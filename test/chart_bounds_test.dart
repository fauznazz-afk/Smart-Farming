import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/dashboard/charts/chart_data.dart';
import 'package:plts_monitoring/screens/dashboard/utils/date_helpers.dart';

ChartSeries seriesOf(List<TelemetryPoint> points) => ChartSeries(
  'Power',
  'W',
  points,
  processSpots(points),
  const Color(0xFF1E88E5),
  SeriesStats.fromPoints(points),
);

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
      expect(
        niceTimeStep(3 * 24 * 3600 * 1000),
        closeTo(3 * 86400000, 1e-6),
      );
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
      expect(bounds.minX, lessThanOrEqualTo(DateTime(2026, 3, 10, 6, 7).millisecondsSinceEpoch));
      expect(bounds.maxX, greaterThanOrEqualTo(DateTime(2026, 3, 10, 18, 41).millisecondsSinceEpoch));
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

    test('detects a multi-day range', () {
      final week = [
        at(DateTime(2026, 3, 1), 1),
        at(DateTime(2026, 3, 8), 2),
      ];
      final day = [
        at(DateTime(2026, 3, 10, 1), 1),
        at(DateTime(2026, 3, 10, 20), 2),
      ];
      expect(ChartBounds.fromSeries([seriesOf(week)]).spansMultipleDays, isTrue);
      expect(ChartBounds.fromSeries([seriesOf(day)]).spansMultipleDays, isFalse);
    });
  });

  group('formatAxisTick', () {
    final value = DateTime(2026, 3, 10, 14, 5).millisecondsSinceEpoch.toDouble();

    test('shows a clock time for a single-day range', () {
      expect(formatAxisTick(value, spansMultipleDays: false), '14:05');
    });

    test('shows a date for a multi-day range', () {
      expect(formatAxisTick(value, spansMultipleDays: true), '10/03');
    });
  });
}
