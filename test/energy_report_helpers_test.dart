import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/energy_report/utils/chart_helpers.dart';
import 'package:plts_monitoring/screens/energy_report/utils/format_helpers.dart';
import 'package:plts_monitoring/screens/energy_report/utils/period_buckets.dart';
import 'package:plts_monitoring/services/energy_report_service.dart';

EnergyBucket bucket(
  DateTime hour, {
  double pv = 0,
  double ac = 0,
  int samples = 1,
}) =>
    EnergyBucket(hour: hour, pvKwh: pv, acKwh: ac, sampleCount: samples);

void main() {
  group('bucketsForPeriod (daily)', () {
    final buckets = [
      bucket(DateTime(2026, 3, 10, 0), pv: 1),
      bucket(DateTime(2026, 3, 10, 1), pv: 2),
      bucket(DateTime(2026, 3, 10, 23), pv: 3),
      bucket(DateTime(2026, 3, 11, 0), pv: 4),
      bucket(DateTime(2026, 2, 28, 12), pv: 5),
    ];

    test('keeps only the selected day', () {
      final result = bucketsForPeriod(
        buckets: buckets,
        selectedDate: DateTime(2026, 3, 10, 17, 45),
        monthly: false,
      );
      expect(result.length, 3);
      expect(
        result.map((item) => item.pvKwh).toList(),
        [1, 2, 3],
      );
    });

    test('returns an empty list for a day with no data', () {
      final result = bucketsForPeriod(
        buckets: buckets,
        selectedDate: DateTime(2026, 3, 12),
        monthly: false,
      );
      expect(result, isEmpty);
    });
  });

  group('bucketsForPeriod (monthly)', () {
    final buckets = [
      bucket(DateTime(2026, 3, 10, 0), pv: 1, ac: 0.5, samples: 1),
      bucket(DateTime(2026, 3, 10, 5), pv: 2, ac: 1.5, samples: 2),
      bucket(DateTime(2026, 3, 11, 0), pv: 4, ac: 2, samples: 1),
      bucket(DateTime(2026, 2, 28, 23), pv: 99, ac: 99, samples: 1),
    ];

    test('aggregates hours into days, sorted ascending', () {
      final result = bucketsForPeriod(
        buckets: buckets,
        selectedDate: DateTime(2026, 3, 20),
        monthly: true,
      );
      expect(result.length, 2);
      expect(result.first.hour, DateTime(2026, 3, 10));
      expect(result.first.pvKwh, 3);
      expect(result.first.acKwh, 2);
      expect(result.first.sampleCount, 3);
      expect(result.last.hour, DateTime(2026, 3, 11));
      expect(result.last.pvKwh, 4);
    });

    test('excludes buckets from other months', () {
      final result = bucketsForPeriod(
        buckets: buckets,
        selectedDate: DateTime(2026, 2, 5),
        monthly: true,
      );
      expect(result.length, 1);
      expect(result.single.pvKwh, 99);
    });
  });

  group('previousPeriodTotals', () {
    final buckets = [
      bucket(DateTime(2026, 3, 10, 0), pv: 1, ac: 0.5),
      bucket(DateTime(2026, 3, 10, 1), pv: 2, ac: 1.5),
      bucket(DateTime(2026, 3, 11, 0), pv: 4, ac: 2),
    ];

    test('sums the previous day in daily mode', () {
      final totals = previousPeriodTotals(
        buckets: buckets,
        selectedDate: DateTime(2026, 3, 11),
        monthly: false,
      );
      expect(totals!.pvKwh, 3);
      expect(totals.acKwh, 2);
    });

    test('sums the previous month in monthly mode', () {
      final withFebruary = [
        ...buckets,
        bucket(DateTime(2026, 2, 5), pv: 7, ac: 3),
        bucket(DateTime(2026, 2, 6), pv: 8, ac: 4),
      ];
      final totals = previousPeriodTotals(
        buckets: withFebruary,
        selectedDate: DateTime(2026, 3, 11),
        monthly: true,
      );
      expect(totals!.pvKwh, 15);
      expect(totals.acKwh, 7);
    });

    test('returns null when the previous period has no data', () {
      expect(
        previousPeriodTotals(
          buckets: buckets,
          selectedDate: DateTime(2026, 4, 1),
          monthly: false,
        ),
        isNull,
      );
      expect(
        previousPeriodTotals(
          buckets: const [],
          selectedDate: DateTime.now(),
          monthly: false,
        ),
        isNull,
      );
    });

    test('crosses month boundaries when stepping back from the 1st', () {
      final totals = previousPeriodTotals(
        buckets: [bucket(DateTime(2026, 2, 28), pv: 6, ac: 2)],
        selectedDate: DateTime(2026, 3, 1),
        monthly: false,
      );
      expect(totals!.pvKwh, 6);
      expect(totals.acKwh, 2);
    });

    test('crosses year boundaries when stepping back from January', () {
      final totals = previousPeriodTotals(
        buckets: [bucket(DateTime(2025, 12, 20), pv: 3, ac: 1)],
        selectedDate: DateTime(2026, 1, 15),
        monthly: true,
      );
      expect(totals!.pvKwh, 3);
    });
  });

  group('totalsOf and totalSampleCount', () {
    test('sums energy and samples', () {
      final buckets = [
        bucket(DateTime(2026, 3, 10), pv: 1, ac: 0.5, samples: 2),
        bucket(DateTime(2026, 3, 10, 1), pv: 2, ac: 1.5, samples: 3),
      ];
      final totals = totalsOf(buckets);
      expect(totals.pvKwh, 3);
      expect(totals.acKwh, 2);
      expect(totalSampleCount(buckets), 5);
    });

    test('handles an empty list', () {
      expect(totalsOf(const []).pvKwh, 0);
      expect(totalSampleCount(const []), 0);
    });
  });

  group('calculateMaxY', () {
    test('pads the largest value by 25%', () {
      expect(calculateMaxY([bucket(DateTime(2026), pv: 4, ac: 2)]), 5);
    });

    test('uses the AC value when it is the largest', () {
      expect(calculateMaxY([bucket(DateTime(2026), pv: 1, ac: 8)]), 10);
    });

    test('falls back to 1.0 for empty or all-zero data', () {
      expect(calculateMaxY(const []), 1.0);
      expect(calculateMaxY([bucket(DateTime(2026))]), 1.0);
    });
  });

  group('clampBucketIndex', () {
    test('keeps a valid index', () {
      expect(clampBucketIndex(2, 5), 2);
    });

    test('clamps out-of-range and null indexes', () {
      expect(clampBucketIndex(-3, 5), 0);
      expect(clampBucketIndex(99, 5), 4);
      expect(clampBucketIndex(null, 5), 0);
    });

    test('returns 0 when there are no buckets', () {
      expect(clampBucketIndex(3, 0), 0);
      expect(clampBucketIndex(null, 0), 0);
    });
  });

  group('comparisonLabel', () {
    test('handles a missing baseline', () {
      expect(comparisonLabel(5, null), 'Belum ada data pembanding');
    });

    test('handles a zero baseline without dividing by zero', () {
      expect(comparisonLabel(5, 0), 'Periode sebelumnya: 0 kWh');
    });

    test('describes growth, decline, and no change', () {
      expect(comparisonLabel(12, 10), '+20% dari periode sebelumnya');
      expect(comparisonLabel(8, 10), '-20% dari periode sebelumnya');
      expect(comparisonLabel(10, 10), 'Sama dengan periode sebelumnya');
    });
  });

  group('escapeCsv', () {
    test('quotes and doubles embedded quotes', () {
      expect(escapeCsv('a"b'), '"a""b"');
      expect(escapeCsv('plain'), '"plain"');
    });
  });
}
