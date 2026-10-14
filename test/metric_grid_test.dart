import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
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
    const MetricSpec('ph', 'PH', '', Icons.science, metric: 'ph', decimals: 2),
    const MetricSpec(
      'tds_ppm',
      'TDS',
      'ppm',
      Icons.opacity,
      metric: 'tds_ppm',
      decimals: 0,
    ),
    // Informational only — no configured limit, so never graded.
    const MetricSpec('water_temp', 'WATER_T', '°C', Icons.waves, decimals: 1),
  ];

  final thresholds = AlarmThresholds.defaults;

  /// The declared line box of every value figure the grid drew.
  ///
  /// **This is the declaration, not the size that reaches the glass, and the
  /// distinction is worth keeping rather than papering over.** A value sits
  /// inside a `FittedBox(scaleDown)`, and `FittedBox` scales with a
  /// *transform* rather than by re-laying out its child - so the child's own
  /// size is what it would have been unscaled. Measured: `Heavily overcast` at a
  /// 2.0 font scale reports 53 dp, its full unscaled height, inside a 160 dp
  /// box. A height assertion cannot see a shrink.
  ///
  /// **That is why there is no scale assertion here, and it took a probe to
  /// learn.** Reading the applied scale as the ratio of the `FittedBox`'s width
  /// to its child's, every value on this grid measures between 1.8 and 4.5 -
  /// the grid draws one short number per row and never shrinks any of them. A
  /// guard that cannot fail is worse than no guard, because it reads as
  /// coverage. Where a shrink genuinely happens is the period summary, whose
  /// rows carry `min / avg / max` triples, and that panel is the one that names
  /// a size for them.
  ///
  /// **Matched on the size rather than the token, because `TerminalRow` paints
  /// `valueStyle.copyWith(color:)`.** An `identical` check against
  /// `AppType.slotValue` matches nothing, which is a test that passes on an empty
  /// list and asserts nothing.
  List<double> valueHeights(WidgetTester tester) {
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .where((t) => t.text.style?.fontSize == AppType.slotValue.fontSize)
        .map((t) {
          final box =
              find.byWidget(t).evaluate().single.renderObject
                  as RenderParagraph;
          return box.size.height;
        })
        .toList();
  }

  group('MetricGrid', () {
    // **One size for every value, and it is the Power page's 24 sp.** The user
    // asked for Environment and Fish to look like Power, and the difference was
    // scale: `slotValue` was 15 while `TelemetryCard`'s figure was 24. This
    // pins the declared size rather than the token that is named, because a
    // test reading the token back would pass even if `TerminalRow` painted the
    // value at a different size.
    testWidgets('every value is declared at the Power page figure size', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'ENVIRONMENT',
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
      await tester.pumpAndSettle();

      final heights = valueHeights(tester);
      expect(
        heights,
        isNotEmpty,
        reason: 'the grid drew no value figures to measure',
      );
      // 24 sp at the token's own line height is 26.4 dp. Tolerance is the
      // renderer's rounding, not a design slack.
      for (final h in heights) {
        expect(
          h,
          closeTo(26.4, 0.5),
          reason:
              'a value is declared $h dp tall, so it is not the 24 sp figure '
              'the Power page uses',
        );
      }
    });

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

    testWidgets('renders one row per spec regardless of columns', (
      tester,
    ) async {
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

    testWidgets('shows limit labels when limitLabelFor is provided', (
      tester,
    ) async {
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

    // **One cell printed two different numbers for one reading.** The row above
    // the bar formats at `spec.decimals`; the bar's right caption used
    // `slotNumber`'s default of 1 and ignored the spec entirely, so a spec that
    // declares fewer digits — `turbidity_ntu` declares 0, the sensor is good to
    // a few percent — drew `2396` directly above `2396.5`.
    testWidgets('the value and the meter caption agree on precision', (
      tester,
    ) async {
      // A two-sided limit the default thresholds actually carry — TDS keeps no
      // upper bound, so it draws no meter at all — declared at fewer digits
      // than `slotNumber` defaults to.
      const coarse = [
        MetricSpec(
          'temp_dht',
          'AMBIENT_T',
          '°C',
          Icons.thermostat,
          metric: 'temp_dht',
          decimals: 0,
        ),
      ];
      await tester.pumpWidget(
        wrap(
          MetricGrid(
            title: 'Environment',
            specs: coarse,
            values: const {'temp_dht': 25.4},
            thresholds: thresholds,
            lastUpdate: DateTime.now(),
          ),
        ),
      );

      final rendered = tester
          .widgetList<TerminalMeter>(find.byType(TerminalMeter))
          .map((m) => m.rightCaption)
          .whereType<String>();
      expect(rendered, contains('25'));
      // The un-decimalised reading must not survive anywhere in the cell.
      expect(find.text('25.4'), findsNothing);
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
            limitLabelFor: (spec) => spec.metric == null ? null : '0 – 100',
          ),
        ),
      );

      // Three of the four monitored specs have a two-ended range. `tds_ppm` is
      // a floor with no ceiling — an unbounded maximum is deliberate, see
      // `defaultTdsMin` — so it gets a caption and no bar. The unwatched spec
      // has neither, because a bar with no scale is a shape.
      expect(find.byType(TerminalMeter), findsNWidgets(3));
    });

    testWidgets('suppresses the breach colour when showGridColors is false', (
      tester,
    ) async {
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

    testWidgets('keeps the stale tag even when showGridColors is false', (
      tester,
    ) async {
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
