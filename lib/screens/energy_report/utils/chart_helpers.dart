import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../services/energy_report_service.dart';

/// Calculates the maximum Y value for the chart with 25% padding.
double calculateMaxY(List<EnergyBucket> buckets) {
  var maxValue = 0.0;
  for (final bucket in buckets) {
    if (bucket.pvKwh > maxValue) maxValue = bucket.pvKwh;
    if (bucket.acKwh > maxValue) maxValue = bucket.acKwh;
  }
  return maxValue <= 0 ? 1.0 : maxValue * 1.25;
}

/// Clamps a touched bucket index into the valid range for [buckets].
///
/// Returns 0 for an empty list so callers always have a safe index.
int clampBucketIndex(int? index, int length) {
  if (length <= 0) return 0;
  return (index ?? 0).clamp(0, length - 1);
}

/// Calculates the chart width based on number of buckets.
double calculateChartWidth(List<EnergyBucket> buckets, bool monthly) {
  return (buckets.length * (monthly ? 18 : 22)).toDouble();
}

/// Creates bar chart groups from energy buckets.
List<BarChartGroupData> createBarChartGroups({
  required List<EnergyBucket> buckets,
  required bool monthly,
}) {
  return [
    for (var i = 0; i < buckets.length; i++)
      BarChartGroupData(
        x: i,
        barsSpace: 2,
        barRods: [
          BarChartRodData(
            toY: buckets[i].pvKwh,
            color: const Color(0xFFFFC857),
            width: monthly ? 6 : 8,
            borderRadius: BorderRadius.circular(3),
          ),
          BarChartRodData(
            toY: buckets[i].acKwh,
            color: const Color(0xFF69B7FF),
            width: monthly ? 6 : 8,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
  ];
}

/// Creates left axis titles for the chart.
AxisTitles createLeftTitles({
  required double maxY,
  required bool isDark,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 38,
      interval: maxY / 4,
      getTitlesWidget: (value, _) => Text(
        value.toStringAsFixed(2),
        style: TextStyle(
          fontSize: 9,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    ),
  );
}

/// Creates bottom axis titles for the chart.
AxisTitles createBottomTitles({
  required List<EnergyBucket> buckets,
  required bool monthly,
  required bool isDark,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 26,
      interval: monthly ? 5 : 4,
      getTitlesWidget: (value, _) {
        final index = value.toInt();
        if (index < 0 || index >= buckets.length) {
          return const SizedBox.shrink();
        }
        final date = buckets[index].hour;
        final text = monthly
            ? '${date.day}'
            : date.hour.toString().padLeft(2, '0');
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        );
      },
    ),
  );
}