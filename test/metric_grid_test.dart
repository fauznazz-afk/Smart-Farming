import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_grid.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';

void main() {
  const seedColor = Color(0xFF35A968);

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  final specs = [
    const MetricSpec(
      'temp_dht',
      'Temperature',
      '°C',
      Icons.thermostat,
      metric: 'temp_dht',
      decimals: 1,
    ),
    const MetricSpec(
      'humidity_dht',
      'Humidity',
      '%',
      Icons.water_drop,
      metric: 'humidity_dht',
      decimals: 1,
    ),
    const MetricSpec(
      'ph',
      'pH',
      '',
      Icons.science,
      metric: 'ph',
      decimals: 2,
    ),
    const MetricSpec(
      'tds_ppm',
      'TDS',
      'ppm',
      Icons.opacity,
      metric: 'tds_ppm',
      decimals: 0,
    ),
    // Informational only — no configured limit, so never graded.
    const MetricSpec(
      'water_temp',
      'Water Temp',
      '°C',
      Icons.waves,
      decimals: 1,
    ),
  ];

  final thresholds = AlarmThresholds.defaults;

  group('MetricGrid', () {
    testWidgets('renders with all values in range', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 25.0,
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
      // Value and unit are separate Text widgets — "25.0" beside "°C" — so the
      // value is what can be asserted as one string.
      expect(find.text('25.0'), findsOneWidget);
      expect(find.text('60.0'), findsOneWidget);
      expect(find.text('6.50'), findsOneWidget);
      expect(find.text('800'), findsOneWidget);
      expect(find.text('24.0'), findsOneWidget);
    });

    testWidgets('renders with some values out of range', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 45.0, // above max
              'humidity_dht': 60.0, // in range
              'ph': 6.5, // in range
              'tds_ppm': 800, // in range
              'water_temp': 24.0, // in range
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
      expect(find.text('1 out of range'), findsOneWidget);
    });

    testWidgets('renders stale tag when data is old', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 25.0,
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now().subtract(const Duration(minutes: 30)),
            staleMinutes: 10,
          ),
        ),
      );

      expect(find.text('Stale data'), findsOneWidget);
    });

    testWidgets('renders with null values', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: null,
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(5));
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 25.0,
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: true,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
    });

    testWidgets('renders with custom column count', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 25.0,
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
            columns: 2,
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
    });

    testWidgets('shows limit labels when limitLabelFor is provided', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 25.0,
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
            limitLabelFor: (spec) {
              if (spec.metric == null) return null;
              final min = thresholds.minFor(spec.metric!);
              final max = thresholds.maxFor(spec.metric!);
              if (min == null || max == null) return null;
              return '$min – $max';
            },
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
    });

    testWidgets('suppresses the breach tag when showGridColors is false',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 45.0, // above max, but alerts are switched off
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
            showGridColors: false,
          ),
        ),
      );

      // The reading itself is still shown — only the "out of range" verdict
      // goes, because the user switched these limits off in Settings.
      expect(find.text('45.0'), findsOneWidget);
      expect(find.text('1 out of range'), findsNothing);
    });

    testWidgets('keeps the stale tag even when showGridColors is false',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: const {
              'temp_dht': 25.0,
              'humidity_dht': 60.0,
              'ph': 6.5,
              'tds_ppm': 800,
              'water_temp': 24.0,
            },
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now().subtract(const Duration(minutes: 30)),
            staleMinutes: 10,
            showGridColors: false,
          ),
        ),
      );

      // A dead sensor is a fact about the data, not a configured limit, so it
      // still speaks up with alerts off.
      expect(find.text('Stale data'), findsOneWidget);
    });

    testWidgets('handles empty specs list', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: const [],
            values: const {},
            isDark: false,
            seedColor: seedColor,
            performanceMode: true,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
    });
  });
}
