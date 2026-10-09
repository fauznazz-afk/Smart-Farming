import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/services/cctv_url.dart';

// Split out of the former `cctv_test.dart`, which at 34 tests had outgrown the
// RAM budget for a single file on this 7 GB machine: `dart_test.yaml` pins
// `concurrency: 1` because the Dart compiler and the test isolate compete, and a
// file that is too large loses that race as a bare "loading <file>.dart" or
// "did not complete" with no stack trace. Every group here passes standalone,
// which is what makes that diagnosis rather than a guess.
//
// Nothing moved here. These are the allowlist guards, unchanged, and they stay
// the file named in `AGENTS.md` §"Regression guards worth knowing about" - now
// under this name rather than `cctv_test.dart`.
//
// Pure Dart on purpose: every test below is a function call with no widget and
// no Flutter binding, so this file costs a fraction of the screen test's
// footprint and is the cheapest of the three to run.
void main() {
  group('parseAllowedCctvUrl', () {
    test('accepts the official https stream page', () {
      expect(
        parseAllowedCctvUrl(defaultAllowedCctvUrl),
        isNotNull,
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(
        parseAllowedCctvUrl('  $defaultAllowedCctvUrl  '),
        isNotNull,
      );
    });

    test('rejects non-https schemes', () {
      expect(
        parseAllowedCctvUrl('http://cctv.mbkm20262027.tech/stream.html'),
        isNull,
      );
      expect(
        parseAllowedCctvUrl('javascript:alert(1)'),
        isNull,
      );
    });

    test('rejects any other host, including lookalikes', () {
      expect(
        parseAllowedCctvUrl('https://evil.example.com/stream.html?src=cam1'),
        isNull,
      );
      expect(
        parseAllowedCctvUrl('https://cctv.mbkm20262027.tech.evil.com/stream'),
        isNull,
      );
      expect(
        parseAllowedCctvUrl('https://mbkm20262027.tech/stream.html'),
        isNull,
      );
    });

    test('rejects non-default ports', () {
      expect(
        parseAllowedCctvUrl('https://cctv.mbkm20262027.tech:8443/stream.html'),
        isNull,
      );
    });

    test('rejects unparsable input', () {
      expect(parseAllowedCctvUrl(''), isNull);
      expect(parseAllowedCctvUrl('not a url'), isNull);
    });

    test('host check is case insensitive', () {
      expect(
        parseAllowedCctvUrl('https://CCTV.MBKM20262027.TECH/stream.html'),
        isNotNull,
      );
    });

    // **The four below were all reachable before, and none of them was a host
    // bypass.** The allowlist constrained where the *document* came from and
    // stopped there, so everything the document could then be *told to fetch*
    // was unconstrained. Found in review on 6 October 2026.
    group('constrains what go2rtc is told to dial', () {
      test('rejects a src that is a URL', () {
        // The finding. `src` goes straight to the go2rtc process on the camera
        // host, so this turns the user's own camera box into a relay that dials
        // out of their LAN. `file://` reads the camera host's filesystem.
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=rtsp://203.0.113.9/x',
          ),
          isNull,
        );
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=file:///etc/passwd',
          ),
          isNull,
        );
      });

      test('rejects a src that traverses', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=../../etc/passwd',
          ),
          isNull,
        );
      });

      test('rejects a second parameter hiding behind src', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1&src=rtsp://x/y',
          ),
          isNull,
        );
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1&url=http://evil',
          ),
          isNull,
        );
      });

      test('accepts the names the app itself ships', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1',
          ),
          isNotNull,
        );
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam2',
          ),
          isNotNull,
        );
        // A stream name with a dash or underscore is a legitimate go2rtc name.
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=front_door-2',
          ),
          isNotNull,
        );
      });

      test('no src at all still resolves', () {
        // go2rtc's player page shows a picker without one, and a saved setting
        // may be that. There is nothing to abuse in its absence, so refusing it
        // would break a working configuration to fix nothing.
        expect(
          parseAllowedCctvUrl('https://cctv.mbkm20262027.tech/stream.html'),
          isNotNull,
        );
      });
    });

    group('mirrors the Kotlin host allowlist', () {
      // `requireAllowedThingsBoardHost` rejected userinfo with a comment naming
      // the trick. This function is its counterpart and did not.
      test('rejects credentials in the URL', () {
        expect(
          parseAllowedCctvUrl(
            'https://user:pw@cctv.mbkm20262027.tech/stream.html?src=cam1',
          ),
          isNull,
        );
      });

      test('rejects a path other than the player page', () {
        // Same reasoning as the Kotlin side: a path would address a different
        // service on the same host.
        expect(
          parseAllowedCctvUrl('https://cctv.mbkm20262027.tech/admin?src=cam1'),
          isNull,
        );
        expect(
          parseAllowedCctvUrl('https://cctv.mbkm20262027.tech/?src=cam1'),
          isNull,
        );
      });

      test('rejects a fragment', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1#x',
          ),
          isNull,
        );
      });
    });
  });
}