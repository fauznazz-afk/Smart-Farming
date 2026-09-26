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
