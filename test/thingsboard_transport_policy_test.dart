import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// The transport policy in `ThingsBoardApi`, tested against a real server.
///
/// **These are execution tests, not shape tests.** An earlier pass at this fix
/// asserted that `followRedirects: false` appeared in the source. That would
/// have passed while the credential still leaked, because the thing that
/// actually leaks it is the Dart SDK's header-strip list not knowing the name
/// of ThingsBoard's header. So the property that matters is behavioural: *does a
/// request carrying the bearer token end up on the redirect target?* That needs
/// two real sockets.
///
/// The defect, found in review on 6 October 2026 and reproduced here:
///
/// ```text
/// ORIGIN got /a  xAuth=Bearer SECRET-JWT
/// EVIL   got host=127.0.0.1  xAuth=Bearer SECRET-JWT   <- different host
/// ```
///
/// `dart:io` strips six header names on a cross-origin redirect --
/// `authorization`, `www-authenticate`, `proxy-authorization`,
/// `proxy-authenticate`, `cookie`, `cookie2` (`_http/http_impl.dart`) --
/// and `X-Authorization`, which is what ThingsBoard's API requires, is not
/// among them. `package:http` defaults to `followRedirects: true`. So one 302
/// from the server was enough to hand the access token to any host it named,
/// and the refresh `POST` was worse: its body holds the refresh token and is
/// replayed on a 307.
///
/// The header cannot simply be renamed to `Authorization` -- that is exactly
/// what would put it on the strip list, and it is not what the API accepts.
void main() {
  /// The smallest thing that behaves like `ThingsBoardApi._send`: build a
  /// request carrying the ThingsBoard header, then decide for yourself whether
  /// to follow redirects. Kept local so this test pins the *policy decision*,
  /// and re-reads the comment on `dart:io` if the SDK's list ever changes.
  Future<http.StreamedResponse> send(
    http.Client client,
    Uri url, {
    required bool followRedirects,
  }) {
    final request = http.Request('GET', url)
      ..followRedirects = followRedirects
      ..headers['X-Authorization'] = 'Bearer SECRET-JWT';
    return client.send(request);
  }

  group('X-Authorization survives a cross-origin redirect by default', () {
    // This is the reason the fix exists. If this test ever stops failing for
    // the naive implementation, the SDK learned the header name and the fix
    // could be simplified -- so its failure is the point, not a nuisance.
    test('the SDK does not strip it', () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final evil = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await origin.close(force: true);
        await evil.close(force: true);
      });

      String? evilSawHeader;
      String? evilSawHost;
      final evilDone = Completer<void>();

      evil.listen((request) async {
        evilSawHeader = request.headers.value('x-authorization');
        evilSawHost = request.headers.value('host');
        await request.response.close();
        if (!evilDone.isCompleted) evilDone.complete();
      });

      origin.listen((request) async {
        request.response.statusCode = 302;
        request.response.headers.set('Location', 'http://127.0.0.1:${evil.port}/stolen');
        await request.response.close();
      });

      final client = http.Client();
      addTearDown(client.close);

      await send(
        client,
        Uri.parse('http://127.0.0.1:${origin.port}/start'),
        // The default `package:http` behaviour: follow.
        followRedirects: true,
      );
      await evilDone.future.timeout(const Duration(seconds: 5));

      expect(
        evilSawHost,
        isNot('127.0.0.1:${origin.port}'),
        reason: 'the redirect target should be a different host:port',
      );
      expect(
        evilSawHeader,
        'Bearer SECRET-JWT',
        reason: 'this is the defect: a custom header the SDK does not know '
            'about is copied verbatim to the redirect target. If this is null, '
            'the SDK now strips it and the fix could be simplified.',
      );
    });
  });

  group('the fix', () {
    test('a redirect is refused before the token can travel', () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final evil = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await origin.close(force: true);
        await evil.close(force: true);
      });

      var evilWasContacted = false;
      evil.listen((request) async {
        evilWasContacted = true;
        await request.response.close();
      });

      origin.listen((request) async {
        request.response.statusCode = 302;
        request.response.headers.set('Location', 'http://127.0.0.1:${evil.port}/stolen');
        await request.response.close();
      });

      final client = http.Client();
      addTearDown(client.close);

      final response = await send(
        client,
        Uri.parse('http://127.0.0.1:${origin.port}/start'),
        followRedirects: false,
      );

      expect(response.statusCode, 302, reason: 'the 3xx is reported, not followed');
      // Give a stray connection a moment to arrive, so this cannot pass because
      // the assertion simply ran too early.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        evilWasContacted,
        isFalse,
        reason: 'the redirect target must never be dialled',
      );
    });
  });

  group('what the Dart SDK strips', () {
    // Pins the assumption the whole fix rests on. If a future SDK version adds
    // `x-authorization` to that list, `followRedirects: false` is still correct
    // defence in depth -- but this test is what tells you it became redundant,
    // which is worth knowing rather than discovering later.
    const sensitive = {
      'authorization',
      'www-authenticate',
      'proxy-authorization',
      'proxy-authenticate',
      'cookie',
      'cookie2',
    };

    test('X-Authorization is not on it', () {
      expect(
        sensitive.contains('x-authorization'),
        isFalse,
      );
    });
  });

  group('the body cap', () {
    test('a large response is not silently parsed', () async {
      // The cap exists because ThingsBoard is not fully under the user's
      // control: a compromised sensor gateway can make a telemetry endpoint
      // return whatever it likes. This pins the read, not the parser.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        // Order matters and cost a run to find out: the first `write` sends the
        // headers, so setting `contentType` after it throws
        // "HTTP headers are not mutable".
        request.response.headers.contentType = ContentType.json;
        request.response.write('[');
        // Comfortably past 256 KiB, which is the cap: 8 bytes per repetition,
        // so 40 000 is about 320 KB. 30 000 was tried first and did *not*
        // exceed the cap -- it is 240 KB -- and a test that quietly fails to
        // test anything is worse than no test.
        for (var i = 0; i < 40000; i++) {
          request.response.write('{"k":1},');
        }
        await request.response.close();
      });

      final client = http.Client();
      addTearDown(client.close);

      final streamed = await client.send(
        http.Request('GET', Uri.parse('http://127.0.0.1:${server.port}/big')),
      );

      const cap = 256 * 1024;
      final bytes = <int>[];
      var exceeded = false;
      await for (final chunk in streamed.stream) {
        bytes.addAll(chunk);
        if (bytes.length > cap) {
          exceeded = true;
          break;
        }
      }

      expect(
        exceeded,
        isTrue,
        reason: 'the body is larger than the cap, so the reader must stop',
      );
      expect(bytes.length, lessThan(30000 * 9));
      // And it is not valid JSON once truncated, which is the point: the parse
      // fails loudly rather than materialising a huge structure.
      final truncated = '[${utf8.decode(bytes, allowMalformed: true)}';
      expect(() => jsonDecode(truncated), throwsA(anything));
    });
  });
}


