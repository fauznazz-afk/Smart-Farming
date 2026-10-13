import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/utils/app_update.dart';

void main() {
  group('parseGitHubRelease', () {
    test('reads the tag, the page and the notes', () {
      final release = parseGitHubRelease('''
        {"tag_name":"v1.14.0","html_url":"https://github.com/fauznazz-afk/Smart-Farming/releases/tag/v1.14.0","body":"Fixes the sky mark."}
      ''');
      expect(release, isNotNull);
      expect(release!.tag, 'v1.14.0');
      expect(release.version, '1.14.0');
      expect(release.url, 'https://github.com/fauznazz-afk/Smart-Farming/releases/tag/v1.14.0');
      expect(release.notes, 'Fixes the sky mark.');
    });

    // **Every one of these has to be a null and not an exception.** The call
    // site runs this during startup against a third-party API, and an app that
    // cannot be launched because an optional convenience returned HTML is worse
    // than an app that never mentions an update.
    test('returns null for anything it does not understand', () {
      const bodies = <String>[
        '',
        'not json at all',
        '<html><body>rate limited</body></html>',
        '[]',
        '{"tag_name":null}',
        '{"tag_name":""}',
        '{"tag_name":"v1.0.0"}',
        '{"tag_name":"v1.0.0","html_url":"http://insecure.example/x"}',
        '{"tag_name":"v1.0.0","html_url":"javascript:alert(1)"}',
      ];
      for (final body in bodies) {
        expect(
          parseGitHubRelease(body),
          isNull,
          reason: 'this body must not produce a release: $body',
        );
      }
    });

    // **An unreadable body is not an unreadable release.** The tag and the page
    // are what the update actually is; the notes are a nicety. Throwing the
    // whole thing away because `body` came back as a number would mean a
    // cosmetic field decides whether the user hears about a security fix.
    test('a release whose notes are unusable is still a release', () {
      final release = parseGitHubRelease(
        '{"tag_name":"v1.0.0","html_url":"https://ok.example","body":42}',
      );
      expect(release, isNotNull);
      expect(release!.notes, isNull);
    });

    // **An empty body is null notes, not a release with blank notes.** The two
    // are different: one is a release nobody wrote anything for, the other is a
    // release the parser mis-read.
    test('a release with no body keeps a null note rather than empty text', () {
      expect(
        parseGitHubRelease('{"tag_name":"v1.0.0","html_url":"https://x.example","body":"   "}')!
            .notes,
        isNull,
      );
    });
  });

  group('normalizeVersion', () {
    test('strips the tag decoration that has shipped in this repo', () {
      expect(normalizeVersion('v1.13.0'), '1.13.0');
      expect(normalizeVersion('1.13.0'), '1.13.0');
      expect(normalizeVersion('release-1.13.0'), '1.13.0');
      expect(normalizeVersion('  v1.13.0  '), '1.13.0');
      expect(normalizeVersion('=1.13.0'), '1.13.0');
    });
  });

  group('isNewerVersion', () {
    // **The reason this exists, and it is not hypothetical: this app shipped
    // 1.13.0.** A string comparison says "1.9.0" > "1.13.0" because '9' sorts
    // after '1', so a client on the older build would be told to update to a
    // version it already has, and a client on the newer one would not be told
    // about anything at all.
    test('compares segment by segment, not as strings', () {
      expect(isNewerVersion('1.9.0', '1.13.0'), isFalse);
      expect(isNewerVersion('1.13.0', '1.9.0'), isTrue);
      expect(isNewerVersion('1.14.0', '1.13.0'), isTrue);
      expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    });

    test('a missing segment is zero', () {
      expect(isNewerVersion('1.14', '1.13.0'), isTrue);
      expect(isNewerVersion('1.13', '1.13.0'), isFalse);
      expect(isNewerVersion('1.13.1', '1.13'), isTrue);
    });

    test('the same version is not newer', () {
      expect(isNewerVersion('1.13.0', '1.13.0'), isFalse);
    });

    // **The build number is dropped, deliberately.** The installed app reports
    // `1.13.0+25`; the tag says `v1.13.0`. Comparing the build counter against
    // a tag would make every build of a released version look like something
    // else, and the user would be told to reinstall the app they already have.
    test('the local build counter after + is ignored', () {
      expect(isNewerVersion('1.13.0', '1.13.0+25'), isFalse);
      expect(isNewerVersion('1.13.0+99', '1.13.0+25'), isFalse);
      expect(isNewerVersion('1.14.0', '1.13.0+25'), isTrue);
    });

    test('an unparseable version never nags the user', () {
      expect(isNewerVersion('nightly', '1.13.0'), isFalse);
      expect(isNewerVersion('1.x.0', '1.13.0'), isFalse);
      expect(isNewerVersion('', '1.13.0'), isFalse);
      expect(isNewerVersion('1.13.0', ''), isFalse);
      expect(isNewerVersion('1.-1.0', '1.13.0'), isFalse);
    });
  });

  group('isDue', () {
    final now = DateTime(2026, 10, 13, 9);

    test('never checked is due immediately', () {
      expect(isDue(null, now), isTrue);
    });

    test('a check inside the window is not due', () {
      expect(isDue(now.subtract(const Duration(hours: 23)), now), isFalse);
      expect(isDue(now.subtract(const Duration(minutes: 5)), now), isFalse);
    });

    test('a check at or past the window is due', () {
      expect(isDue(now.subtract(kUpdateCheckInterval), now), isTrue);
      expect(isDue(now.subtract(const Duration(hours: 25)), now), isTrue);
    });
  });
}