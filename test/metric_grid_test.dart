import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_grid.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  // Slot names, not English words — the grid is a terminal panel now. The
  // telemetry keys stay as the device publishes them, which is the whole reason
  // the two fields are separate.
  final specs = [
    const MetricSpec(
      'temp_dht',
      'AMBIENT_T',
      '°C',
      Icons.thermostat,
      metric: 'temp_dht',
      decimals: 1,
    ),
    const MetricSpec(
      'humidity_dht',
      'HUMIDITY',
      '%',
      Icons.water_drop,
      metric: 'humidity_dht',
      decimals: 1,
    ),
    const MetricSpec(
      'ph',
      'PH',
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
      'WATER_T',
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
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      // The heading is the panel's red slot name, uppercased.
      expect(find.text('ENVIRONMENT'), findsOneWidget);
      // One TerminalRow per spec, in spec order.
      expect(find.byType(TerminalRow), findsNWidgets(5));
      for (final label in ['AMBIENT_T', 'HUMIDITY', 'PH', 'TDS', 'WATER_T']) {
        expect(find.text(label), findsOneWidget);
      }
      // `slotNumber` right-trims trailing zeros — the device reported a whole
      // number, so a tabular column says so instead of implying precision.
      // Scoped to the row: the meter's right caption repeats the value on
      // purpose, so an unscoped finder sees each metered figure twice.
      final rows = find.byType(TerminalRow);
      for (final figure in ['25', '60', '6.5', '800', '24']) {
        expect(
          find.descendant(of: rows, matching: find.text(figure)),
          findsOneWidget,
        );
      }
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
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('ENVIRONMENT'), findsOneWidget);
      expect(find.text('1 OUT OF RANGE'), findsOneWidget);
      // The breached row is the one marked alert.
      final alertRows = tester
          .widgetList<TerminalRow>(find.byType(TerminalRow))
          .where((row) => row.alert)
          .map((row) => row.label)
          .toList();
      expect(alertRows, ['AMBIENT_T']);
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
            thresholds: thresholds,
            lastUpdate: DateTime.now().subtract(const Duration(minutes: 30)),
            staleMinutes: 10,
          ),
        ),
      );

      expect(find.text('STALE DATA'), findsOneWidget);
    });

    testWidgets('renders with null values', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: specs,
            values: null,
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('ENVIRONMENT'), findsOneWidget);
      // One per row: `slotNumber` returns '--' for a missing reading.
      expect(find.text('--'), findsNWidgets(5));
    });

    // Was "renders in dark mode", which used to differ from the first test only
    // by the seed it passed. There is one appearance now, so the two were the
    // same pump; kept as a plain render check because an uninstrumented grid
    // laying out its specs is the thing every other test here depends on.
    testWidgets('renders without overflow', (tester) async {
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
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ENVIRONMENT'), findsOneWidget);
    });

    testWidgets('renders one row per spec regardless of columns',
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
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
            columns: 2,
          ),
        ),
      );

      // `columns` is still accepted — the call sites pass it — but the table is
      // never laid out side-by-side, so it cannot produce a half-empty row.
      expect(find.text('ENVIRONMENT'), findsOneWidget);
      expect(find.byType(TerminalRow), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows limit labels when limitLabelFor is provided',
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

      expect(find.text('ENVIRONMENT'), findsOneWidget);
      // The captioned range is the meter under the row, and an unwatched spec
      // has no caption at all.
      final leftCaptions = tester
          .widgetList<TerminalMeter>(find.byType(TerminalMeter))
          .map((m) => m.leftCaption)
          .where((c) => c != null)
          .length;
      expect(leftCaptions, greaterThan(0));
    });

    testWidgets('draws no meter for an unwatched spec', (tester) async {
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
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
            limitLabelFor: (spec) =>
                spec.metric == null ? null : '0 – 100',
          ),
        ),
      );

      // Three of the four monitored specs have a two-ended range. `tds_ppm` is
      // a floor with no ceiling — an unbounded maximum is deliberate, see
      // `defaultTdsMin` — so it gets a caption and no bar. The unwatched spec
      // has neither, because a bar with no scale is a shape.
      expect(find.byType(TerminalMeter), findsNWidgets(3));
    });

    testWidgets('suppresses the breach colour when showGridColors is false',
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
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
            showGridColors: false,
          ),
        ),
      );

      // The reading itself is still shown — only the "out of range" verdict
      // goes, because the user switched these limits off in Settings.
      expect(
        find.descendant(
          of: find.byType(TerminalRow),
          matching: find.text('45'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 OUT OF RANGE'), findsNothing);
      expect(
        tester
            .widgetList<TerminalRow>(find.byType(TerminalRow))
            .any((row) => row.alert),
        isFalse,
      );
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
            thresholds: thresholds,
            lastUpdate: DateTime.now().subtract(const Duration(minutes: 30)),
            staleMinutes: 10,
            showGridColors: false,
          ),
        ),
      );

      // A dead sensor is a fact about the data, not a configured limit, so it
      // still speaks up with alerts off.
      expect(find.text('STALE DATA'), findsOneWidget);
    });

    testWidgets('handles empty specs list', (tester) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: const [],
            values: const {},
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('ENVIRONMENT'), findsOneWidget);
      expect(find.byType(TerminalRow), findsNothing);
    });
  });
}