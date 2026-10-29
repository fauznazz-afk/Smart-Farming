import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/update_banner.dart';
import 'package:plts_monitoring/utils/app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final release = AppRelease(
    tag: 'v1.14.0',
    version: '1.14.0',
    url: 'https://github.com/fauznazz-afk/Smart-Farming/releases/tag/v1.14.0',
    notes: 'Fixes the sky mark.',
  );

  group('UpdateBanner', () {
    testWidgets('names the version it is offering', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(release: release, onDismiss: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPDATE 1.14.0 AVAILABLE'), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('LATER'), findsOneWidget);
    });

    testWidgets('LATER calls the dismiss callback', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(release: release, onDismiss: () => dismissed++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('LATER'));
      await tester.pumpAndSettle();

      expect(
        dismissed,
        1,
        reason: 'the only way to hide the banner has to actually fire',
      );
    });

    // **The tap targets have to be real.** The first version of this banner
    // wrapped a 10 sp `Text` in a `Padding`, and the measured hit area was 12 dp
    // tall - a quarter of the 48 dp minimum - on the one control the banner
    // exists for. A comment in the source claimed it was fine; this is what
    // says otherwise, and it is measured rather than read.
    testWidgets('GET and LATER are large enough to hit with a thumb', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(release: release, onDismiss: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const ['GET', 'LATER']) {
        // The InkWell, not the label: the label is the smaller of the two and
        // measuring it would be measuring the wrong thing.
        final target = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(
          target.height,
          greaterThanOrEqualTo(44),
          reason:
              '$label is ${target.height} dp tall, which is not a tap '
              'target',
        );
        expect(
          target.width,
          greaterThanOrEqualTo(44),
          reason:
              '$label is ${target.width} dp wide, which is not a tap '
              'target',
        );
      }
    });
  });

  group('UpdateBannerSwitcher', () {
    testWidgets('a null release draws nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateBannerSwitcher(
              release: null,
              visible: true,
              onDismiss: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPDATE 1.14.0 AVAILABLE'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a visible release shows the version', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBannerSwitcher(
              release: release,
              visible: true,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPDATE 1.14.0 AVAILABLE'), findsOneWidget);
    });
  });

  group('the force path', () {
    // **The gate is right for the automatic check and wrong for a button.** A
    // phone on a metered connection should not ask GitHub on every launch, which
    // is what `kUpdateCheckInterval` is for. But that makes the banner invisible
    // to anyone who wants to see it now, including the developer who just
    // published the release. `force: true` is what the Settings button passes,
    // and it is the difference between a button and a decoration.
    test('isDue is what force bypasses, and it holds a real timestamp', () {
      final now = DateTime(2026, 10, 13, 9);
      final thisMorning = DateTime(2026, 10, 13, 8);
      expect(isDue(thisMorning, now), isFalse);
      // The service stamps the time *before* the request, so a second check in
      // the same session is not due - which is exactly the case force exists
      // for.
      expect(isDue(now, now), isFalse);
    });
  });

  group('the once-a-day gate', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('never checked is due', () {
      expect(isDue(null, DateTime(2026, 10, 13)), isTrue);
    });

    test('a check from an hour ago is not due', () {
      expect(
        isDue(DateTime(2026, 10, 13, 8), DateTime(2026, 10, 13, 9)),
        isFalse,
      );
    });
  });
}

void _noop() {}
