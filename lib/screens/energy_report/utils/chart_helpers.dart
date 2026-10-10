import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/charts/chart_data.dart';
import '../../dashboard/utils/design_tokens.dart'
    show AppRadius;
import '../../../services/energy_report_service.dart';

/// The Y axis interval for the energy report, and the maximum it implies.
///
/// The axis used to divide the padded maximum by four, which put the gridlines
/// on whatever fraction that produced. A peak of 0.369 kWh gave labels reading
/// `0.12 / 0.23 / 0.35 / 0.46` -- each one correct to the displayed precision
/// and none of them a number anyone would write. The dashboard's telemetry chart
/// has used `niceStep` for exactly this reason all along; this one had its own
/// arithmetic and nobody compared them.
///
/// So the interval comes from `niceStep` here too, and the maximum is snapped up
/// to a whole number of intervals. That also removes a second defect for free:
/// `maxY` and the top gridline used to be different numbers, so the topmost
/// label was drawn at a height the plot area had no room for and came out
/// clipped in half by the card's padding above it. Snapped, the top gridline
/// *is* the maximum, so the label lands on the boundary of the plot rather than
/// outside it.
({double maxY, double interval}) calculateMaxY(List<EnergyBucket> buckets) {
  var maxValue = 0.0;
  for (final bucket in buckets) {
    if (bucket.pvKwh > maxValue) maxValue = bucket.pvKwh;
    if (bucket.acKwh > maxValue) maxValue = bucket.acKwh;
  }
  if (maxValue <= 0) {
    return (maxY: 1.0, interval: 0.25);
  }
  final padded = maxValue * 1.25;
  final interval = niceStep(padded, divisions: 4);
  final maxY = (padded / interval).ceilToDouble() * interval;
  return (maxY: maxY, interval: interval);
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
  final pvColor = categoryColor(MetricCategory.pv);
  final acColor = categoryColor(MetricCategory.ac);
  return [
    for (var i = 0; i < buckets.length; i++)
      BarChartGroupData(
        x: i,
        barsSpace: 2,
        barRods: [
          BarChartRodData(
            toY: buckets[i].pvKwh,
            color: pvColor,
            width: monthly ? 6 : 8,
            borderRadius: BorderRadius.circular(AppRadius.bar),
          ),
          BarChartRodData(
            toY: buckets[i].acKwh,
            color: acColor,
            width: monthly ? 6 : 8,
            borderRadius: BorderRadius.circular(AppRadius.bar),
          ),
        ],
      ),
  ];
}

/// Creates left axis titles for the chart.
///
/// [interval] rather than `maxY / 4`, for the reason documented on
/// [calculateMaxY]: the labels were landing on whatever fraction the padded
/// maximum divided into, and `0.12 / 0.23 / 0.35 / 0.46` is not a scale anyone
/// reads. The caller now passes the same `niceStep` interval the maximum was
/// snapped to, so the topmost label sits exactly on the top of the plot instead
/// of above it getting clipped by the card padding.
///
/// The label is also centred on its gridline, which means the top one hangs
/// half outside the plot area. `SideTitleWidget` is given the axis alignment so
/// the reserved column absorbs that overhang instead of the text being cut.
AxisTitles createLeftTitles({
  required double maxY,
  required double interval,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 38,
      interval: interval,
      getTitlesWidget: (value, _) => SideTitleWidget(
        // `AxisSide.top` anchors the widget's *top* to the gridline, so the
        // label hangs below its own line. Everything else is centred on it.
        // Without this the topmost label is centred on the top of the plot and
        // the upper half is cut off by the card's padding.
        axisSide: value >= maxY - interval / 2
            ? AxisSide.top
            : AxisSide.bottom,
        child: Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 9,
            color: faintColor,
          ),
        ),
      ),
    ),
  );
}

/// Creates bottom axis titles for the chart.
AxisTitles createBottomTitles({
  required List<EnergyBucket> buckets,
  required bool monthly,
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
              color: faintColor,
            ),
          ),
        );
      },
    ),
  );
}
