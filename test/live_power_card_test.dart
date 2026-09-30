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
}
