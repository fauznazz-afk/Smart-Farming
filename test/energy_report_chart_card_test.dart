import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/energy_report/widgets/chart_card.dart';
import 'package:plts_monitoring/services/energy_report_service.dart';

/// A widget test for `energy_report/widgets/chart_card.dart`.
///
/// This file exists because `PRD_PLTS_Monitoring_App.md` §7.1 named it as a
/// 280-line widget with no test at all, and because of a specific reason in the
/// project's own history.
///
/// On 27 September 2026 three label regressions got through `flutter analyze`,
/// got through a release build, and passed every test that existed at the time:
/// `PV Output` appearing three times inside one card, a unit truncated to
/// `109....`, and a label that only ellipsised once the verdict appeared. Three
/// cosmetic defects in one file, in one session, invisible to the toolchain.
/// `EnergySummaryCard` was the widget the PRD judged most likely to catch the
/// next one, and it now has twenty widget tests.
///
/// This card is the one that was missed. It renders two legend values with a
/// fixed-precision number and no `Expanded` around either of them, next to an
/// `Expanded` date label, inside a readout row. That is exactly the shape the
/// three regressions had.
Widget _wrap(Widget child, {double width = 381, double textScale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800))
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

EnergyBucket _bucket(int hour, double pv, double ac, {int samples = 12}) =>
    EnergyBucket(
      hour: DateTime(2026, 9, 30, hour),
      pvKwh: pv,
      acKwh: ac,
      sampleCount: samples,
    );

List<EnergyBucket> _buckets({int count = 24}) => List.generate(
      count,
      (i) => _bucket(i % 24, 0.4 * i, 0.2 * i),
    );

