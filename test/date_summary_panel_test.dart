import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/date_summary_panel.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';
import 'package:plts_monitoring/utils/date_summary_stats.dart';

TelemetryPoint _point(DateTime at, double value) =>
    TelemetryPoint(timestamp: at, value: value);

/// A known day, minute-spaced so the trapezoid integral is checkable by hand.
List<TelemetryPoint> _series(
  DateTime start,
  List<double> values, {
  Duration step = const Duration(minutes: 30),
}) => [
  for (var i = 0; i < values.length; i++)
    _point(start.add(step * i), values[i]),
];

Future<void> _pump(
  WidgetTester tester,
  DateSummaryPanel panel,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: panel),
      ),
    ),
  );
}

void main() {
  final day = DateTime(2026, 10, 5);

  group('periodStatsFor', () {
    test('reduces a known series to min / avg / max', () {
      final stats = periodStatsFor([30, 20, 40, 25]);
      expect(stats.minimum, 20);
      expect(stats.average, closeTo(28.75, 1e-9));
      expect(stats.maximum, 40);
      expect(stats.samples, 4);
      expect(stats.hasData, isTrue);
    });

    test('an empty list is absent, not zero', () {
      // The regression this guards: a zeroed struct renders `0 / 0 / 0`, which
      // is a claim that the greenhouse read zero degrees for a whole day.
      final stats = periodStatsFor(const []);
      expect(stats.hasData, isFalse);
      expect(stats.minimum, isNull);
      expect(stats.average, isNull);
      expect(stats.maximum, isNull);
      expect(stats.samples, 0);
    });

    test('a single sample is a period of one, and is reported as one', () {
      final stats = periodStatsFor([28]);
      expect(stats.samples, 1);
      expect(stats.minimum, 28);
      expect(stats.maximum, 28);
    });

    test('breach is decided by the extrema, not the average', () {
      // A night at 12 and a day at 30 averages to a comfortable 21. Averaging
      // is how a cold snap gets reported as a normal week.
      final stats = periodStatsFor([30, 12]);
      expect(stats.average, closeTo(21, 1e-9));
      expect(stats.breached(min: 15, max: 35), isTrue);
    });

    test('a value exactly on the limit is not a breach', () {
      // Strict comparison, matching `AlarmComparison`: the boundary is the
      // configured range, not outside it.
      expect(periodStatsFor([15, 35]).breached(min: 15, max: 35), isFalse);
      expect(periodStatsFor([14.9, 35]).breached(min: 15, max: 35), isTrue);
      expect(periodStatsFor([15, 35.1]).breached(min: 15, max: 35), isTrue);
    });

    test('an unmonitored reading cannot have breached', () {
      expect(periodStatsFor([9999]).breached(), isFalse);
    });

    test('null points are absent rather than an error', () {
      expect(periodStatsForPoints(null).hasData, isFalse);
      expect(periodStatsForPoints(const []).hasData, isFalse);
    });
  });

  group('energyForCoveredPeriod', () {
    final start = day;
    final end = day.add(const Duration(hours: 1));

    test('integrates a covered window', () {
      // Two points an hour apart at a constant 1000 W is one kWh.
      final points = _series(
        start,
        [1000, 1000],
        step: const Duration(hours: 1),
      );
      expect(
        energyForCoveredPeriod(points: points, start: start, end: end),
        closeTo(1.0, 1e-9),
      );
    });

    test('returns null when the window predates the fetched history', () {
      // The live case: `_energyHistory` is a rolling fortnight and the date
      // picker reaches back ninety days. `energyForPeriod` alone returns 0.0
      // here, which would print `0.00 kWh` for a day nobody looked at.
      final points = _series(day, [1000, 1000], step: const Duration(hours: 1));
      final older = day.subtract(const Duration(days: 40));
      expect(
        energyForCoveredPeriod(
          points: points,
          start: older,
          end: older.add(const Duration(hours: 1)),
        ),
        isNull,
      );
    });

    test('returns null for a partially covered window', () {
      // A total computed from half a day is smaller than the real one, so it
      // reads as a quiet day rather than as a gap. That is worse than nothing.
      final points = _series(day, [1000, 1000], step: const Duration(hours: 1));
      expect(
        energyForCoveredPeriod(
          points: points,
          start: day.subtract(const Duration(hours: 1)),
          end: end,
        ),
        isNull,
      );
    });

    test('one point cannot be integrated', () {
      expect(
        energyForCoveredPeriod(
          points: [_point(start, 1000)],
          start: start,
          end: end,
        ),
        isNull,
      );
    });

    test('null history is null, not zero', () {
      expect(
        energyForCoveredPeriod(points: null, start: start, end: end),
        isNull,
      );
    });
  });

  group('DateSummaryStat', () {
    test('renders min / avg / max in the declared order', () {
      const stat = DateSummaryStat(
        label: 'AMBIENT_T',
        unit: '°C',
        stats: PeriodStats(minimum: 18.4, average: 26.24, maximum: 34.9, samples: 3),
      );
      expect(stat.value, '18.4 / 26.2 / 34.9');
    });

    test('an empty period renders as dashes, never as zeros', () {
      const stat = DateSummaryStat(label: 'LUX', unit: 'lx', stats: PeriodStats.empty());
      expect(stat.value, '--');
      expect(stat.value, isNot(contains('0')));
    });

    test('respects the spec decimals', () {
      // pH is logarithmic; three decimals is noise. This is the MetricGrid
      // decimal reaching the summary rather than a second opinion about it.
      const stat = DateSummaryStat(
        label: 'PH',
        decimals: 2,
        stats: PeriodStats(minimum: 6.1, average: 7.24, maximum: 7.31, samples: 3),
      );
      expect(stat.value, '6.1 / 7.24 / 7.31');
    });
  });

  group('DateSummaryPanel', () {
    testWidgets('shows the empty state and no zeros for a day with no data', (
      tester,
    ) async {
      await _pump(
        tester,
        const DateSummaryPanel(periodLabel: '05/10/2026'),
      );

      expect(find.text('NO_DATA'), findsOneWidget);
      expect(find.text('Nothing recorded'), findsOneWidget);
      expect(find.text('POWER'), findsNothing);
      expect(
        find.textContaining('0.00'),
        findsNothing,
        reason: 'a day with no history must not print an energy total of zero',
      );
    });

    testWidgets('reports net as generated minus used', (tester) async {
      await _pump(
        tester,
        const DateSummaryPanel(
          periodLabel: '05/10/2026',
          solarKwh: 4.21,
          loadKwh: 6.08,
        ),
      );

      expect(find.text('4.21'), findsOneWidget);
      expect(find.text('6.08'), findsOneWidget);
      expect(find.text('-1.87'), findsOneWidget);
    });

    testWidgets('net is positive when the array covered the house', (
      tester,
    ) async {
      await _pump(
        tester,
        const DateSummaryPanel(
          periodLabel: '05/10/2026',
          solarKwh: 6.08,
          loadKwh: 4.21,
        ),
      );
      expect(find.text('1.87'), findsOneWidget);
      expect(find.text('-1.87'), findsNothing);
    });

    testWidgets('net is unknown when either side is unknown', (tester) async {
      // The out-of-window day: generation is missing, so a subtraction from it
      // would be a fabricated balance.
      await _pump(
        tester,
        const DateSummaryPanel(
          periodLabel: '05/10/2026',
          solarKwh: 4.21,
        ),
      );
      expect(find.text('4.21'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(2));
      expect(find.text('0.00'), findsNothing);
    });

    testWidgets('renders environment and fish min/avg/max rows', (tester) async {
      await _pump(
        tester,
        const DateSummaryPanel(
          periodLabel: '05/10/2026',
          solarKwh: 4.21,
          loadKwh: 3.08,
          environment: [
            DateSummaryStat(
              label: 'AMBIENT_T',
              unit: '°C',
              limitLabel: '15–35',
              stats: PeriodStats(
                minimum: 18.4,
                average: 26.1,
                maximum: 34.9,
                samples: 48,
              ),
            ),
            DateSummaryStat(
              label: 'HUMIDITY',
              unit: '%',
              limitLabel: '40–85',
              stats: PeriodStats(
                minimum: 55,
                average: 70,
                maximum: 88,
                samples: 48,
              ),
            ),
            DateSummaryStat(
              label: 'LUX',
              unit: 'lx',
              stats: PeriodStats(minimum: 0, average: 300, maximum: 980, samples: 48),
            ),
          ],
          fish: [
            DateSummaryStat(
              label: 'PH',
              decimals: 2,
              limitLabel: '6.5–8',
              stats: PeriodStats(
                minimum: 6.9,
                average: 7.2,
                maximum: 7.4,
                samples: 48,
              ),
            ),
          ],
        ),
      );

      expect(find.text('POWER'), findsOneWidget);
      expect(find.text('ENVIRONMENT  MIN / AVG / MAX'), findsOneWidget);
      expect(find.text('FISH  MIN / AVG / MAX'), findsOneWidget);
      expect(find.text('AMBIENT_T'), findsOneWidget);
      expect(find.text('18.4 / 26.1 / 34.9'), findsOneWidget);
      expect(find.text('0 / 300 / 980'), findsOneWidget);
      expect(find.text('6.9 / 7.2 / 7.4'), findsOneWidget);
      // The configured band rides the row, borrowed from the grid's caption
      // builder rather than re-derived here.
      expect(find.text('15–35'), findsOneWidget);
      expect(find.text('6.5–8'), findsOneWidget);
      // A unit-less spec (pH) must not leave a gap where the unit would be.
      expect(find.text('°C'), findsOneWidget);
    });

    testWidgets('marks a breach and counts it in the header', (tester) async {
      await _pump(
        tester,
        const DateSummaryPanel(
          periodLabel: '05/10/2026',
          solarKwh: 4.21,
          loadKwh: 3.08,
          environment: [
            DateSummaryStat(
              label: 'AMBIENT_T',
              unit: '°C',
              breached: true,
              stats: PeriodStats(
                minimum: 12.4,
                average: 24.1,
                maximum: 34.9,
                samples: 48,
              ),
            ),
            DateSummaryStat(
              label: 'HUMIDITY',
              unit: '%',
              stats: PeriodStats(
                minimum: 55,
                average: 70,
                maximum: 88,
                samples: 48,
              ),
            ),
          ],
        ),
      );

      // `TerminalTag` upper-cases its text; the panel passes it in sentence case
      // so the caller is not the thing that decides the panel's casing.
      expect(find.text('1 OUT OF RANGE'), findsOneWidget);
      // Only the breaching row is red. Red is the panel's one severity colour,
      // so a second row wearing it would mean a second thing.
      final alertRows = tester
          .widgetList<TerminalRow>(find.byType(TerminalRow))
          .where((row) => row.alert)
          .toList();
      expect(alertRows, hasLength(1));
      expect(alertRows.single.label, 'AMBIENT_T');
    });

    testWidgets('says nothing about breaches when nothing breached', (
      tester,
    ) async {
      await _pump(
        tester,
        const DateSummaryPanel(
          periodLabel: '05/10/2026',
          solarKwh: 4.21,
          loadKwh: 3.08,
          environment: [
            DateSummaryStat(
              label: 'AMBIENT_T',
              unit: '°C',
              stats: PeriodStats(
                minimum: 18,
                average: 24,
                maximum: 34,
                samples: 48,
              ),
            ),
          ],
        ),
      );

      // No "all within range" badge. A green chip on a healthy day is a verdict
      // on data the reader did not ask about.
      expect(find.textContaining('OUT OF RANGE'), findsNothing);
    });

    testWidgets('names the period it is summarising', (tester) async {
      await _pump(
        tester,
        const DateSummaryPanel(periodLabel: '05/10/2026 – 09/10/2026'),
      );
      expect(find.text('05/10/2026 – 09/10/2026'), findsOneWidget);
    });

    testWidgets('announces itself as a period summary, not as Overview', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const DateSummaryPanel(periodLabel: '05/10/2026', solarKwh: 1, loadKwh: 1),
      );

      // `TerminalPanel` hardcoded 'Overview' before the parameter existed, which
      // announced this panel as the live overview — a factually wrong first
      // impression for a screen-reader user on a page about a past day.
      //
      // Scoped to the `TerminalPanel` itself, not to an `AppCard`: the panel is
      // built from raw tokens rather than `AppCard` (its build comment explains
      // why — the dead `stamped` shadow), so an `AppCard` finder here matched
      // nothing and the assertion read as "no label anywhere".
      expect(
        find.descendant(
          of: find.byType(TerminalPanel),
          matching: find.bySemanticsLabel('Period summary'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
