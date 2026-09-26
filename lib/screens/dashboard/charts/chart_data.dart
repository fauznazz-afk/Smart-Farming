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
    final xValues = points
        .map((point) => point.timestamp.millisecondsSinceEpoch.toDouble())
        .toList();
    final yValues = points.map((point) => point.value).toList();
    final minX = xValues.reduce((a, b) => a < b ? a : b);
    final maxX = xValues.reduce((a, b) => a > b ? a : b);
    final minimum = yValues.reduce((a, b) => a < b ? a : b);
    final maximum = yValues.reduce((a, b) => a > b ? a : b);
    final minY = minimum < 0 ? minimum * 1.1 : 0.0;
    final maxY = maximum <= 0 ? 1.0 : maximum * 1.1;
    final chartInterval = (maxY - minY) / 3;
    final timeInterval = (maxX - minX) / 3;
    return ChartBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      chartInterval: chartInterval == 0 ? 1 : chartInterval,
      timeInterval: timeInterval == 0 ? 1 : timeInterval,
    );
  }
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