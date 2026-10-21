import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/utils/production_buckets.dart';

/// The 7-day sheet draws "nothing here" differently from "zero here", and the
/// whole reason `kwh` is nullable is that distinction. These cases pin the nulls,
/// the trapezoid arithmetic and the ordering the UI indexes positionally.
void main() {
  TelemetryPoint at(int day, int hour, double value, {int minute = 0}) =>
      TelemetryPoint(
        timestamp: DateTime(2026, 10, day, hour, minute),
        value: value,
      );

  group('dailyTotals', () {
    test('returns exactly days entries, oldest first, ending on today', () {
      final totals = dailyTotals(
        const <TelemetryPoint>[],
        DateTime(2026, 10, 10),
        days: 7,
      );
      expect(totals.length, 7);
      expect(totals.first.date, DateTime(2026, 10, 4));
      expect(totals.last.date, DateTime(2026, 10, 10));
      for (var i = 1; i < totals.length; i++) {
        expect(
          totals[i].date.isAfter(totals[i - 1].date),
          isTrue,
          reason: 'entry $i must be later than entry ${i - 1}',
        );
      }
    });

    test('two samples 1 h apart at 1000 W integrate to 1.0 kWh', () {
      // 0.5 * (1000 + 1000) W * 1 h = 1000 Wh = 1.0 kWh
      final totals = dailyTotals(
        [at(8, 10, 1000), at(8, 11, 1000)],
        DateTime(2026, 10, 8),
        days: 1,
      );
      expect(totals.single.kwh, closeTo(1.0, 1e-9));
    });

    test('two samples 30 min apart at 600 W integrate to 0.3 kWh', () {
      // 0.5 * (600 + 600) W * 0.5 h = 300 Wh = 0.3 kWh
      final totals = dailyTotals(
        [at(8, 10, 600), at(8, 10, 600, minute: 30)],
        DateTime(2026, 10, 8),
        days: 1,
      );
      expect(totals.single.kwh, closeTo(0.3, 1e-9));
    });

    test('an irregular gap is not credited as a nominal interval', () {
      // 600 W constant across the real 6 h gap: 0.5 * (600 + 600) * 6 =
      // 3600 Wh = 3.6 kWh. A nominal-interval implementation would bill only
      // the sampling period and report a sixth of that.
      final totals = dailyTotals(
        [at(8, 10, 600), at(8, 16, 600)],
        DateTime(2026, 10, 8),
        days: 1,
      );
      expect(totals.single.kwh, closeTo(3.6, 1e-9));
    });

    test('a single sample in a day is null, not 0', () {
      final totals = dailyTotals(
        [at(8, 10, 800)],
        DateTime(2026, 10, 8),
        days: 1,
      );
      expect(totals.single.kwh, isNull);
      expect(totals.single.isEmpty, isTrue);
    });

    test('negative power is clamped to zero', () {
      final totals = dailyTotals(
        [at(8, 10, -500), at(8, 11, -500)],
        DateTime(2026, 10, 8),
        days: 1,
      );
      expect(totals.single.kwh, 0.0);
      expect(
        totals.single.kwh! >= 0,
        isTrue,
        reason: 'a sensor glitch must not subtract energy from a day',
      );
    });

    test('samples land in the day they belong to, sorted internally', () {
      final totals = dailyTotals(
        [at(8, 11, 1000), at(8, 10, 1000), at(9, 10, 2000), at(9, 10, 2000, minute: 30)],
        DateTime(2026, 10, 9),
        days: 2,
      );
      expect(totals[0].date, DateTime(2026, 10, 8));
      expect(totals[0].kwh, closeTo(1.0, 1e-9), reason: '1000 W for 1 h');
      expect(totals[1].date, DateTime(2026, 10, 9));
      // 2000 W across 30 min is 1000 Wh, so 1.0 kWh — the unsorted pair here is
      // what proves the internal sort happened before integrating.
      expect(totals[1].kwh, closeTo(1.0, 1e-9), reason: '2000 W for 0.5 h');
    });
  });
}