import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/dashboard/charts/chart_data.dart';
import 'package:plts_monitoring/screens/dashboard/utils/date_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/chart_groups.dart';

ChartSeries seriesOf(List<TelemetryPoint> points) => ChartSeries(
  'Power',
  'W',
  points,
  processSpots(points),
  const Color(0xFF1E88E5),
  SeriesStats.fromPoints(points),
);

/// One series of [values], an hour apart, starting 10 March 2026 at 00:00.
List<TelemetryPoint> ramp(List<double> values) => [
  for (var i = 0; i < values.length; i++)
    TelemetryPoint(
      timestamp: DateTime(2026, 3, 10).add(Duration(hours: i)),
      value: values[i],
    ),
];

/// Representative data per prefix: group, then series, then readings.
///
/// Written out rather than generated, because the interesting cases are the ones
/// the hardware actually produces: a discharging battery is negative, a pH
/// sensor drifts in a narrow band, and a lux sensor crosses zero at dusk.
///
/// The three electrical pages supply one group of three series, which is the
/// grouping `chart_groups.dart` documents and the reason its own comment is
/// flagged as making a false claim. See the note there.
Map<String, List<List<List<double>>>> sampleDataByPrefix() => {
  'pv': [
    [
      [12.4, 13.1, 12.9, 0.0], // V
      [0.0, 1.8, 1.6, -0.4], // A
      [0.0, 23.6, 21.0, -5.2], // W
    ],
  ],
  'ac': [
    [
      [228.0, 231.0, 0.0, 229.0], // V
      [0.0, 1.2, -0.6, 0.9], // A
      [0.0, 277.0, -138.0, 206.0], // W
    ],
  ],
  'battery': [
    [
      [13.2, 12.6, 12.1], // V
      [-0.97, -1.4, 0.0], // A, discharging
      [-12.92, -17.6, 0.0], // W
    ],
  ],
  'env': [
    [
      [22.7, 25.1, 23.4],
      [23.9, 27.8, 25.1],
    ], // degC, air and panel: two series sharing an axis is the case the unit
        // rule is actually about
    [
      [78.0, 61.0, 84.0],
    ], // %
    [
      [0.0, 18400.0, 91000.0],
    ], // lx
    [
      [820.0, 1240.0, 1500.0],
    ], // ppm
  ],
  'fish': [
    [
      [6.42, 7.05, 7.75, 6.37],
    ], // pH
    [
      [27.4, 28.1, 26.9],
    ], // degC
    [
      [4.0, 118.0, 2396.0],
    ], // NTU
  ],
};

/// The Y axis for one group's series, using the group's declared anchoring.
ChartBounds boundsFor(ChartGroup group, List<List<double>> seriesData) =>
    ChartBounds.fromSeries([
      for (final values in seriesData) seriesOf(ramp(values)),
    ], zeroAnchored: group.zeroAnchored);

