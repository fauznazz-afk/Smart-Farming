/// What one sensor did over a selected period: the three numbers the Overview's
/// date summary reports.
///
/// ## Why these live in `utils/` and not in the panel
///
/// The panel's whole claim is that it reports what the sensors said, and a
/// summary whose arithmetic is a widget is a summary nobody can test without a
/// ThingsBoard server. This file takes plain doubles and plain points and
/// returns plain numbers; `test/date_summary_panel_test.dart` exercises it
/// directly.
///
/// ## Why an empty period is null and not zero
///
/// Every field here is nullable, and that is the load-bearing decision of the
/// whole feature. `0.0 kWh` and `--` are different claims: one says the array
/// produced nothing, the other says nothing was recorded. Collapsing them is the
/// exact defect `TelemetryPoint`'s own comment describes one layer down — a
/// fabricated zero used as a placeholder. The date strip reaches back ninety
/// days and the energy history window is fourteen, so "nothing recorded" is a
/// state the user will hit routinely, not an edge case.
library;

import '../models/telemetry_model.dart';
import '../screens/dashboard/utils/energy_helpers.dart';

/// Minimum / average / maximum for one reading over one period.
class PeriodStats {
  const PeriodStats({this.minimum, this.average, this.maximum, this.samples = 0});

  /// Nothing was recorded. Every figure is null and [hasData] is false.
  const PeriodStats.empty() : this();

  final double? minimum;
  final double? average;
  final double? maximum;

  /// How many samples the figures came from.
  ///
  /// **Kept because a one-sample period is a real state.** A grower who opens
  /// an old date and sees `28.0 / 28.0 / 28.0` has been shown one reading, not a
  /// day's range, and the summary can say so because this is not zero.
  final int samples;

  bool get hasData => samples > 0;

  /// Whether the period left the configured band at any point.
  ///
  /// **Tested against [minimum] and [maximum], never against [average].** An
  /// average hides exactly the excursion this is for: a night that dropped to
  /// 12 °C and a day at 30 °C averages to a comfortable 21, and the alert the
  /// user wants is the 12. This is also how `AlarmComparison` in
  /// `lib/utils/alarm_rules.dart` decides the same question, so the background
  /// check and this row agree.
  ///
  /// A null limit means the reading is not monitored, and an unmonitored reading
  /// cannot have breached. Returning false is the only honest answer; raising
  /// here would invent an alarm the rules do not have.
  bool breached({double? min, double? max}) =>
      hasData && ((min != null && minimum! < min) || (max != null && maximum! > max));
}

/// Min / average / max for a plain list of values, in one pass.
///
/// Returns [PeriodStats.empty] for an empty list — **not** a zeroed struct. See
/// the file doc for why.
PeriodStats periodStatsFor(List<double> values) {
  if (values.isEmpty) return const PeriodStats.empty();
  var min = values.first;
  var max = values.first;
  var sum = 0.0;
  for (final value in values) {
    if (value < min) min = value;
    if (value > max) max = value;
    sum += value;
  }
  return PeriodStats(
    minimum: min,
    average: sum / values.length,
    maximum: max,
    samples: values.length,
  );
}

/// [periodStatsFor] over a telemetry series.
PeriodStats periodStatsForPoints(List<TelemetryPoint>? points) {
  if (points == null || points.isEmpty) return const PeriodStats.empty();
  return periodStatsFor([for (final point in points) point.value]);
}

/// Energy accumulated in `[start, end]`, or null when the series does not cover
/// the whole window.
///
/// **The coverage check is the point of this function.** `energyForPeriod`
/// integrates whatever pairs of points it is given and returns `0.0` for a window
/// it has nothing for, which is a correct integral of an empty set and a lie
/// about a day. The power history behind the Overview is a *rolling* fourteen
/// day window, while the date picker reaches back ninety: asking for a day
/// outside it returns no points, integrates to zero, and would print `0.00 kWh`
/// for a day the app never looked at.
///
/// So this refuses to report a total it only partly saw. A partial total is
/// worse than no total, because it is smaller and therefore reads as a quiet day.
///
/// Two samples is the floor rather than one, because a trapezoid needs two: a
/// single point has no duration and integrating it is arithmetic on nothing.
double? energyForCoveredPeriod({
  required List<TelemetryPoint>? points,
  required DateTime start,
  required DateTime end,
}) {
  if (points == null || points.length < 2) return null;
  // `points` is sorted by the callers that produce it (`_fetchEnergyHistory` and
  // `_storeHistory` both sort), so first/last bound the series.
  if (start.isBefore(points.first.timestamp)) return null;
  if (end.isAfter(points.last.timestamp)) return null;
  return energyForPeriod(points, start, end);
}