void main() {
  group('ChartCard readout', () {
    testWidgets('shows the interval label and both series values', (tester) async {
      final touched = ValueNotifier<int?>(3);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bucket 3 is hour 03, so the readout's date slot is the hour label.
      expect(find.text('03:00'), findsWidgets);
      expect(find.text('PV 1.20'), findsOneWidget);
      expect(find.text('AC 0.60'), findsOneWidget);
    });

    testWidgets('uses a full date label when the period is monthly',
        (tester) async {
      final touched = ValueNotifier<int?>(0);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: true,
            buckets: _buckets(count: 6),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30/09/2026'), findsWidgets);
    });

    testWidgets('follows the touched bucket rather than staying on the first',
        (tester) async {
      final touched = ValueNotifier<int?>(null);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PV 0.00'), findsOneWidget);

      touched.value = 6;
      await tester.pumpAndSettle();

      expect(find.text('PV 0.00'), findsNothing);
      expect(find.text('PV 2.40'), findsOneWidget);
      expect(find.text('AC 1.20'), findsOneWidget);
    });

    testWidgets('clamps a touched index past the end of the list',
        (tester) async {
      final touched = ValueNotifier<int?>(999);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(count: 4),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Last bucket is index 3 -> hour 03, pv 1.20, ac 0.60.
      expect(find.text('PV 1.20'), findsOneWidget);
    });
  });

  group('ChartCard stepper', () {
    testWidgets('disables previous on the first interval and next on the last',
        (tester) async {
      final touched = ValueNotifier<int?>(null);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(count: 6),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      IconButton button(String tooltip) => tester.widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          );

      expect(button('Previous interval').onPressed, isNull);
      expect(button('Next interval').onPressed, isNotNull);

      touched.value = 5;
      await tester.pumpAndSettle();

      expect(button('Previous interval').onPressed, isNotNull);
      expect(button('Next interval').onPressed, isNull);
    });

    testWidgets('the stepper steps one interval at a time', (tester) async {
      final touched = ValueNotifier<int?>(0);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(count: 5),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Next interval'));
      await tester.pumpAndSettle();
      expect(touched.value, 1);

      await tester.tap(find.byTooltip('Next interval'));
      await tester.pumpAndSettle();
      expect(touched.value, 2);
    });

    testWidgets('is not built for a single bucket', (tester) async {
      final touched = ValueNotifier<int?>(null);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: [_bucket(6, 1.0, 0.5)],
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A Slider built with `divisions: 0` asserts, so the `length > 1` guard
      // is load-bearing rather than cosmetic.
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ChartCard holds up at a narrow viewport and a large font scale', () {
    // **`PRD_PLTS_Monitoring_App.md` 7.2 item 4 lists this layout among three
    // that "flutter test cannot catch", and that is wrong.** A widget test can
    // set the viewport width through `MediaQueryData.size` and the font scale
    // through `textScaler`, which is the only thing needed here because the
    // overflow was a plain `RenderFlex` in a `Row`, not a device-specific one.
    //
    // The defect it found, measured on this widget rather than predicted:
    //
    // | viewport | text scale | overflow before the fix |
    // |---|---|---|
    // | 381 dp | 1.0 | none |
    // | 320 dp | 1.0 | none |
    // | 381 dp | 2.0 | **19 px on the right** |
    // | 320 dp | 2.0 | **80 px on the right** |
    //
    // It came from the readout row holding two `MainAxisSize.min` `_LegendValue`s
    // with no `Flexible` around them, so at 2x scale they had nowhere to go. The
    // fix is a `Wrap`, not `Flexible` plus ellipsis -- see the note in the
    // widget, which is the short version of why a truncated energy figure is
    // worse than a wrapped one.
    const cases = <String, (double, double)>{
      '381 dp at 1.0': (381, 1.0),
      '320 dp at 1.0': (320, 1.0),
      '381 dp at 1.5': (381, 1.5),
      '381 dp at 2.0': (381, 2.0),
      '320 dp at 1.5': (320, 1.5),
      '320 dp at 2.0': (320, 2.0),
    };

    cases.forEach((name, size) {
      testWidgets('the readout does not overflow at $name', (tester) async {
        final touched = ValueNotifier<int?>(2);
        addTearDown(touched.dispose);

        await tester.pumpWidget(
          _wrap(
            ChartCard(
              theme: AppTheme.light,
              monthly: false,
              buckets: _buckets(count: 12),
              touchedBucketNotifier: touched,
            ),
            width: size.$1,
            textScale: size.$2,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Nothing may be abbreviated either: a value that fits only because it
        // was cut off is the regression this file exists to prevent.
        expect(find.text('PV 0.80'), findsOneWidget);
        expect(find.text('AC 0.40'), findsOneWidget);
      });
    });

    testWidgets('the readout wraps rather than truncating at 2.0 scale',
        (tester) async {
      final touched = ValueNotifier<int?>(2);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(count: 12),
            touchedBucketNotifier: touched,
          ),
          width: 320,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      // A full string, not an ellipsised and cut one. If a future change
      // reintroduces `Flexible` plus `TextOverflow.ellipsis`, this goes.
      final pv = tester.widget<Text>(find.text('PV 0.80'));
      expect(pv.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('the monthly readout also survives 2.0 scale', (tester) async {
      final touched = ValueNotifier<int?>(1);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: true,
            buckets: _buckets(count: 6),
            touchedBucketNotifier: touched,
          ),
          width: 320,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // A full date label is the widest string in the readout.
      expect(find.text('30/09/2026'), findsWidgets);
    });
  });

  group('ChartCard semantics', () {
    testWidgets('describes the chart and its interval count to a screen reader',
        (tester) async {
      // Disposed at the end of the body, not through addTearDown.
      // `_runTestBody` calls `_endOfTestVerifications`, and therefore
      // `_verifySemanticsHandlesWereDisposed`, before any addTearDown callback
      // runs -- so a tearDown-disposed handle is still live when it is checked
      // and the test fails for a reason that has nothing to do with the card.
      // `energy_summary_card_test.dart` records the same trap from this side.
      final handle = tester.ensureSemantics();
      final touched = ValueNotifier<int?>(null);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(count: 24),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Energy bar chart showing 24 intervals'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the interval count in the label tracks the real bucket count',
        (tester) async {
      final handle = tester.ensureSemantics();
      final touched = ValueNotifier<int?>(null);
      addTearDown(touched.dispose);

      await tester.pumpWidget(
        _wrap(
          ChartCard(
            theme: AppTheme.light,
            monthly: false,
            buckets: _buckets(count: 7),
            touchedBucketNotifier: touched,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Energy bar chart showing 7 intervals'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('ChartCard renders across the three themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark, AppTheme.dracula]) {
      testWidgets('$theme paints without throwing', (tester) async {
        final touched = ValueNotifier<int?>(2);
        addTearDown(touched.dispose);

        await tester.pumpWidget(
          _wrap(
            ChartCard(
              theme: theme,
              monthly: false,
              buckets: _buckets(),
              touchedBucketNotifier: touched,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('PV 0.80'), findsOneWidget);
      });
    }
  });
}