import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_grid.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_specs.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';

/// Pins that a monitored fish reading over its limit is graded by the grid, the
/// same way the greenhouse grid grades its own.
///
/// Found on the test device on 29 September 2026. The Fish page showed turbidity
/// at 2396 NTU with no range caption and no red border while a turbidity limit
/// was configured in the Fish tank alerts section. The grid turned out to be
/// correct — what was wrong was the stored data — but nothing covered this
/// particular spec, so the two sides could drift apart again without a test
/// noticing. The greenhouse specs and the fish specs share a widget but not a
/// key: the fish page passes `ph`, `suhu` and `turbidity_ntu`, and only the
/// greenhouse ones were exercised.
void main() {
  const seedColor = Color(0xFF35A968);

  // What the device had stored: pH 6-8.5, water 20-35, turbidity max 100.
  final thresholds = AlarmThresholds(
    energyAlerts: true,
    environmentAlerts: true,
    lowSoc: 20,
    staleMinutes: 10,
    offlineMinutes: 60,
    fishAlerts: true,
    fishPhMin: 6,
    fishPhMax: 8.5,
    fishTempMin: 20,
    fishTempMax: 35,
    fishTurbidityMax: 100,
  );

  final values = <String, double>{
    'ph': 6.38,
    'suhu': 30.3,
    'turbidity_ntu': 2396,
    'water_level_percent': 69.3,
  };

  Widget wrap(MetricGrid grid) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: grid,
          ),
        ),
      );

  group('Fish water quality grid, turbidity over its limit', () {
    testWidgets('prints the range caption for turbidity', (tester) async {
      await tester.pumpWidget(wrap(MetricGrid(
        title: 'Water Quality',
        specs: kFishSpecs,
        values: values,
        isDark: true,
        seedColor: seedColor,
        thresholds: thresholds,
        limitLabelFor: (spec) => environmentLimitLabel(spec, thresholds),
        showGridColors: thresholds.fishAlerts,
        staleMinutes: 10,
        lastUpdate: DateTime.now(),
        columns: 2,
      )));

      // The caption is the only place the configured limit is visible, so if it
      // is missing the user cannot tell a monitored reading from an
      // informational one.
      expect(
        find.text('≤ 100'),
        findsOneWidget,
        reason: 'Turbidity has a configured maximum of 100 NTU, so the card must '
            'caption it. Without the caption the reading looks unmonitored.',
      );
    });

    testWidgets('counts turbidity as out of range', (tester) async {
      await tester.pumpWidget(wrap(MetricGrid(
        title: 'Water Quality',
        specs: kFishSpecs,
        values: values,
        isDark: true,
        seedColor: seedColor,
        thresholds: thresholds,
        limitLabelFor: (spec) => environmentLimitLabel(spec, thresholds),
        showGridColors: thresholds.fishAlerts,
        staleMinutes: 10,
        lastUpdate: DateTime.now(),
        columns: 2,
      )));

      expect(
        find.text('1 out of range'),
        findsOneWidget,
        reason: '2396 NTU is over the configured 100 NTU maximum, so the grid '
            'must say so. A turbidity alarm armed at the same limit would '
            'notify, and a page that stays silent while a notification fires is '
            'the disagreement this widget exists to prevent.',
      );
    });
  });
}
