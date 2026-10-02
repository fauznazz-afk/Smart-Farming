import 'package:flutter/material.dart';
// `RenderParagraph`, for `didExceedMaxLines`.
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/system_status_strip.dart';

import 'widget_text_helpers.dart';

/// The first test this widget has ever had.
///
/// It had none, and the reason this file exists is a screenshot rather than a
/// reasoning: on the Xiaomi 24090RA29G at a 2.0 system font the strip rendered
///
/// ```text
///   Bat...      AC ...      Ala...
///   99%         Sta...      1
///   min 1...    221 V ...   active
/// ```
///
/// Six fragments, one of them the word **Stable** — the verdict, and the single
/// thing on this strip that cannot be ambiguous. `flutter analyze` was clean, the
/// release build succeeded and all 609 tests passed, because the three `Text`
/// widgets that produced it were each `maxLines: 1, overflow: ellipsis` and that
/// is not a mistake any linter has an opinion about.
///
/// The widths here are **screen** widths and the card is wrapped in the
/// dashboard's page margin, so the card is 48 dp narrower than the number in
/// the test name. A test that renders the card edge to edge is measuring a
/// widget 48 dp wider than the one that ships; that mistake is what let
/// `LivePowerCard` pass here while the device showed `Sola` for `Solar`.
void main() {
  const seedColor = Color(0xFF35A968);

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  /// Both sides arrive as record typedefs, so the absent case is expressed by a
  /// null field rather than by a flag — which is the point the widget's own
  /// typedef doc argues: "a missing reading is not a zero".
  SystemStatusStrip strip({
    double? soc,
    double? acVoltage,
    double? acFrequency,
    int activeAlerts = 0,
  }) =>
      SystemStatusStrip(
        theme: AppTheme.light,
        seedColor: seedColor,
        onOpenBattery: () {},
        lowSocThreshold: 15,
        activeAlerts: activeAlerts,
        battery: (soc: soc, voltage: 12.6, current: -2, power: -30),
        ac: (voltage: acVoltage, current: 0.3, power: 18, frequency: acFrequency),
      );

  Future<void> pumpAt(
    WidgetTester tester, {
    required double widthDp,
    required double scale,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(widthDp, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: wrap(
          atDashboardPageWidth(
            strip(soc: 99, acVoltage: 221, acFrequency: 50, activeAlerts: 1),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('SystemStatusStrip states its facts', () {
    testWidgets('a healthy reading takes the accent, not a status colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(strip(soc: 99, acVoltage: 221, acFrequency: 50)),
      );

      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('99%'), findsOneWidget);
      expect(find.text('min 15%'), findsOneWidget);
      expect(find.text('AC grid'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(find.text('221 V · 50 Hz'), findsOneWidget);
    });

    // "Say nothing when nothing is wrong": with no alarm there is no alarm
    // column, and with a healthy grid there is no `Unstable`. A permanent badge
    // asserting a boring condition is the thing `AGENTS.md` rejected.
    testWidgets('a healthy strip shows no alarm column at all', (tester) async {
      await tester.pumpWidget(
        wrap(strip(soc: 99, acVoltage: 221, acFrequency: 50)),
      );

      expect(find.text('Alarm'), findsNothing);
      expect(find.text('Unstable'), findsNothing);
    });

    testWidgets('an active alarm is the only thing that adds a column', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(strip(soc: 99, acVoltage: 221, acFrequency: 50, activeAlerts: 1)),
      );

      expect(find.text('Alarm'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
    });

    // `Stable` is `|freq - 50| < 2 && 200 < volt < 240`, and both halves are
    // pinned because a strip that calls 219 V stable and 241 V stable is worse
    // than no strip.
    testWidgets('the grid verdict needs both the frequency and the voltage', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(strip(soc: 99, acVoltage: 221, acFrequency: 50)));
      expect(find.text('Stable'), findsOneWidget);

      await tester.pumpWidget(wrap(strip(soc: 99, acVoltage: 221, acFrequency: 47)));
      expect(find.text('Stable'), findsNothing);

      await tester.pumpWidget(wrap(strip(soc: 99, acVoltage: 241, acFrequency: 50)));
      expect(find.text('Stable'), findsNothing);
    });

    testWidgets('an absent state of charge is not printed as 0%', (tester) async {
      await tester.pumpWidget(
        wrap(strip(soc: null, acVoltage: 221, acFrequency: 50)),
      );

      expect(find.text('0%'), findsNothing);
    });
  });

  group('SystemStatusCard survives a large system font', () {
    // The regression, as a test. Read off the laid-out paragraph rather than
    // inferred from the widget tree: the tree still reports `Stable` in full
    // after the engine has drawn `Sta...`, which is why this passed for as long
    // as it did.
    for (final width in kNarrowWidthsDp) {
      for (final scale in kTextScales) {
        testWidgets('nothing is truncated at ${width.toInt()} dp, scale $scale', (
          tester,
        ) async {
          await pumpAt(tester, widthDp: width, scale: scale);

          expectNothingClipped(
            tester,
            because: 'Six fragments on a dashboard strip is not a reading. The '
                'verdict word matters most: "Sta..." cannot be told from '
                '"Standby" or from a truncated something-else.',
          );
        });
      }
    }

    testWidgets('the strip lays out without overflowing at any scale', (
      tester,
    ) async {
      for (final width in kNarrowWidthsDp) {
        for (final scale in kTextScales) {
          await pumpAt(tester, widthDp: width, scale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: 'something overflowed at ${width.toInt()} dp, scale $scale. '
                'Three equal `Expanded` columns cannot hold their text at 2.0, '
                'and an overflow throws on every frame.',
          );
        }
      }
    });

    // The verdict is the claim this strip makes, so it is the one string that
    // must survive intact rather than merely being present in the tree.
    testWidgets('the verdict word is drawn whole at 2.0', (tester) async {
      await pumpAt(tester, widthDp: 320, scale: 2.0);

      final verdict = tester.renderObject<RenderParagraph>(find.text('Stable'));
      expect(
        verdict.didExceedMaxLines,
        isFalse,
        reason: 'the grid verdict was cut; the user is being told something '
            'they cannot read',
      );
    });
  });
}
