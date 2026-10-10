import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/charts/chart_data.dart';
import '../../dashboard/utils/design_tokens.dart';
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
///
/// [maxY] is the axis maximum from [calculateMaxY], and it is what makes the
/// empty state work: `BarChartRodData.backDrawRodData` runs from
/// `backDrawRodData.fromY` to `backDrawRodData.toY`, so `maxY` gives each bar a
/// full-height column behind it.
///
/// **The bar is the brief's recipe.** A full-height column of
/// `AppSurfaces.surfaceMuted` with `AppRadius.sm` on the top two corners, and
/// the category hue at full strength on top of it. What this replaces was
/// `BorderRadius.circular(AppRadius.bar)`, which rounds a bar into a stadium —
/// the radius the brief reserves for the *progress track*, the one full-round
/// shape in the system that is not a filter chip. A bar is not a pill; the brief
/// gives chart bar tops `rounded.sm` and nothing else.
///
/// The radius has a second effect that is easy to miss: `BarChartPainter` reads
/// the **main rod's** `borderRadius` when it builds the background rod's
/// `RRect`, so the empty column is rounded by the same value as the filled one.
/// Getting the rod's radius right therefore fixes both at once — there is no
/// separate radius to keep in step.
List<BarChartGroupData> createBarChartGroups({
  required List<EnergyBucket> buckets,
  required bool monthly,
  required double maxY,
  Color? emptyStateColor,
}) {
  final pvColor = categoryColor(MetricCategory.pv);
  final acColor = categoryColor(MetricCategory.ac);
  // The empty state's fill. A parameter rather than a constant because a test
  // can then assert the brief's `#333333` without this file re-declaring it.
  final trackColor = emptyStateColor ?? AppSurfaces.surfaceMuted;
  final width = monthly ? 6.0 : 8.0;
  // `rounded.sm` on the top corners only. A bottom radius would lift the bar
  // off the axis and read as a chip floating above the baseline.
  final radius = BorderRadius.only(
    topLeft: Radius.circular(AppRadius.sm),
    topRight: Radius.circular(AppRadius.sm),
  );
  return [
    for (var i = 0; i < buckets.length; i++)
      BarChartGroupData(
        x: i,
        barsSpace: 2,
        barRods: [
          BarChartRodData(
            toY: buckets[i].pvKwh,
            color: pvColor,
            width: width,
            borderRadius: radius,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              fromY: 0,
              toY: maxY,
              color: trackColor,
            ),
          ),
          BarChartRodData(
            toY: buckets[i].acKwh,
            color: acColor,
            width: width,
            borderRadius: radius,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              fromY: 0,
              toY: maxY,
              color: trackColor,
            ),
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
/// reads. The caller passes the same `niceStep` interval the maximum was
/// snapped to, so the topmost label sits on the top of the plot rather than
/// above it.
///
/// **These were 9sp in `faintColor`; both halves are the brief's axis-label
/// tokens now.** `AppType.labelMicro` is the 10sp bold label slot and
/// `AppSurfaces.onSurfaceVariant` is the metadata ink — `faintColor` is the same
/// constant as the latter, so only the size moved, from a fourth arbitrary
/// number to the scale the brief actually has.
///
/// **The top label is pulled inside the plot by `fitInside`, for the same
/// measured reason the dashboard's `chart_card.dart` uses it.** fl_chart centres
/// every `SideTitleWidget` on its own gridline whatever `AxisSide` is passed —
/// `SideTitlesFlex` offsets the child by `axisPixelLocation - size / 2` and the
/// `Container` inside `SideTitleWidget` shrink-wraps to its child, so the
/// widget's alignment and margin cancel out. The `axisSide: AxisSide.top`
/// switch this replaces therefore bought `space / 2` and nothing more.
/// Measured here at 381 dp against the card's own `BarChart` rect, before the
/// change: the top label hung 16dp above the chart at scale 1 and 52dp at
/// scale 2, against a chart 230dp tall. After it, both are 4dp inside and the
/// chart is still 230dp.
///
/// **`axisSide` has to be the axis's own side, and `fitInside` is why.** The
/// `AxisSide` passed to `SideTitleWidget` decides two things: the
/// alignment of the label inside the reserved column, and *which way*
/// `AxisChartHelper.calcFitInsideOffset` returns its offset in — vertical for
/// `left`/`right`, horizontal for `top`/`bottom`. Passing `AxisSide.bottom`
/// for a left-axis label translates it sideways and leaves the clip in place,
/// which is exactly what the first attempt at this did. `meta.axisSide` is the
/// side the label is actually drawn on, so it is the only value that makes the
/// offset go the right way — and it also right-aligns the whole axis on the
/// plot edge instead of centring each label inside the 38dp column, which is
/// what the dashboard's Y axis already does.
///
/// `distanceFromEdge: AppSpacing.xs` keeps a hair of the label inside the
/// painted edge. The plot loses nothing: the label goes *into* it.
AxisTitles createLeftTitles({required double maxY, required double interval}) {
  final labelStyle = AppType.labelMicro.copyWith(
    color: AppSurfaces.onSurfaceVariant,
  );
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 38,
      interval: interval,
      getTitlesWidget: (value, meta) {
        final isMax = value >= maxY - interval / 2;
        return SideTitleWidget(
          axisSide: meta.axisSide,
          fitInside: SideTitleFitInsideData.fromTitleMeta(
            meta,
            enabled: isMax,
            distanceFromEdge: AppSpacing.xs,
          ),
          child: Text(value.toStringAsFixed(2), style: labelStyle),
        );
      },
    ),
  );
}

/// Creates bottom axis titles for the chart.
AxisTitles createBottomTitles({
  required List<EnergyBucket> buckets,
  required bool monthly,
}) {
  final labelStyle = AppType.labelMicro.copyWith(
    color: AppSurfaces.onSurfaceVariant,
  );
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
          child: Text(text, style: labelStyle),
        );
      },
    ),
  );
}
