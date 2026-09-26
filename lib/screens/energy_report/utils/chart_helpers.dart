import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../services/energy_report_service.dart';

/// Calculates the maximum Y value for the chart with 25% padding.
double calculateMaxY(List<EnergyBucket> buckets) {
  final maxValue = buckets.fold<double>(
    0,
    (max, item) => max > item.pvKwh ? (max > item.acKwh ? max : item.acKwh) : (item.pvKwh > item.acKwh ? item.pvKwh : item.acKwh),
  );
  return maxValue <= 0 ? 1.0 : maxValue * 1.25;
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