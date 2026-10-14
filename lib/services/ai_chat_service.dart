import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/ai_provider.dart';

/// Calls the user's model endpoint and returns the reply text.
///
/// The API key is the user's own and exists only in a header built by
/// [buildAiHeaders]. It is never logged, never placed in the body, and never
/// included in an error message — an error surfaces the provider's own message
/// and the status code only.
class AiChatService {
  const AiChatService();

  /// Covers headers and body together. A model call is slower than a ThingsBoard
  /// poll but this is a user-initiated request on a phone, not a tick.
  static const Duration _timeout = Duration(seconds: 45);

  /// A chat reply is text. Anything larger is a mistake or an attack, and the
  /// fold stops reading rather than buffering it — the same cap the ThingsBoard
  /// client uses for its snapshots.
  static const int _maxReplyBytes = 256 * 1024;

  /// Sends one question and returns the assistant's reply.
  ///
  /// Throws [AiChatException] with a message meant to be shown to the user. Any
  /// transport failure is wrapped in the same type, so the screen has exactly
  /// one error path.
  Future<String> ask({
    required AiProviderPreset preset,
    required String apiKey,
    required String model,
    required String telemetrySummary,
    required List<AiTurn> history,
    required String question,
  }) async {
    final questionText = sanitizeQuestion(question);
    if (questionText.isEmpty) {
      throw const AiChatException('Ask a question first.');
    }

    final uri = _resolveEndpoint(preset);
    final body = buildAiRequestBody(
      preset: preset,
      model: model,
      telemetrySummary: telemetrySummary,
      history: history,
      question: questionText,
    );
    final request = http.Request('POST', uri)
      ..headers.addAll(buildAiHeaders(preset, apiKey))
      // **Redirects are refused, as in the ThingsBoard client.** A 307 would
      // replay the request — headers included — to whatever host the redirect
      // names, which would hand the user's key to that host. The key travels in
      // a header, so this is the same risk as the access-token redirect there.
      ..followRedirects = false
      ..body = jsonEncode(body);

    final client = http.Client();
    late final http.Response response;
    try {
      response = await _send(client, request);
    } on _ReplyTooLarge {
      throw const AiChatException('The model reply was too large to read.');
    } on TimeoutException {
      throw const AiChatException(
        'The model took too long to answer. Try again.',
      );
    // `dart:io` is never imported in this app, so a raw `SocketException`
    // cannot be named here. `http`'s IO client wraps it in `ClientException`,
    // which is the case below.
    } on http.ClientException {
      throw const AiChatException('Could not reach the model endpoint.');
    } on FormatException {
      throw const AiChatException('The model returned an unreadable reply.');
    } finally {
      client.close();
    }

    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const AiChatException(
        'The model endpoint redirected. Refused, so your key is not forwarded.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiChatException(
        'The API key was rejected. Check it in Settings.',
      );
    }
    if (response.statusCode == 404) {
      // **The most likely cause by far is a retired model name**, so the error
      // says that rather than printing a bare status. Reported on the device on
      // 13 October 2026: Gemini answered 404 because the shipped default was
      // `gemini-2.0-flash`, which Google shut down on 1 June 2026. Google's
      // error body for that case is terse, and the generic message turned a
      // one-field fix into a hunt.
      throw AiChatException(
        'The provider does not recognise the model "${_safeModelName(model)}". '
        'Model names change and retired ones are removed — check the Model '
        'field in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw const AiChatException(
        'The provider rate limit was reached. Wait a moment and try again.',
      );
    }

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiChatException(_providerMessage(decoded, response.statusCode));
    }
    final reply = parseAiReply(preset, decoded);
    if (reply == null) {
      throw const AiChatException('The model returned an unreadable reply.');
    }
    return reply;
  }

  /// Streams the assistant's reply as a sequence of text chunks.
  ///
  /// Returns a [Stream<String>] that emits each token/delta as it arrives.
  /// The stream completes when the model signals `[DONE]` (OpenAI) or the
  /// final event (Anthropic), or errors with [AiChatException] on failure.
  ///
  /// The existing [ask] method remains unchanged for backward compatibility.
  Stream<String> askStream({
    required AiProviderPreset preset,
    required String apiKey,
    required String model,
    required String telemetrySummary,
    required List<AiTurn> history,
    required String question,
  }) async* {
    final questionText = sanitizeQuestion(question);
    if (questionText.isEmpty) {
      throw const AiChatException('Ask a question first.');
    }

    final uri = _resolveEndpoint(preset);
    final body = buildAiRequestBody(
      preset: preset,
      model: model,
      telemetrySummary: telemetrySummary,
      history: history,
      question: questionText,
      stream: true,
    );
    final request = http.Request('POST', uri)
      ..headers.addAll(buildAiHeaders(preset, apiKey))
      ..headers.addAll({'Accept': 'text/event-stream'})
      ..followRedirects = false
      ..body = jsonEncode(body);

    final client = http.Client();
    late final http.StreamedResponse streamed;
    try {
      streamed = await client.send(request).timeout(_timeout);
    } on TimeoutException {
      client.close();
      throw const AiChatException(
        'The model took too long to answer. Try again.',
      );
    } on http.ClientException {
      client.close();
      throw const AiChatException('Could not reach the model endpoint.');
    }

    if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
      client.close();
      throw const AiChatException(
        'The model endpoint redirected. Refused, so your key is not forwarded.',
      );
    }
    if (streamed.statusCode == 401 || streamed.statusCode == 403) {
      client.close();
      throw const AiChatException(
        'The API key was rejected. Check it in Settings.',
      );
    }
    if (streamed.statusCode == 404) {
      client.close();
      throw AiChatException(
        'The provider does not recognise the model "${_safeModelName(model)}". '
        'Model names change and retired ones are removed — check the Model '
        'field in Settings.',
      );
    }
    if (streamed.statusCode == 429) {
      client.close();
      throw const AiChatException(
        'The provider rate limit was reached. Wait a moment and try again.',
      );
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      // Read error body for provider message
      final errorBytes = await streamed.stream
          .timeout(_timeout)
          .fold<List<int>>(<int>[], (acc, chunk) {
        if (acc.length + chunk.length > _maxReplyBytes) {
          throw const _ReplyTooLarge();
        }
        return acc..addAll(chunk);
      });
      client.close();
      final errorBody = _decodeBytes(errorBytes);
      throw AiChatException(_providerMessage(errorBody, streamed.statusCode));
    }

    final decoder = utf8.decoder;
    String buffer = '';
    bool done = false;
    int streamedBytes = 0;

    await for (final chunk in streamed.stream.timeout(_timeout)) {
      if (done) continue;
      streamedBytes += chunk.length;
      if (streamedBytes > _maxReplyBytes) {
        client.close();
        throw const AiChatException('The model reply was too large to read.');
      }
      buffer += decoder.convert(chunk);

      // Split on double newline (SSE event separator)
      final events = buffer.split('\n\n');
      buffer = events.removeLast(); // Keep incomplete event in buffer

      for (final event in events) {
        if (preset.isAnthropic) {
          final delta = parseAnthropicStreamChunk(event);
          if (delta != null) yield delta;
          // Anthropic signals completion with message_stop event
          if (event.contains('event: message_stop')) {
            done = true;
            break;
          }
        } else {
          final delta = parseOpenAiStreamChunk(event);
          if (delta != null) yield delta;
          // OpenAI signals completion with [DONE] or finish_reason
          final trimmed = event.trim();
          if (trimmed == 'data: [DONE]') {
            done = true;
            break;
          }
          // Some providers send finish_reason without [DONE]. It must be a
          // *string* value: every intermediate chunk carries
          // `"finish_reason": null`, and a bare `contains('"finish_reason"')`
          // matched those too, ending the stream on the first chunk.
          if (trimmed.startsWith('data: ') &&
              RegExp(r'"finish_reason"\s*:\s*"').hasMatch(trimmed)) {
            done = true;
            break;
          }
        }
      }
    }

    // Flush any remaining buffer
    if (buffer.isNotEmpty && !done) {
      if (preset.isAnthropic) {
        final delta = parseAnthropicStreamChunk(buffer);
        if (delta != null) yield delta;
      } else {
        final delta = parseOpenAiStreamChunk(buffer);
        if (delta != null) yield delta;
      }
    }

    client.close();
  }

  /// HTTPS only, no userinfo, and a typed endpoint is required.
  ///
  /// Same reasoning as `parseAllowedCctvUrl`: an endpoint is a URL the user typed
  /// and it carries a credential, so `https://evil.example@…` and a non-443 port
  /// are both refused rather than normalised. There is no allowlist here — the
  /// user is pointing at their own provider — but the scheme check is not
  /// optional, because a cleartext POST would put the key on the wire in the
  /// clear.
  Uri _resolveEndpoint(AiProviderPreset preset) {
    final raw = preset.endpoint.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      throw const AiChatException(
        'The model endpoint must be an HTTPS URL. Set it in Settings.',
      );
    }
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const AiChatException('The model endpoint is not a valid URL.');
    }
    return uri;
  }

  Future<http.Response> _send(http.Client client, http.Request request) async {
    final streamed = await client.send(request).timeout(_timeout);
    // Inside the timeout, not just around `send`: a server that sends headers
    // and then stalls would otherwise hold this future open indefinitely.
    final bytes = await streamed.stream.timeout(_timeout).fold<List<int>>(
      <int>[],
      (acc, chunk) {
        if (acc.length + chunk.length > _maxReplyBytes) {
          throw const _ReplyTooLarge();
        }
        return acc..addAll(chunk);
      },
    );
    return http.Response.bytes(
      bytes,
      streamed.statusCode,
      headers: streamed.headers,
      request: request,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  Map<String, dynamic> _decodeBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  /// The model name as typed, for an error message.
  ///
  /// **Clipped and stripped.** It is the only value in this class that came from
  /// a text field, and it is about to be rendered into a SnackBar-sized string;
  /// an unbounded one is a layout problem and a control character in it is a
  /// rendering one.
  String _safeModelName(String model) {
    final cleaned = model.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();
    if (cleaned.isEmpty) return '(empty)';
    return cleaned.length <= 64 ? cleaned : '${cleaned.substring(0, 64)}...';
  }

  /// The provider's own error text, which names the problem (`model not found`,
  /// `invalid api key`) in a way "request failed (400)" does not.
  String _providerMessage(Map<String, dynamic> body, int statusCode) {
    final error = body['error'];
    final message = switch (error) {
      final Map<String, dynamic> map => map['message'],
      final String text => text,
      _ => null,
    };
    final text = message is String ? message.trim() : '';
    if (text.isEmpty) return 'The model request failed ($statusCode).';
    // Bounded: a provider echoing a long HTML error page is not a message.
    return text.length <= 300 ? text : '${text.substring(0, 300)}...';
  }
}

/// Anything the assistant could not answer, phrased for the user.
class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ReplyTooLarge implements Exception {
  const _ReplyTooLarge();
}