import 'package:flutter/material.dart';

import '../services/ai_chat_service.dart';
import '../services/ai_settings.dart';
import '../utils/ai_provider.dart';
import 'chat/widgets/chat_app_bar.dart';
import 'chat/widgets/chat_views.dart';
import 'dashboard/utils/design_tokens.dart';

/// Ask the model a question about the current telemetry.
///
/// **The telemetry summary is passed in, not read.** The dashboard owns the live
/// values and rebuilds on its own poll; reaching into it from here would make a
/// chat screen depend on a screen's private state, which is the one thing the
/// layering in this app is for. It arrives as a callback and is called once per
/// question, so the answer describes the readings at the moment of asking rather
/// than at the moment the screen opened.
///
/// **Nothing is persisted.** The transcript lives in this [State] and dies with
/// the screen, so closing the assistant leaves no conversation on the device.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.telemetrySummary,
    this.openSettings,
  });

  /// Rebuilt for every question, so the assistant answers from the current
  /// readings rather than from whatever they were when the screen opened.
  /// See [buildTelemetrySummary].
  final String Function() telemetrySummary;

  /// Pushes the assistant's settings, awaited so the key can be re-read on the
  /// way back. Optional so a test can skip the navigation.
  final Future<void> Function()? openSettings;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const AiChatService _service = AiChatService();

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiTurn>[];

  /// The wall clock each turn was sent, parallel to [_messages].
  ///
  /// **A parallel list rather than a field on [AiTurn], because `AiTurn` is the
  /// wire format.** A timestamp the model never asked for is a field that then has
  /// to stay out of the request body and out of thirty-odd tests, for no benefit.
  /// Here it is one local list, and both lists are only written through
  /// [_addTurn] and [_removeStreaming] — which is the only reason they stay the
  /// same length.
  final _sentAt = <DateTime>[];

  AiSettings? _settings;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  // For streaming: index of the assistant message being streamed
  int? _streamingIndex;
  String? _lastUserQuestion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await AiSettings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  @override
  void dispose() {
    // Clean up any partial streaming message so it doesn't persist
    // if the user navigates away mid-stream
    final pending = _streamingIndex;
    if (pending != null && pending < _messages.length) {
      if (_messages[pending].text.trim().isEmpty) {
        _removeStreaming();
      }
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final settings = _settings;
    final question = _input.text;
    if (settings == null || !settings.isConfigured || _sending) return;
    final sanitized = sanitizeQuestion(question);
    if (sanitized.isEmpty) return;

    _lastUserQuestion = sanitized;

    setState(() {
      _sending = true;
      _error = null;
      _addTurn('user', sanitized);
      // Add empty assistant message for streaming
      _addTurn('assistant', '');
      _streamingIndex = _messages.length - 1;
      _input.clear();
    });
    _scrollToEnd();

    try {
      await _askStreaming(settings: settings, question: sanitized);

      // Streaming complete
      if (!mounted) return;
      setState(() => _streamingIndex = null);
    } on AiChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        // Remove the empty assistant message on error
        _removeStreaming();
        _streamingIndex = null;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _retryLastQuestion() async {
    final settings = _settings;
    final question = _lastUserQuestion;
    if (settings == null ||
        !settings.isConfigured ||
        _sending ||
        question == null) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _addTurn('user', question);
      _addTurn('assistant', '');
      _streamingIndex = _messages.length - 1;
    });
    _scrollToEnd();

    try {
      await _askStreaming(settings: settings, question: question);

      if (!mounted) return;
      setState(() => _streamingIndex = null);
    } on AiChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _removeStreaming();
        _streamingIndex = null;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  /// Streams one reply into the pending assistant turn, and falls back to a
  /// single non-streaming call when the stream delivers nothing.
  ///
  /// **The fallback exists because a provider is free to ignore `stream: true`
  /// and answer with one JSON body.** The SSE parser reads no events from that,
  /// so the `await for` completes with zero chunks — a silent empty bubble, which
  /// is the "the assistant does not answer" report. One non-streaming call is
  /// cheap and turns that case into a reply.
  ///
  /// Throws [AiChatException] when neither path yields text, so the caller
  /// surfaces the reason rather than an empty bubble. Both call sites (`_send`
  /// and `_retryLastQuestion`) must have appended `user` + an empty `assistant`
  /// turn before calling this — the history slice below assumes it.
  Future<void> _askStreaming({
    required AiSettings settings,
    required String question,
  }) async {
    // One snapshot per question, taken here rather than in `initState`: the
    // stream and its non-streaming fallback are one request and must see the
    // same readings.
    final telemetrySummary = widget.telemetrySummary();
    var receivedAnyChunk = false;
    final stream = _service.askStream(
      preset: settings.preset,
      apiKey: settings.apiKey,
      model: settings.model,
      telemetrySummary: telemetrySummary,
      history: _messages.sublist(0, _messages.length - 2),
      question: question,
    );

    await for (final chunk in stream) {
      receivedAnyChunk = true;
      if (!mounted) return;
      setState(() {
        if (_streamingIndex != null && _streamingIndex! < _messages.length) {
          final current = _messages[_streamingIndex!];
          _messages[_streamingIndex!] = AiTurn(
            role: current.role,
            text: current.text + chunk,
          );
        }
      });
      _scrollToEnd();
    }
    if (receivedAnyChunk) return;

    if (!mounted) return;
    final reply = await _service.ask(
      preset: settings.preset,
      apiKey: settings.apiKey,
      model: settings.model,
      telemetrySummary: telemetrySummary,
      history: _messages.sublist(0, _messages.length - 2),
      question: question,
    );
    if (reply.isEmpty) {
      throw const AiChatException('The model returned an empty reply.');
    }
    if (!mounted) return;
    setState(() {
      if (_streamingIndex != null && _streamingIndex! < _messages.length) {
        _messages[_streamingIndex!] = AiTurn(role: 'assistant', text: reply);
      }
    });
  }

  /// Appends one turn and stamps it. The only writer of [_messages].
  void _addTurn(String role, String text) {
    _messages.add(AiTurn(role: role, text: text));
    _sentAt.add(DateTime.now());
  }

  /// Drops the assistant turn that was being streamed, if it is still there.
  void _removeStreaming() {
    final index = _streamingIndex;
    if (index == null || index >= _messages.length) return;
    _messages.removeAt(index);
    if (index < _sentAt.length) _sentAt.removeAt(index);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.state,
        curve: Curves.easeOut,
      );
    });
  }

  void _askSuggestion(String question) {
    _input.text = question;
    _send();
  }

  /// Pushes Settings and **re-reads the key on the way back**.
  ///
  /// Without the re-read this screen keeps the settings it loaded in
  /// `initState`, and the user who taps "Open settings", pastes a key and comes
  /// straight back lands on the same "No API key yet" screen they left — which
  /// reads as the save having failed when nothing did.
  Future<void> _openSettings() async {
    final open = widget.openSettings;
    if (open == null) return;
    await open();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final configured = _settings?.isConfigured ?? false;
    return Scaffold(
      // The flat page colour rather than `AppBackground`'s sweep: this screen is
      // a list of bubbles and nothing else, and the gradient behind them buys
      // nothing. What it *does* need is for the few lines that are drawn **on**
      // this colour - the app bar title, the unconfigured state, the intro
      // headings - to use page ink rather than card ink.
      backgroundColor: AppSurfaces.page,
      appBar: chatAppBar(
        context: context,
        clearEnabled: !_sending && _messages.isNotEmpty,
        onClear: () => setState(() {
          _messages.clear();
          _sentAt.clear();
        }),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ChatTranscript(
                      messages: _messages,
                      sentAt: _sentAt,
                      scroll: _scroll,
                      configured: configured,
                      sending: _sending,
                      streamingIndex: _streamingIndex,
                      telemetrySummary: widget.telemetrySummary,
                      onSuggestion: _askSuggestion,
                      onOpenSettings: _openSettings,
                    ),
                  ),
                  if (_error != null)
                    ChatErrorBanner(
                      message: _error!,
                      retryEnabled: !_sending,
                      onRetry: _retryLastQuestion,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  ChatComposer(
                    input: _input,
                    configured: configured,
                    sending: _sending,
                    onSend: _send,
                  ),
                ],
              ),
      ),
    );
  }
}

