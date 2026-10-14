import 'dart:math' as math;

import '../../../models/telemetry_model.dart';

/// Integrates a power series into kWh over `[start, end]` using trapezoidal
/// interpolation between consecutive points.
///
/// Gaps longer than one hour are treated as missing data and skipped.
double energyForPeriod(
  List<TelemetryPoint> points,
  DateTime start,
  DateTime end,
) {
  var kwh = 0.0;
  for (var i = 1; i < points.length; i++) {
    final previous = points[i - 1];
    final current = points[i];
    final gapMs = current.timestamp
        .difference(previous.timestamp)
        .inMilliseconds;
    if (gapMs <= 0 || gapMs > 60 * 60 * 1000) continue;
    final left = previous.timestamp.isAfter(start)
        ? previous.timestamp
        : start;
    final right = current.timestamp.isBefore(end) ? current.timestamp : end;
    final durationMs = right.difference(left).inMilliseconds;
    if (durationMs <= 0) continue;
    final leftFraction =
        left.difference(previous.timestamp).inMilliseconds / gapMs;
    final rightFraction =
        right.difference(previous.timestamp).inMilliseconds / gapMs;
    final leftPower =
        previous.value + (current.value - previous.value) * leftFraction;
    final rightPower =
        previous.value + (current.value - previous.value) * rightFraction;
    final averageWatts = math
        .max(0.0, (leftPower + rightPower) / 2)
        .toDouble();
    kwh += averageWatts * durationMs / 3600000000;
  }
  return kwh;
}

/// Energy accumulated in the active window and the window before it.
typedef EnergyComparison = ({double current, double previous});

/// Compares the selected period against the equivalent preceding period.
EnergyComparison energyComparison({
  required Map<String, List<TelemetryPoint>> history,
  required String key,
  required bool weekly,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final periodStart = weekly
      ? today.subtract(const Duration(days: 6))
      : today;
  final previousStart = weekly
      ? periodStart.subtract(const Duration(days: 7))
      : today.subtract(const Duration(days: 1));
  final points = history[key] ?? const <TelemetryPoint>[];
  return (
    current: energyForPeriod(points, periodStart, reference),
    previous: energyForPeriod(points, previousStart, periodStart),
  );
}

/// What a period of energy is worth, and what it cost.
///
/// **Three numbers, and the third is the honest one.** `solarValue` is what the
/// array produced at the user's own tariff and `loadCost` is what the house
/// drew at that same tariff; `balance` is the difference.
///
/// **The naming matters more than the arithmetic.** Two of the obvious names
/// for `solarValue` are wrong. It is not "saving": a saving is money that was
/// not spent, and this array's output only becomes unspent money where it
/// displaces grid import, which the app has no visibility into — there is no
/// import/export meter on this installation, only a PZEM on the DC and AC sides.
/// And it is not "revenue": nobody is being paid. The panel this feeds already
/// refuses to label a healthy reading with a colour that means a condition, and
/// a figure labelled `SAVED` would be the same mistake in money.
///
/// A negative [balance] is a real and common result — a house that draws more
/// than the array makes — so nothing here clamps, and nothing hides the sign.
typedef MoneyPeriod = ({double solarValue, double loadCost, double balance});

/// Prices a period of generation against consumption at [tariffPerKwh].
///
/// [tariffPerKwh] is rupiah per kWh. **A tariff of zero or null is null, not
/// zero**: an unset tariff is "the user has not told us", and reporting
/// "Rp 0 hemat" every morning is a claim the app cannot support.
MoneyPeriod? moneyForPeriod({
  required double solarKwh,
  required double loadKwh,
  required double? tariffPerKwh,
}) {
  if (tariffPerKwh == null || tariffPerKwh <= 0) return null;
  if (solarKwh.isNaN || loadKwh.isNaN) return null;
  final solarValue = solarKwh * tariffPerKwh;
  final loadCost = loadKwh * tariffPerKwh;
  return (
    solarValue: solarValue,
    loadCost: loadCost,
    balance: solarValue - loadCost,
  );
}

/// How well an array of [installedWp] is performing over a period.
///
/// **Only quantities that can be derived from what the device actually
/// publishes.** `capacityFactor` and `fullLoadHours` are; a performance ratio
/// is not, because PR needs measured irradiance and this greenhouse has a lux
/// sensor indoors-facing and no pyranometer, so a PR here would be a number
/// computed from an assumption the app cannot check. The honest absence of a PR
/// is better than a fabricated one.
typedef PvPerformance = ({double fullLoadHours, double capacityFactor});

/// Derives array performance from energy produced over [hours].
///
/// [installedWp] is the array's nameplate in watts. **A non-positive or
/// unknown nameplate is null** — a capacity factor is a ratio against the array
/// you own, and dividing by a guess produces a plausible-looking figure that
/// means nothing.
PvPerformance? pvPerformance({
  required double solarKwh,
  required double? installedWp,
  required double hours,
}) {
  if (installedWp == null || installedWp <= 0) return null;
  if (solarKwh.isNaN || hours <= 0) return null;
  final fullLoadHours = solarKwh * 1000 / installedWp;
  return (
    fullLoadHours: fullLoadHours,
    // What fraction of the nameplate the array actually delivered, averaged
    // over the whole window. Never above 1 for a sane installation, and it is
    // NOT clamped: a reading above 1 means the nameplate is wrong or the meter
    // is, and hiding that is the one outcome worse than an odd number.
    capacityFactor: (fullLoadHours / hours).clamp(0.0, 1.0),
  );
}

/// Indonesian rupiah, grouped the way a person reads it.
///
/// **`Rp 12.400`, not `Rp 12,400.00`.** The panel is a readout, not an invoice,
/// and every other figure on it is right-trimmed by [slotNumber] for exactly
/// this reason. Sub-rupiah is dropped rather than rounded — the smallest unit
/// the grid meters.
String rupiah(num value) {
  if (value.isNaN) return '--';
  final whole = value.round();
  final digits = whole.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return whole < 0 ? '-Rp $grouped' : 'Rp $grouped';
}
