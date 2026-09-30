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
    // These assert the two properties the axis depends on rather than the exact
    // numbers. The function used to return a bare maximum computed as
    // `peak * 1.25`, and the test pinned those products -- 5 for a peak of 4, 10
    // for a peak of 8. The axis has since been snapped to a whole number of
    // `niceStep` intervals so the topmost label lands on the top of the plot
    // instead of being clipped above it, which moves the numbers. Pinning the
    // products would pin the defect.
    void expectAxisCovers(
      List<EnergyBucket> buckets,
      double peak, {
      required String reason,
    }) {
      final axis = calculateMaxY(buckets);
      expect(
        axis.maxY,
        greaterThanOrEqualTo(peak * 1.25),
        reason: '$reason: the maximum must leave the 25% headroom, or the '
            'tallest bar is clipped',
      );
      expect(
        axis.maxY / axis.interval,
        closeTo((axis.maxY / axis.interval).roundToDouble(), 1e-9),
        reason: '$reason: the maximum must be a whole number of intervals, or '
            'the top label is drawn at a height the plot has no room for',
      );
      expect(axis.interval, greaterThan(0), reason: reason);
    }

    test('pads the largest value by 25% and snaps to an interval', () {
      expectAxisCovers(
        [bucket(DateTime(2026), pv: 4, ac: 2)],
        4,
        reason: 'peak 4',
      );
    });

    test('uses the AC value when it is the largest', () {
      expectAxisCovers(
        [bucket(DateTime(2026), pv: 1, ac: 8)],
        8,
        reason: 'peak 8',
      );
    });

    test('produces a label a reader would write', () {
      // The defect this replaced: a peak of 0.369 gave labels of
      // 0.12 / 0.23 / 0.35 / 0.46. Each was correct to two decimals and none
      // was a number anyone would write. The interval has to land on the
      // 1 / 2 / 2.5 / 5 family.
      final axis = calculateMaxY([
        bucket(DateTime(2026), pv: 0.369, ac: 0.0),
      ]);
      expect(
        axis.interval,
        anyOf(0.1, 0.2, 0.25, 0.5),
        reason: 'interval ${axis.interval} is not a round step',
      );
    });

    test('falls back to 1.0 for empty or all-zero data', () {
      expect(calculateMaxY(const []).maxY, 1.0);
      expect(calculateMaxY([bucket(DateTime(2026))]).maxY, 1.0);
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
      expect(comparisonLabel(5, null), 'No comparison data yet');
      // A null is "no previous period at all" and is answered before any
      // arithmetic, so a zero current must not turn it into something else.
      expect(comparisonLabel(0, null), 'No comparison data yet');
    });

    test('handles a zero baseline without dividing by zero', () {
      expect(comparisonLabel(5, 0), 'Previous period: 0 kWh');
      // This wording is the report's own and is kept deliberately: the card
      // says 'Nothing to compare yet' here, but that string is pinned by
      // test/energy_summary_card_test.dart and the two files are not allowed to
      // drift into each other's vocabulary.
      expect(comparisonLabel(0, 0), 'Previous period: 0 kWh');
    });

    test('describes growth, decline, and no change', () {
      expect(comparisonLabel(12, 10), '+20% from the previous period');
      expect(comparisonLabel(8, 10), '-20% from the previous period');
      expect(comparisonLabel(10, 10), 'Same as the previous period');
    });

    // The threshold is 0.1 kWh, matching
    // EnergySummaryCard._meaningfulPrevious. Everything below is a ratio
    // withheld, and the wording is copied from the card's branch structure so
    // the dashboard and the report cannot describe the same two numbers
    // differently.
    test('does not claim a loss when the previous period was rounding noise',
        () {
      // The reported defect: 0.01 kWh then nothing. The old code printed
      // '-100% from the previous period', which reads as a catastrophic loss.
      expect(comparisonLabel(0, 0.01), isNot(contains('%')));
      expect(comparisonLabel(0, 0.01), 'No production');
    });

    test('withholds a ratio just below the threshold as well', () {
      // 0.09 is still under 0.1, and a current of zero makes the old code
      // print '-100% from the previous period'.
      expect(comparisonLabel(0, 0.09), isNot(contains('%')));
      expect(comparisonLabel(0, 0.09), 'No production');
    });

    test('spells out a small current against an empty previous period', () {
      // Both periods are below 0.1 kWh, but the current one is not zero, so the
      // figure is quoted instead of a ratio being claimed. The threshold is
      // 0.1, not the 0.01 the value is displayed to, which is why 0.04 and 0.02
      // are not simply "0.00 kWh".
      expect(comparisonLabel(0.04, 0.02), '0.04 kWh, none last period');
      expect(comparisonLabel(0.09, 0.01), '0.09 kWh, none last period');
    });

    test('withholds a ratio when only the previous period is below it', () {
      // previous = 0.05 is noise, so there is no baseline to divide by, even
      // though the current period is substantial. The card's branch for this.
      expect(comparisonLabel(5, 0.05), 'Nothing to compare yet');
      expect(comparisonLabel(5, 0.05), isNot(contains('%')));
    });

    test('starts reporting a ratio at exactly the threshold', () {
      // 0.1 is not "less than" the threshold, so a 0 -> 0.1 change is a real
      // 100% and is stated. This pins the boundary from both sides.
      expect(comparisonLabel(0.2, 0.1), '+100% from the previous period');
      expect(comparisonLabel(0.2, 0.099999), 'Nothing to compare yet');
    });
  });

  group('formatMonthLabel', () {
    test('renders every month in English', () {
      // The list had 'Oktober' and 'Desember' in it while the other ten were
      // English and the app's only locale is en_US, so an October report read
      // "Oktober 2026" on screen and in the exported CSV (the Period row of
      // buildEnergyCsv). There was no test on this function at all.
      const expected = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      for (var month = 1; month <= 12; month++) {
        expect(
          formatMonthLabel(DateTime(2026, month)),
          '${expected[month - 1]} 2026',
          reason: 'month $month must render as an English name',
        );
      }
    });

    test('uses the year of the date it is given', () {
      expect(formatMonthLabel(DateTime(2025, 10)), 'October 2025');
      expect(formatMonthLabel(DateTime(2026, 12, 31, 23, 59)), 'December 2026');
    });

    test('rejects an Indonesian spelling outright', () {
      // Stated explicitly rather than relying only on the list above, so the
      // intent survives an edit that only changes one string.
      expect(formatMonthLabel(DateTime(2026, 10)), isNot('Oktober 2026'));
      expect(formatMonthLabel(DateTime(2026, 12)), isNot('Desember 2026'));
    });
  });

  group('escapeCsv', () {
    test('quotes and doubles embedded quotes', () {
      expect(escapeCsv('a"b'), '"a""b"');
      expect(escapeCsv('plain'), '"plain"');
    });
  });
}
