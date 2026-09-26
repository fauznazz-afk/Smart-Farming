import '../../../services/energy_report_service.dart';

/// PV and AC totals for one reporting period, in kWh.
class PeriodTotals {
  const PeriodTotals({required this.pvKwh, required this.acKwh});

  final double pvKwh;
  final double acKwh;
}

/// Normalizes any timestamp to midnight of that day.
DateTime _dayOf(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Narrows a full report down to the selected day, or aggregates it to days
/// within the selected month.
List<EnergyBucket> bucketsForPeriod({
  required List<EnergyBucket> buckets,
  required DateTime selectedDate,
  required bool monthly,
}) {
  if (!monthly) {
    return buckets
        .where((item) => _dayOf(item.hour) == _dayOf(selectedDate))
        .toList(growable: false);
  }

  final byDay = <DateTime, EnergyBucket>{};
  for (final item in buckets) {
    if (item.hour.year != selectedDate.year ||
        item.hour.month != selectedDate.month) {
      continue;
    }
    final day = _dayOf(item.hour);
    final existing = byDay[day];
    byDay[day] = EnergyBucket(
      hour: day,
      pvKwh: (existing?.pvKwh ?? 0) + item.pvKwh,
      acKwh: (existing?.acKwh ?? 0) + item.acKwh,
      sampleCount: (existing?.sampleCount ?? 0) + item.sampleCount,
    );
  }
  return byDay.values.toList()..sort((a, b) => a.hour.compareTo(b.hour));
}

/// Totals for the equivalent preceding period, or null when there is no data.
///
/// [selectedDate] is only read for its year/month (monthly) or year/month/day
/// (daily) components; any time-of-day is ignored.
PeriodTotals? previousPeriodTotals({
  required List<EnergyBucket> buckets,
  required DateTime selectedDate,
  required bool monthly,
}) {
  // DateTime normalises out-of-range components, so month 0 becomes December
  // of the previous year and day 0 becomes the last day of the month before.
  final previousStart = monthly
      ? DateTime(selectedDate.year, selectedDate.month - 1)
      : DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day - 1,
        );

  var pvKwh = 0.0;
  var acKwh = 0.0;
  var matched = false;
  for (final item in buckets) {
    final sameDay = _dayOf(item.hour) == _dayOf(previousStart);
    final sameMonth =
        item.hour.year == previousStart.year &&
        item.hour.month == previousStart.month;
    if (monthly ? !sameMonth : !sameDay) continue;
    matched = true;
    pvKwh += item.pvKwh;
    acKwh += item.acKwh;
  }
  if (!matched) return null;
  return PeriodTotals(pvKwh: pvKwh, acKwh: acKwh);
}

/// Sums a bucket list into period totals.
PeriodTotals totalsOf(List<EnergyBucket> buckets) {
  var pvKwh = 0.0;
  var acKwh = 0.0;
  for (final bucket in buckets) {
    pvKwh += bucket.pvKwh;
    acKwh += bucket.acKwh;
  }
  return PeriodTotals(pvKwh: pvKwh, acKwh: acKwh);
}

/// Total telemetry samples represented by a bucket list.
int totalSampleCount(List<EnergyBucket> buckets) =>
    buckets.fold(0, (sum, item) => sum + item.sampleCount);