void main() {
  group('niceStep', () {
    test('rounds up to 1 / 2 / 2.5 / 5 x 10^n', () {
      expect(niceStep(4, divisions: 4), closeTo(1, 1e-9));
      expect(niceStep(8, divisions: 4), closeTo(2, 1e-9));
      expect(niceStep(10, divisions: 4), closeTo(2.5, 1e-9));
      expect(niceStep(20, divisions: 4), closeTo(5, 1e-9));
      expect(niceStep(400, divisions: 4), closeTo(100, 1e-9));
    });

    test('never returns zero or a negative step', () {
      expect(niceStep(0), 1);
      expect(niceStep(-5), 1);
      expect(niceStep(double.nan), 1);
      expect(niceStep(double.infinity), 1);
    });

    test('divides the range into at most the requested tick count', () {
      // A raw step of 0.9 over 4 divisions should still give >= 4 intervals.
      final step = niceStep(3.6, divisions: 4);
      expect(3.6 / step, lessThanOrEqualTo(4));
    });
  });

  group('niceTimeStep', () {
    test('snaps to whole minutes', () {
      expect(niceTimeStep(90 * 1000), closeTo(120000, 1e-9));
      expect(niceTimeStep(20 * 60 * 1000), closeTo(30 * 60 * 1000, 1e-9));
    });

    test('handles multi-hour and multi-day spans', () {
      // 4h rounds up to the next listed step, 6h.
      expect(niceTimeStep(4 * 3600 * 1000), closeTo(6 * 3600 * 1000, 1e-9));
      // A 12-day range wants 3-day ticks (12 / 4 = 3).
      expect(niceTimeStep(3 * 24 * 3600 * 1000), closeTo(3 * 86400000, 1e-6));
      // A 90-day range wants ~22-day ticks, widened to the 30-day step.
      expect(
        niceTimeStep(22.5 * 24 * 3600 * 1000),
        closeTo(30 * 86400000, 1e-6),
      );
    });

    test('yields roughly four intervals for a typical range', () {
      const days = [1, 3, 7, 14, 30, 90];
      for (final span in days) {
        final rangeMs = span * 86400000.0;
        final step = niceTimeStep(rangeMs / 4);
        final ticks = rangeMs / step;
        expect(
          ticks,
          inInclusiveRange(1, 8),
          reason: '$span-day range produced $ticks intervals',
        );
      }
    });

    test('only ever rounds the step up, never down', () {
      for (final minutes in [1, 7, 45, 200, 500, 1500, 5000, 20000]) {
        final step = niceTimeStep(minutes * 60 * 1000);
        expect(
          step,
          greaterThanOrEqualTo(minutes * 60 * 1000),
          reason: '${minutes}m rounded down',
        );
      }
    });

    test('caps at one year and rejects invalid input', () {
      expect(
        niceTimeStep(400 * 24 * 3600 * 1000),
        closeTo(365 * 86400000, 1e-6),
      );
      expect(niceTimeStep(0), closeTo(60000, 1e-9));
      expect(niceTimeStep(double.nan), closeTo(60000, 1e-9));
    });
  });

  group('ChartBounds.fromSeries', () {
    TelemetryPoint at(DateTime time, double value) =>
        TelemetryPoint(timestamp: time, value: value);

    test('falls back to a unit square for empty series', () {
      final bounds = ChartBounds.fromSeries([seriesOf(const [])]);
      expect(bounds.minX, 0);
      expect(bounds.maxX, 1);
      expect(bounds.chartInterval, 1);
      expect(bounds.spansMultipleDays, isFalse);
    });

    test('aligns the x axis to round clock boundaries', () {
      // 18:33 through 18:28 next day: raw span is just under 24h.
      final points = [
        at(DateTime(2026, 3, 10, 18, 33), 1),
        at(DateTime(2026, 3, 11, 18, 28), 2),
      ];
      final bounds = ChartBounds.fromSeries([seriesOf(points)]);
      final minTime = DateTime.fromMillisecondsSinceEpoch(bounds.minX.toInt());
      final maxTime = DateTime.fromMillisecondsSinceEpoch(bounds.maxX.toInt());

      expect(minTime.minute, 0, reason: 'minX should land on a round minute');
      expect(maxTime.minute, 0, reason: 'maxX should land on a round minute');
      expect(
        (bounds.maxX - bounds.minX) % bounds.timeInterval,
        closeTo(0, 1e-6),
        reason: 'the span should be a whole number of intervals',
      );
    });

    test('keeps the data inside the padded x range', () {
      final points = [
        at(DateTime(2026, 3, 10, 6, 7), 1),
        at(DateTime(2026, 3, 10, 18, 41), 2),
      ];
      final bounds = ChartBounds.fromSeries([seriesOf(points)]);
      expect(
        bounds.minX,
        lessThanOrEqualTo(DateTime(2026, 3, 10, 6, 7).millisecondsSinceEpoch),
      );
      expect(
        bounds.maxX,
        greaterThanOrEqualTo(
          DateTime(2026, 3, 10, 18, 41).millisecondsSinceEpoch,
        ),
      );
    });

    test('uses a friendly y interval instead of an arbitrary one', () {
      final points = [
        at(DateTime(2026, 3, 10, 1), 0),
        at(DateTime(2026, 3, 10, 2), 303.97),
      ];
      final bounds = ChartBounds.fromSeries([seriesOf(points)]);
      // 303.97 * 1.1 / 4 = 83.6 -> snaps up to 100.
      expect(bounds.chartInterval, closeTo(100, 1e-9));
    });

    test('anchors a non-negative series at zero', () {
      final points = [
        at(DateTime(2026, 3, 10, 1), 5),
        at(DateTime(2026, 3, 10, 2), 9),
      ];
      expect(ChartBounds.fromSeries([seriesOf(points)]).minY, 0);
    });

    // chart_data.dart:127 - `final maxY = maximum <= 0 ? 1.0 : maximum * 1.1;`
    // The `<= 0` branch is a flat 1.0, not a padded multiple of the data. The
    // series that reach it are real: battery power and current are negative
    // while the pack discharges, so an all-negative window is ordinary.
    test('falls back to a flat maxY of 1.0 when the peak is zero or below', () {
      final allZero = [
        at(DateTime(2026, 3, 10, 1), 0),
        at(DateTime(2026, 3, 10, 2), 0),
      ];
      final zeroBounds = ChartBounds.fromSeries([seriesOf(allZero)]);
      expect(zeroBounds.maxY, 1.0);
      // chart_data.dart:126 - minimum is 0, which is not < 0, so minY is flat 0.
      expect(zeroBounds.minY, 0);
      // chart_data.dart:133 - niceStep(1.0, divisions: 4) = 0.25.
      expect(zeroBounds.chartInterval, closeTo(0.25, 1e-9));

      final allNegative = [
        at(DateTime(2026, 3, 10, 1), -1),
        at(DateTime(2026, 3, 10, 2), -1),
      ];
      final negativeBounds = ChartBounds.fromSeries([seriesOf(allNegative)]);
      expect(negativeBounds.maxY, 1.0);
      // chart_data.dart:126 - minimum is padded 10%, so -1.1.
      expect(negativeBounds.minY, closeTo(-1.1, 1e-9));
      // chart_data.dart:133 - niceStep(2.1, divisions: 4) = 1.0.
      expect(negativeBounds.chartInterval, closeTo(1.0, 1e-9));
    });

    // The 1.0 fallback is a fixed constant while minY tracks the data, so a
    // deep negative series is padded far more at the bottom than the top.
    // Pinned because it is the visible shape of a discharging battery chart.
    test('pads an all-negative series 10% below but a flat 1.0 above', () {
      final points = [
        at(DateTime(2026, 3, 10, 1), -10),
        at(DateTime(2026, 3, 10, 2), -20),
      ];
      final bounds = ChartBounds.fromSeries([seriesOf(points)]);
      // chart_data.dart:126 - minimum -20 padded by 10%.
      expect(bounds.minY, closeTo(-22.0, 1e-9));
      // chart_data.dart:127 - maximum -10 takes the flat fallback, so the
      // positive headroom is 11.0 while the negative headroom is 2.0.
      expect(bounds.maxY, 1.0);
      expect(bounds.minY, lessThan(-20));
      // chart_data.dart:133 - niceStep(23.0, divisions: 4) = 10.0.
      expect(bounds.chartInterval, closeTo(10.0, 1e-9));
    });

    // chart_card.dart:329-330 hands minY and maxY straight to LineChartData, so
    // the fallback has to keep the range strictly increasing or fl_chart has an
    // inverted axis. Asserted across the whole <= 0 branch rather than by hand.
    test('keeps the y range increasing for every non-positive peak', () {
      // Typed as <double> because a bare literal list mixing 0.0 with -1 infers
      // List<num>, and `at` takes a double.
      for (final peak in <double>[0.0, -0.0001, -1, -12.5, -1e6]) {
        final points = [
          at(DateTime(2026, 3, 10, 1), peak),
          at(DateTime(2026, 3, 10, 2), peak * 2 - 1),
        ];
        final bounds = ChartBounds.fromSeries([seriesOf(points)]);
        expect(
          bounds.maxY,
          greaterThan(bounds.minY),
          reason:
              'maxY ${bounds.maxY} is not above minY ${bounds.minY} '
              'for a series peaking at $peak',
        );
        expect(
          bounds.chartInterval,
          greaterThan(0),
          reason: 'a non-positive peak gave a non-positive y interval',
        );
      }
    });

    test('detects a multi-day range', () {
      final week = [at(DateTime(2026, 3, 1), 1), at(DateTime(2026, 3, 8), 2)];
      final day = [
        at(DateTime(2026, 3, 10, 1), 1),
        at(DateTime(2026, 3, 10, 20), 2),
      ];
      expect(
        ChartBounds.fromSeries([seriesOf(week)]).spansMultipleDays,
        isTrue,
      );
      expect(
        ChartBounds.fromSeries([seriesOf(day)]).spansMultipleDays,
        isFalse,
      );
    });
  });

  group('formatAxisTick', () {
    final value = DateTime(
      2026,
      3,
      10,
      14,
      5,
    ).millisecondsSinceEpoch.toDouble();

    test('shows a clock time for a single-day range', () {
      expect(formatAxisTick(value, spansMultipleDays: false), '14:05');
    });

    test('shows a date for a multi-day range', () {
      expect(formatAxisTick(value, spansMultipleDays: true), '10/03');
    });
  });

  // Zero is the bottom of the axis because zero is a *state*, not because it is
  // a convenient number. A lux reading of 0 is dark and a wattage of 0 is idle,
  // so the distance from the baseline is the reading. pH has no such state: 0 is
  // an arbitrary point on a 0-14 ruler, and anchoring there squeezed a
  // 7.75 -> 6.37 drop -- the whole point of the page -- into the top fifth of
  // the plot.
  group('zero-anchored axes', () {
    test('a group opts out of zero exactly when it is dimensionless', () {
      // Derived rather than listed, so a future dimensionless group has to make
      // this decision instead of inheriting a zero baseline that flattens it,
      // and a future unit-bearing group cannot quietly opt out of a baseline it
      // needs. An empty unit is the app's existing spelling of "no unit": pH is
      // the only one, and it is the only one that opts out.
      for (final prefix in ['pv', 'ac', 'battery', 'env', 'fish']) {
        for (final group in chartGroupsForPrefix(prefix)) {
          final dimensionless = group.series.every((s) => s.unit.isEmpty);
          expect(
            group.zeroAnchored,
            !dimensionless,
            reason:
                "'${group.title}' on '$prefix' has unit "
                "'${group.series.map((s) => s.unit).join('/')}' so it "
                '${dimensionless ? 'must' : 'must not'} anchor at zero',
          );
        }
      }
    });

    test('the history request is the pinned key list, whatever the grouping',
        () {
      // Regrouping a page's charts must not change what is fetched.
      //
      // The reason this is worth a test: `chartKeysForPrefix` flattens the groups,
      // so splitting one three-series group into three single-series groups
      // produces a byte-for-byte identical request. That is the property which
      // makes regrouping safe to attempt, and it is invisible in the app -- the
      // only way to break it is to change a key, and the only way to notice is to
      // compare lists.
      //
      // A key appearing in two groups would be fetched once (the request is a set
      // of keys) but plotted twice, and one key disappearing from both would be
      // silently unplotted. Both are checked here rather than by reading.
      for (final entry in kHistoryKeysByPrefix.entries) {
        final derived = chartKeysForPrefix(entry.key);
        expect(
          derived,
          entry.value,
          reason: "'${entry.key}' requests something other than the pinned "
              'list. Regrouping must not change the request.',
        );
        expect(
          derived.toSet().length,
          derived.length,
          reason: "'${entry.key}' has a key in two groups, so it is fetched once "
              'and plotted twice',
        );
      }
    });

    test('leaves every magnitude group bit-for-bit unchanged', () {
      // The strongest form of "unchanged": the flag is a no-op for a group that
      // does not set it, so the two calls have to agree on every field rather
      // than on an expectation somebody typed. If a future edit makes
      // `_lowerBound` consult the flag for a zero-anchored group, this fails.
      final data = sampleDataByPrefix();
      var checked = 0;
      for (final entry in data.entries) {
        final groups = chartGroupsForPrefix(entry.key);
        // The sample lists are positional, so a group added or reordered without
        // its data would otherwise plot the neighbouring series and pass.
        expect(
          entry.value.length,
          groups.length,
          reason: 'sample data for ${entry.key} is out of step with its groups',
        );
        for (var i = 0; i < groups.length; i++) {
          final group = groups[i];
          final seriesData = entry.value[i];
          expect(
            seriesData.length,
            group.series.length,
            reason:
                'sample data for ${entry.key}/${group.title} is out of '
                'step with its series',
          );
          if (!group.zeroAnchored) continue;
          final withFlag = boundsFor(group, seriesData);
          final withoutFlag = ChartBounds.fromSeries([
            for (final values in seriesData) seriesOf(ramp(values)),
          ]);
          checked++;
          expect(
            withFlag.minY,
            withoutFlag.minY,
            reason: "'${group.title}' on '${entry.key}' changed minY",
          );
          expect(
            withFlag.maxY,
            withoutFlag.maxY,
            reason: "'${group.title}' on '${entry.key}' changed maxY",
          );
          expect(
            withFlag.chartInterval,
            withoutFlag.chartInterval,
            reason: "'${group.title}' on '${entry.key}' changed the interval",
          );
        }
      }
      // Derived from the same declaration the sweep walks, so this catches an
      // empty or partial sweep without hard-coding a group count that a future
      // group would invalidate for no reason.
      expect(
        checked,
        [
          for (final prefix in ['pv', 'ac', 'battery', 'env', 'fish'])
            for (final g in chartGroupsForPrefix(prefix))
              if (g.zeroAnchored) 1,
        ].length,
        reason: 'every zero-anchored group has to be swept',
      );
    });

    test('an index group keeps the zero baseline when it does not opt out', () {
      // The counterfactual, and the reason the flag is a flag: the same pH data
      // through a zero-anchored axis puts the data in the top slice.
      final ph = chartGroupsForPrefix('fish')
          .firstWhere((g) => !g.zeroAnchored);
      final values = [
        [6.42, 7.05, 7.75, 6.37],
      ];
      final zeroAnchored = ChartBounds.fromSeries([seriesOf(ramp(values[0]))]);
      final index = boundsFor(ph, values);
      expect(zeroAnchored.minY, 0);
      expect(index.minY, isNot(0));
    });
  });

  group('index-anchored axes', () {
    /// The pH group, which is the one group in the app that opts out.
    ChartGroup ph() =>
        chartGroupsForPrefix('fish').firstWhere((g) => !g.zeroAnchored);

    /// The share of the plot height the data actually occupies.
    double filled(ChartBounds b, List<double> values) {
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      return (max - min) / (b.maxY - b.minY);
    }

    test('opens headroom below the data instead of pinning to zero', () {
      final values = [6.42, 7.05, 7.75, 6.37];
      final b = boundsFor(ph(), [values]);
      final min = values.reduce((a, b) => a < b ? a : b);
      expect(
        b.minY,
        lessThan(min),
        reason: 'the axis has to start below the data, not at it',
      );
      expect(b.minY, greaterThan(0), reason: 'pH never went negative');
    });

    test('spends the axis on the data rather than on the empty zero', () {
      // The property the whole change exists for, stated without a literal: the
      // same readings must occupy strictly more of the plot height once the
      // baseline stops being an arbitrary point on the scale. Any threshold here
      // would be a magic number; "more than it did before" is the claim.
      for (final values in <List<double>>[
        [6.42, 7.05, 7.75, 6.37],
        [7.0, 7.05, 6.98, 7.02], // a nearly flat tank
        [5.8, 6.1, 8.4], // a wide excursion
      ]) {
        final zero = ChartBounds.fromSeries([seriesOf(ramp(values))]);
        final index = boundsFor(ph(), [values]);
        expect(
          filled(index, values),
          greaterThan(filled(zero, values)),
          reason: '$values plotted no taller anchored away from zero',
        );
      }
    });

    test('keeps every gridline a round pH value', () {
      // The axis is a count of intervals tall, so fl_chart -- which labels every
      // multiple of the interval *and* both bounds -- cannot draw a leftover like
      // 6.025 as a gridline. Same reasoning as the maxY snap that already
      // existed, applied to the bottom of the axis.
      for (final values in <List<double>>[
        [6.42, 7.05, 7.75, 6.37],
        [7.0, 7.05, 6.98, 7.02],
        [5.8, 6.1, 8.4],
        [7.0, 7.0, 7.0], // never moves
      ]) {
        final b = boundsFor(ph(), [values]);
        final intervals = (b.maxY - b.minY) / b.chartInterval;
        expect(
          intervals,
          closeTo(intervals.roundToDouble(), 1e-6),
          reason: '$values gave a span of $intervals intervals',
        );
        final steps = b.maxY / b.chartInterval;
        expect(
          steps,
          closeTo(steps.roundToDouble(), 1e-6),
          reason:
              '$values gave maxY ${b.maxY} on a step of '
              '${b.chartInterval}',
        );
      }
    });

    test('scales its headroom to the range, not to the value', () {
      // The bottom is derived from the *range*, so headroom per unit of range
      // is the same number for every input. A pad proportional to the value --
      // which is what the top of a zero-anchored axis does, and the obvious
      // thing to copy -- would give a different ratio for each of these, and so
      // would no pad at all. Stated as a ratio because the coefficient itself is
      // not the contract; how it scales is.
      for (final high in [7.2, 7.75, 8.4, 9.1, 11.0, 13.9]) {
        for (final low in [4.2, 6.37, 6.9]) {
          final range = high - low;
          final headroom =
              low - chartLowerBound(low, high, zeroAnchored: false);
          final reference =
              (low - chartLowerBound(low, 7.75, zeroAnchored: false)) /
              (7.75 - low);
          expect(
            headroom / range,
            closeTo(reference, 1e-9),
            reason:
                'a $range-wide pH swing from $low padded at a different '
                'rate than a 1.38-wide one did',
          );
        }
      }
    });

    test('never plots a zero-height axis', () {
      // A flat series is the case the 2%-of-value term exists for: a range-only
      // pad would give minY == rawMaxY and fl_chart would have a line with
      // nowhere to be. Swept over both anchoring modes and both signs, because
      // this is the failure a hand-written expectation misses.
      for (final values in <List<double>>[
        [7.0, 7.0, 7.0],
        [7.0, 7.0000001],
        [0.0, 0.0, 0.0],
        [0.0, 0.1],
        [-5.0, -5.0],
        [-5.0, -1.0, -3.0],
        [1e6, 1e6],
        [0.0, 0.0, 5.0],
      ]) {
        for (final zeroAnchored in [true, false]) {
          final b = ChartBounds.fromSeries([
            seriesOf(ramp(values)),
          ], zeroAnchored: zeroAnchored);
          expect(
            b.maxY,
            greaterThan(b.minY),
            reason:
                '$values at zeroAnchored=$zeroAnchored plotted '
                '${b.minY}..${b.maxY}',
          );
          expect(
            b.chartInterval,
            greaterThan(0),
            reason:
                '$values at zeroAnchored=$zeroAnchored gave a '
                'non-positive interval',
          );
        }
      }
    });
  });
}
