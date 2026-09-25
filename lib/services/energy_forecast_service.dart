import 'dart:math' as math;

import '../models/telemetry_model.dart';

/// Calculated energy indicators that can be rendered without a network call.
class EnergyForecastResult {
  const EnergyForecastResult({
    required this.observedProductionKwh,
    required this.dailyProductionEstimateKwh,
    required this.productionTargetKwh,
    required this.targetProgress,
    required this.peakUsageWatts,
    required this.peakUsageAt,
    required this.batteryDepletionHours,
    required this.batteryStateOfCharge,
    required this.sampleStart,
    required this.sampleEnd,
  });

  final double observedProductionKwh;
  final double dailyProductionEstimateKwh;
  final double? productionTargetKwh;
  final double? targetProgress;
  final double? peakUsageWatts;
  final DateTime? peakUsageAt;
  final double? batteryDepletionHours;
  final double? batteryStateOfCharge;
  final DateTime? sampleStart;
  final DateTime? sampleEnd;

  bool get hasProduction => observedProductionKwh > 0;
  bool get hasPeakUsage => peakUsageWatts != null;
  bool get hasBatteryEstimate => batteryDepletionHours != null;
}

/// Performs local forecast calculations from ThingsBoard history.
///
/// [history] uses telemetry keys such as `power_dc`, `power_ac`, `soc`,
/// `voltage`, and `remain_capacity_ah`. Values are expected in watts, percent,
/// volts, and amp-hours respectively.
class EnergyForecastService {
  const EnergyForecastService();

  EnergyForecastResult calculate({
    required Map<String, List<TelemetryPoint>> history,
    Map<String, double> latest = const {},
    double? dailyProductionTargetKwh,
    double? batteryCapacityKwh,
    DateTime? referenceDate,
  }) {
    final day = referenceDate ?? DateTime.now();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final production =
        _points(history, const ['power_dc', 'pv_power', 'solar_power'])
            .where((point) {
              return !point.timestamp.isBefore(dayStart) &&
                  point.timestamp.isBefore(dayEnd);
            })
            .toList(growable: false);
    final usage =
        _points(history, const ['power_ac', 'load_power', 'consumption_power'])
            .where((point) {
              return !point.timestamp.isBefore(dayStart) &&
                  point.timestamp.isBefore(dayEnd);
            })
            .toList(growable: false);
    final soc = _latestPoint(history, latest, const [
      'soc',
      'state_of_charge',
      'battery_soc',
    ]);
    final voltage = _latestPoint(history, latest, const [
      'voltage',
      'battery_voltage',
    ]);
    final current = _latestPoint(history, latest, const [
      'current',
      'battery_current',
    ]);
    final remainingAh = _latestPoint(history, latest, const [
      'remain_capacity_ah',
      'remaining_capacity_ah',
    ]);

    // Only the first/last timestamps are needed here.  Building and sorting a
    // second combined list duplicated the history data and added an
    // O(n log n) operation every time the dashboard recalculated the card.
    DateTime? start;
    DateTime? end;
    void includeTimestamp(DateTime timestamp) {
      if (start == null || timestamp.isBefore(start!)) start = timestamp;
      if (end == null || timestamp.isAfter(end!)) end = timestamp;
    }

    for (final point in production) {
      includeTimestamp(point.timestamp);
    }
    for (final point in usage) {
      includeTimestamp(point.timestamp);
    }
    if (soc != null) includeTimestamp(soc.timestamp);

    final observed = _integrateKwh(production);
    final durationHours = start == null || end == null
        ? 0
        : end!.difference(start!).inSeconds / Duration.secondsPerHour;
    final dailyEstimate = durationHours >= 0.25
        ? observed / (durationHours / 24).clamp(1 / 96, double.infinity)
        : observed;
    final peak = usage.isEmpty
        ? null
        : usage.reduce((a, b) => a.value >= b.value ? a : b);

    double? depletionHours;
    final socValue = soc?.value;
    if (socValue != null && socValue > 0) {
      final capacity =
          batteryCapacityKwh ??
          (remainingAh != null && voltage != null
              ? remainingAh.value * voltage.value / 1000
              : null);
      final loadWatts =
          peak?.value ?? (current?.value ?? 0) * (voltage?.value ?? 0);
      if (capacity != null && capacity > 0 && loadWatts > 0) {
        depletionHours = capacity * (socValue / 100) / (loadWatts / 1000);
      }
    }

    final progress =
        dailyProductionTargetKwh != null && dailyProductionTargetKwh > 0
        ? (dailyEstimate / dailyProductionTargetKwh).clamp(0.0, double.infinity)
        : null;
    return EnergyForecastResult(
      observedProductionKwh: observed,
      dailyProductionEstimateKwh: dailyEstimate,
      productionTargetKwh: dailyProductionTargetKwh,
      targetProgress: progress,
      peakUsageWatts: peak?.value,
      peakUsageAt: peak?.timestamp,
      batteryDepletionHours: depletionHours,
      batteryStateOfCharge: socValue,
      sampleStart: start,
      sampleEnd: end,
    );
  }

  List<TelemetryPoint> _points(
    Map<String, List<TelemetryPoint>> history,
    List<String> keys,
  ) {
    final result = <TelemetryPoint>[];
    for (final key in keys) {
      result.addAll(history[key] ?? const <TelemetryPoint>[]);
    }
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  TelemetryPoint? _latestPoint(
    Map<String, List<TelemetryPoint>> history,
    Map<String, double> latest,
    List<String> keys,
  ) {
    for (final key in keys) {
      final points = history[key];
      if (points != null && points.isNotEmpty) {
        return points.reduce(
          (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
        );
      }
      final value = latest[key];
      if (value != null) {
        return TelemetryPoint(timestamp: DateTime.now(), value: value);
      }
    }
    return null;
  }

  double _integrateKwh(List<TelemetryPoint> points) {
    if (points.length < 2) return 0;
    var totalWh = 0.0;
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final hours =
          current.timestamp.difference(previous.timestamp).inMilliseconds /
          Duration.millisecondsPerHour;
      if (hours > 0 && hours <= 6) {
        totalWh +=
            ((math.max(0, previous.value) + math.max(0, current.value)) / 2) *
            hours;
      }
    }
    return totalWh / 1000;
  }
}
