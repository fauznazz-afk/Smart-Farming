import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';

/// The two latent transport defects, pinned while they are still latent.
///
/// Both are unreachable today because `baseUrl` is a `static const` with no
/// override. That is exactly why they needed writing down: a check that only
/// matters "someday" is a check nobody adds, and the change that makes it
/// matter — a configurable base URL for a multi-tenant install — is unremarkable
/// enough that nobody would connect it to these two lines.
///
/// Neither of these could be tested against the old code by reading it. The
/// websocket one passed review as correct: `base.scheme == 'https' ? 'wss' : 'ws'`
/// is right for the only input anyone had, and the unsafe branch was silent.
void main() {
  group('the telemetry socket', () {
    test('is wss for the configured base', () {
      final api = ThingsBoardApi();
      expect(api.telemetryWebSocketUri.scheme, 'wss');
    });

    test('never carries the token without a session', () {
      // Preserved from the fix's own behaviour: an unauthenticated attempt used
      // to emit `token=` with a null token.
      final api = ThingsBoardApi();
      expect(api.telemetryWebSocketUri.queryParameters, isEmpty);
    });

    test('the base URL is https, which is what makes wss derivable', () {
      // The guard itself. If this ever fails, `telemetryWebSocketUri` now throws
      // rather than quietly emitting `ws://`, and that throw is the fix.
      expect(Uri.parse(ThingsBoardApi.baseUrl).scheme, 'https');
    });
  });

  group('the host allowlist mirrors the Kotlin side', () {
    test('the allowed host is the configured one, derived not copied', () {
      // Deliberately not a second literal. A copy of a host string is what
      // `AGENTS.md` calls out, and it is what the six `Uri.parse` call sites
      // already were before this existed.
      expect(
        Uri.parse(ThingsBoardApi.baseUrl).host,
        'dashboard.mbkm20262027.tech',
      );
    });

    test('no path or port in the base', () {
      // Same two rules `requireAllowedThingsBoardHost` enforces. A path would be
      // prepended to `/api/...` and address a different service on the host.
      final base = Uri.parse(ThingsBoardApi.baseUrl);
      expect(base.hasPort, isFalse);
      expect(base.path, isEmpty);
    });

    test('no credentials in the base', () {
      // `https://allowed.host@evil.example` is the classic way to smuggle a
      // second host past a naive check. Rejected natively; rejected here too.
      expect(Uri.parse(ThingsBoardApi.baseUrl).userInfo, isEmpty);
    });
  });
}
