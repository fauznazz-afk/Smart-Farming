import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/live_power_card.dart';

void main() {
  const seedColor = Color(0xFF35A968);

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('LivePowerCard', () {
    testWidgets('renders with normal data', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: '5s ago',
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Live power'), findsOneWidget);
      expect(find.text('Solar'), findsOneWidget);
      expect(find.text('House'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('renders with stale data', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: true,
            pzemAgeLabel: '2m ago',
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('2m ago'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders unavailable state when pvPower is null', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: null,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.text('Power flow unavailable until the inverter reports'),
        findsOneWidget,
      );
    });

    // The sign convention is the current BMS's, measured on 27 September 2026:
    // negative watts means the pack is DISCHARGING. The previous pack reported
    // the opposite, and this test was written against that one — it had never
    // run, because the filename did not match the `*_test.dart` pattern.
    testWidgets('shows discharging state for negative battery power', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Discharging'), findsOneWidget);
      expect(find.byIcon(Icons.battery_5_bar_rounded), findsOneWidget);
    });

    testWidgets('shows charging state for positive battery power', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: 100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Charging'), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full), findsOneWidget);
    });

    testWidgets('shows standby state for zero battery power', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: 0,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Standby'), findsOneWidget);
    });

    testWidgets('shows warning when array is not covering load', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 100,
            acPower: 500,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.text('The array is not covering the house load right now'),
        findsOneWidget,
      );
    });

    testWidgets('shows spare power when array covers load', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.textContaining('The array covers the house'),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: '5s ago',
            theme: AppTheme.dark,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Live power'), findsOneWidget);
    });

    testWidgets('renders without age label', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Live power'), findsOneWidget);
    });

    // Dracula is the reason this widget takes an `AppTheme` and not a bool, so
    // the test that matters here is the one that asks for a *surface* Dracula
    // derives separately rather than one that just checks it still renders.
    //
    // The charge bar's track is the sharpest case in the file:
    // `AppSurfaces.trackDracula` is `#1E1F29` and `trackDark` is `#131A18`, and
    // Dracula's is the one that is *darker than its own page* — the inverse of
    // both existing modes. A `bool isDark` threaded down here would render
    // Dracula's card with the app's dark track, which still builds, still finds
    // every text and is wrong in a way only a pixel comparison catches.
    //
    // Asserting against the token rather than a hex is deliberate, for the
    // reason `color_helpers_test.dart` documents about its own surface lists: a
    // literal written here is a copy, and copies drift silently.
    for (final theme in AppTheme.values) {
      testWidgets('paints the charge track with ${theme.name} track token',
          (tester) async {
        await tester.pumpWidget(
          wrap(
            LivePowerCard(
              pvPower: 500,
              acPower: 200,
              batteryPower: -100,
              soc: 75,
              pzemStale: false,
              pzemAgeLabel: '5s ago',
              theme: theme,
              seedColor: seedColor,
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == AppSurfaces.track(theme),
          ),
          findsWidgets,
          reason: 'AppSurfaces.track(${theme.name}) is '
              '${AppSurfaces.track(theme)} and no bar behind the charge figure '
              'uses it',
        );
      });
    }
  });

  group('LivePowerCard with nothing reporting', () {
    // **Absence is not zero, and this group is the regression guard for that.**
    //
    // `acPower`, `batteryPower` and `soc` were `double` with `?? 0.0` at the call
    // site, so a device that had never sent a value printed `House 0 W` and
    // `Charge 0%` and then went on to state "The array covers the house load" --
    // a comparison of a real solar figure against a fabricated zero. Three widgets
    // on the Overview page disagreed about what absence means, and the one with
    // the non-nullable field was the one that made a claim.
    //
    // `LivePowerCard` already handled the solar side correctly
    // ("Power flow unavailable until the inverter reports"), which is why this is
    // a nullability change and not a new idea: the card already had the right
    // answer for one of its three terms.

    LivePowerCard card({
      double? pvPower = 500,
      double? acPower,
      double? batteryPower,
      double? soc,
    }) =>
        LivePowerCard(
          pvPower: pvPower,
          acPower: acPower,
          batteryPower: batteryPower,
          soc: soc,
          pzemStale: false,
          pzemAgeLabel: '5s ago',
          theme: AppTheme.light,
          seedColor: seedColor,
        );

    testWidgets('prints -- for every missing figure', (tester) async {
      await tester.pumpWidget(wrap(card()));

      expect(find.text('--'), findsNWidgets(3));
      // The three term labels survive, so the row does not collapse or shift.
      expect(find.text('Solar'), findsOneWidget);
      expect(find.text('House'), findsOneWidget);
    });

    testWidgets('does not claim the array covers the house load',
        (tester) async {
      await tester.pumpWidget(wrap(card()));

      expect(
        find.text('The array is just covering the house load'),
        findsNothing,
      );
      expect(
        find.text('The array covers the house, 300 W spare'),
        findsNothing,
      );
      expect(
        find.text('The array is not covering the house load right now'),
        findsNothing,
      );
      expect(
        find.text('House draw unavailable until the meter reports'),
        findsOneWidget,
      );
    });

    testWidgets('names the pack Battery rather than inventing a direction',
        (tester) async {
      await tester.pumpWidget(wrap(card()));

      // `batteryChargeState` calls a zero reading "standby". An absent reading is
      // not standby, and the label must not claim a direction.
      expect(find.text('Standby'), findsNothing);
      expect(find.text('Battery'), findsOneWidget);
    });

    testWidgets('still draws solar when only the meter is silent',
        (tester) async {
      await tester.pumpWidget(wrap(card(acPower: 200, batteryPower: -100)));

      expect(find.text('500'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(
        find.text('The array covers the house, 300 W spare'),
        findsOneWidget,
      );
    });

    testWidgets('tells a screen reader the real charge', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(card(soc: 64)));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'State of charge: 64 percent')),
        findsOneWidget,
      );
      expect(find.text('64%'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('tells a screen reader the charge is unknown', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(card()));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'State of charge: not reporting')),
        findsOneWidget,
      );
      // And not the old sentence, which asserted a measurement.
      expect(
        find.bySemanticsLabel(RegExp(r'State of charge: 0 percent')),
        findsNothing,
      );

      handle.dispose();
    });
  });

  group('LivePowerCard figure sizing', () {
    // The three flow terms share the card's content width, which is about 89 dp
    // each at the documented 381 dp viewport. A battery figure of `-1250` needs
    // roughly that much for the sign, four digits, icon, gaps and unit at 24 sp,
    // so any system font scale above 1.0 used to overflow the slot and draw the
    // stripe across the number.
    //
    // `Flexible` plus `FittedBox.scaleDown` rather than `TextOverflow.ellipsis`,
    // because this project has shipped a truncated figure twice -- `109....` and
    // `239...` -- and both times the toolchain was green.

    const viewports = <String, double>{
      '381 dp': 381,
      '320 dp': 320,
    };

    viewports.forEach((label, width) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('a four-digit negative figure fits at $label, scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(width, 800))
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: LivePowerCard(
                      pvPower: 1250,
                      acPower: 1250,
                      batteryPower: -1250,
                      soc: 75,
                      pzemStale: false,
                      pzemAgeLabel: '5s ago',
                      theme: AppTheme.light,
                      seedColor: seedColor,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // And the figure is not abbreviated away, which is the whole reason
          // this is a FittedBox and not an ellipsis.
          expect(find.text('-1250'), findsOneWidget);
        });
      }
    });
  });
}
