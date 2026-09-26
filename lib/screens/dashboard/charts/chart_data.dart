import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';

/// Defines a metric to display in telemetry cards.
class MetricDef {
  final String key;
  final String label;
  final String unit;
  final IconData icon;

  const MetricDef(this.key, this.label, this.unit, this.icon);
}

/// Statistics for a series of telemetry points.
class SeriesStats {
  final double latest;
  final double average;
  final double minimum;
  final double maximum;

  const SeriesStats({
    required this.latest,
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  static SeriesStats? fromPoints(List<TelemetryPoint> points) {
    if (points.isEmpty) return null;
    var latest = points.first;
    var sum = 0.0;
    var minimum = points.first.value;
    var maximum = points.first.value;
    for (final point in points) {
      sum += point.value;
      if (point.value < minimum) minimum = point.value;
      if (point.value > maximum) maximum = point.value;
      if (point.timestamp.isAfter(latest.timestamp)) latest = point;
    }
    return SeriesStats(
      latest: latest.value,
      average: sum / points.length,
      minimum: minimum,
      maximum: maximum,
    );
  }
}

/// A chart series with its data points and styling.
class ChartSeries {
  final String label;
  final String unit;
  final List<TelemetryPoint> points;
  final List<FlSpot> spots;
  final Color color;
  final SeriesStats? stats;

  const ChartSeries(
    this.label,
    this.unit,
    this.points,
    this.spots,
    this.color,
    this.stats,
  );
}

/// Bounds for chart axes with calculated intervals.
class ChartBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double chartInterval;
  final double timeInterval;

  const ChartBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.chartInterval,
    required this.timeInterval,
  });

  /// Whether the x range covers more than a single day, in which case axis
  /// labels should show a date rather than a clock time.
  bool get spansMultipleDays =>
      (maxX - minX) > const Duration(days: 1).inMilliseconds;

  factory ChartBounds.fromSeries(List<ChartSeries> series) {
    final points = series.expand((item) => item.points).toList();
    if (points.isEmpty) {
      return const ChartBounds(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        chartInterval: 1,
        timeInterval: 1,
      );
    }
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minimum = double.infinity;
    var maximum = double.negativeInfinity;
    for (final point in points) {
      final x = point.timestamp.millisecondsSinceEpoch.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (point.value < minimum) minimum = point.value;
      if (point.value > maximum) maximum = point.value;
    }

    // Snap the x axis to round clock boundaries so tick labels land on
    // readable times (:00, :30) instead of whatever the first sample was.
    final rawTimeStep = (maxX - minX) / _targetTicks;
    final timeInterval = niceTimeStep(rawTimeStep);
    minX = (minX / timeInterval).floorToDouble() * timeInterval;
    maxX = (maxX / timeInterval).ceilToDouble() * timeInterval;

    final minY = minimum < 0 ? minimum * 1.1 : 0.0;
    final maxY = maximum <= 0 ? 1.0 : maximum * 1.1;
    return ChartBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      chartInterval: niceStep(maxY - minY, divisions: _targetTicks),
      timeInterval: timeInterval,
    );
  }

  /// Number of intervals we aim to fit along each axis.
  static const _targetTicks = 4;
}

/// Rounds a raw axis step up to the next 1 / 2 / 2.5 / 5 x 10^n value.
///
/// Keeps y axis labels on human-friendly numbers such as 0.5 or 25 instead of
/// arbitrary values like 111.45.
double niceStep(double raw, {int divisions = 4}) {
  if (!raw.isFinite || raw <= 0) return 1;
  final target = raw / divisions;
  final magnitude = _pow10Floor(target);
  final normalized = target / magnitude;
  final double step;
  if (normalized <= 1) {
    step = 1;
  } else if (normalized <= 2) {
    step = 2;
  } else if (normalized <= 2.5) {
    step = 2.5;
  } else if (normalized <= 5) {
    step = 5;
  } else {
    step = 10;
  }
  return step * magnitude;
}

const double _minuteMs = 60000;

/// Candidate axis steps in minutes: sub-hour through multi-day.
const _timeStepMinutes = <double>[
  1, 2, 5, 10, 15, 30, //
  60, 120, 180, 360, 720, 1440, //
  2880, 4320, 10080, 20160, 43200, 129600, 259200, 525600,
];

/// Rounds a raw time step (in milliseconds) up to a whole number of minutes.
///
/// The step is always rounded up, never down, so a tick never lands closer
/// together than the caller asked for. Steps beyond a year fall back to one
/// year, which keeps very long custom ranges from collapsing to a single tick.
double niceTimeStep(double rawMs) {
  if (!rawMs.isFinite || rawMs <= 0) return _minuteMs;
  final minutes = rawMs / _minuteMs;
  for (final candidate in _timeStepMinutes) {
    if (minutes <= candidate) return candidate * _minuteMs;
  }
  return _timeStepMinutes.last * _minuteMs;
}

double _pow10Floor(double value) {
  var magnitude = 1.0;
  while (magnitude * 10 <= value) {
    magnitude *= 10;
  }
  while (magnitude > value && magnitude > 1e-9) {
    magnitude /= 10;
  }
  return magnitude;
}

/// Processes telemetry points into chart spots with downsampling.
List<FlSpot> processSpots(List<TelemetryPoint> points) {
  if (points.isEmpty) return const <FlSpot>[];
  if (points.length <= 180) {
    return points
        .map(
          (p) => FlSpot(
            p.timestamp.millisecondsSinceEpoch.toDouble(),
            p.value,
          ),
        )
        .toList(growable: false);
  }

  const targetBuckets = 90;
  final bucketSize = points.length / targetBuckets;
  final spots = <FlSpot>[];

  void addSpot(TelemetryPoint point) {
    final x = point.timestamp.millisecondsSinceEpoch.toDouble();
    if (spots.isEmpty || x > spots.last.x) {
      spots.add(FlSpot(x, point.value));
    }
  }

  addSpot(points.first);

  for (var b = 0; b < targetBuckets; b++) {
    final startIdx = (b * bucketSize).floor();
    var endIdx = ((b + 1) * bucketSize).floor();
    if (endIdx > points.length) endIdx = points.length;
    if (startIdx >= endIdx) continue;

    var minIdx = startIdx;
    var maxIdx = startIdx;
    for (var i = startIdx + 1; i < endIdx; i++) {
      if (points[i].value < points[minIdx].value) minIdx = i;
      if (points[i].value > points[maxIdx].value) maxIdx = i;
    }

    final firstIdx = minIdx < maxIdx ? minIdx : maxIdx;
    final secondIdx = minIdx < maxIdx ? maxIdx : minIdx;

    addSpot(points[firstIdx]);
    if (secondIdx != firstIdx) {
      addSpot(points[secondIdx]);
    }
  }

  final lastX = points.last.timestamp.millisecondsSinceEpoch.toDouble();
  if (spots.isNotEmpty && spots.last.x == lastX) {
    spots[spots.length - 1] = FlSpot(lastX, points.last.value);
  } else {
    spots.add(FlSpot(lastX, points.last.value));
  }

  return spots;
}