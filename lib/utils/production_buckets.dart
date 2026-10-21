import '../models/telemetry_model.dart';

/// Total energy (kWh) produced on one calendar day.
class DailyProduction {
  const DailyProduction({required this.date, required this.kwh});
  final DateTime date; // local midnight of that day
  final double? kwh; // null when the day has no samples at all
  bool get isEmpty => kwh == null;
}

/// `DateTime` at local midnight for [moment]'s calendar day.
DateTime startOfLocalDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Total kWh for each of the last [days] calendar days, oldest first, ending on [today].
///
/// Each day integrates its own samples by the trapezoid rule over the real
/// sample spacing: `kWh = Σ 0.5*(p[i] + p[i+1]) * dt_hours / 1000`. Using the
/// real spacing rather than assuming a fixed interval is the point -- a gateway
/// that dropped six samples must not silently contribute six nominal intervals.
///
/// A day with fewer than 2 samples integrates to `null`, not `0`: one sample is
/// not a measurement of a day. Negative power is clamped to zero before
/// integrating (a sensor glitch must not subtract energy).
List<DailyProduction> dailyTotals(
  List<TelemetryPoint> history,
  DateTime today, {
  int days = 7,
}) {
  final todayStart = startOfLocalDay(today);

  // Group once by local day, then sort each group: O(n log n) overall instead of
  // re-filtering the whole history once per day.
  final byDay = <DateTime, List<TelemetryPoint>>{};
  for (final point in history) {
    (byDay[startOfLocalDay(point.timestamp)] ??= <TelemetryPoint>[]).add(point);
  }
  for (final group in byDay.values) {
    group.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  return [
    for (var offset = days - 1; offset >= 0; offset--)
      () {
        // Calendar arithmetic, not Duration(days:) -- a 24-hour subtract across a
        // DST boundary lands on 23:00 or 01:00, not midnight.
        final date = DateTime(
          todayStart.year,
          todayStart.month,
          todayStart.day - offset,
        );
        final points = byDay[date] ?? const <TelemetryPoint>[];
        if (points.length < 2) {
          return DailyProduction(date: date, kwh: null);
        }
        var wh = 0.0;
        for (var i = 1; i < points.length; i++) {
          final p0 = points[i - 1].value < 0 ? 0.0 : points[i - 1].value;
          final p1 = points[i].value < 0 ? 0.0 : points[i].value;
          final hours = points[i].timestamp
              .difference(points[i - 1].timestamp)
              .inMilliseconds /
              3600000.0;
          wh += 0.5 * (p0 + p1) * hours;
        }
        return DailyProduction(date: date, kwh: wh / 1000.0);
      }(),
  ];
}