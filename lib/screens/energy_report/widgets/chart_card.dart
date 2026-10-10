import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../../widgets/liquid_glass.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../utils/format_helpers.dart';
import '../utils/chart_helpers.dart';
import '../../../services/energy_report_service.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  final bool monthly;
  final List<EnergyBucket> buckets;
  final ValueNotifier<int?> touchedBucketNotifier;

  @override
  Widget build(BuildContext context) {
    final chartWidth = calculateChartWidth(buckets, monthly);
    final axis = calculateMaxY(buckets);
    // `maxY` is passed down, not read from the chart: it is what gives every
    // bar its full-height `surfaceMuted` empty state
    // (`backDrawRodData.toY`). `calculateMaxY` already snaps the axis to a
    // whole number of intervals, so the empty column lands exactly on the top
    // gridline rather than a few pixels off it.
    final barGroups = createBarChartGroups(
      buckets: buckets,
      monthly: monthly,
      maxY: axis.maxY,
    );
    final pvColor = categoryColor(MetricCategory.pv);
    final acColor = categoryColor(MetricCategory.ac);

    return Semantics(
      label: 'Energy bar chart showing ${buckets.length} intervals',
      container: true,
      explicitChildNodes: true,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // **This was a raw 15sp w800, and the token it becomes is the
              // dashboard chart card's own header, not the brief's `headline-md`.
              // **
              //
              // `AppType.labelUppercase` is the brief's `label-uppercase-md`
              // and `ChartSectionHeader` in the dashboard's chart card uses it
              // for exactly this job, so the two chart cards now size a title
              // the same way instead of each picking a number.
              //
              // `headline-md` was the obvious choice -- the brief says it is the
              // uppercase card title -- and it is the wrong one here: at a 320dp
              // viewport and a 2.0 text scale it is 40sp, and
              // "ENERGY PER INTERVAL" at that size is wider than the 296dp
              // column, so an over-ambitious title is what overflows.
              // `label-uppercase-md` fits at both of the scales
              // `energy_report_chart_card_test.dart` already pins.
              //
              // Uppercased at the string, because the brief's rule is that
              // titles and metadata are uppercase, and a title that is uppercase
              // only when the string happens to be written that way is a rule
              // the caller has to keep.
              'Energy per interval'.toUpperCase(),
              style: AppType.labelUppercase.copyWith(color: appPrimaryText),
            ),
            const SizedBox(height: 10),
            _SelectedBucketReadout(
              monthly: monthly,
              buckets: buckets,
              touchedBucketNotifier: touchedBucketNotifier,
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              child: SizedBox(
                height: 230,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth < 300 ? 300 : chartWidth,
                    child: BarChart(
                      BarChartData(
                        maxY: axis.maxY,
                        minY: 0,
                        barGroups: barGroups,
                        // **The brief's grid, and this one was fl_chart's own
                        // default.** `FlGridData(show: true, drawVerticalLine:
                        // false)` with nothing else falls back to
                        // `getDrawingHorizontalLine`, which returns a grey
                        // `FlLine` with no alpha -- a colour and an opacity
                        // that appear nowhere else in the app. Hairlines in
                        // `AppSurfaces.border` at 15%, horizontal only: the
                        // bar chart's vertical axis is a fence of columns and
                        // there is nothing between them to align against, which
                        // is the same reason `drawVerticalLine` is already
                        // false here.
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: axis.interval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: AppSurfaces.border.withValues(alpha: 0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchExtraThreshold: const EdgeInsets.symmetric(
                            vertical: 44,
                            horizontal: 10,
                          ),
                          handleBuiltInTouches: false,
                          touchCallback: (_, response) {
                            final index = response?.spot?.touchedBarGroupIndex;
                            if (index != null &&
                                index >= 0 &&
                                index < buckets.length &&
                                index != touchedBucketNotifier.value) {
                              touchedBucketNotifier.value = index;
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: createLeftTitles(
                            maxY: axis.maxY,
                            interval: axis.interval,
                          ),
                          bottomTitles: createBottomTitles(
                            buckets: buckets,
                            monthly: monthly,
                          ),
                        ),
                      ),
                      swapAnimationDuration: Duration.zero,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (buckets.length > 1)
              _BucketStepper(
                monthly: monthly,
                buckets: buckets,
                touchedBucketNotifier: touchedBucketNotifier,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(label: 'PV', color: pvColor),
                const SizedBox(width: 20),
                _Legend(label: 'AC', color: acColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Readout of the currently selected (touched) interval above the chart.
class _SelectedBucketReadout extends StatelessWidget {
  const _SelectedBucketReadout({
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  final bool monthly;
  final List<EnergyBucket> buckets;
  final ValueNotifier<int?> touchedBucketNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: touchedBucketNotifier,
      builder: (context, touchedIndex, _) {
        final bucket = buckets[clampBucketIndex(touchedIndex, buckets.length)];
        final pvColor = categoryColor(MetricCategory.pv);
        final acColor = categoryColor(MetricCategory.ac);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppSurfaces.track,
            borderRadius: AppRadius.all(AppRadius.badge),
            border: Border.all(color: appDivider(opacity: 0.5)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                monthly
                    ? formatDateLabel(bucket.hour)
                    : formatHourLabel(bucket.hour),
                style: AppType.labelUppercase.copyWith(
                  color: AppSurfaces.onSurface,
                ),
              ),
              _LegendValue(label: 'PV', value: bucket.pvKwh, color: pvColor),
              _LegendValue(label: 'AC', value: bucket.acKwh, color: acColor),
            ],
          ),
        );
      },
    );
  }
}

/// Previous/next stepper plus slider for moving between intervals.
class _BucketStepper extends StatelessWidget {
  const _BucketStepper({
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  final bool monthly;
  final List<EnergyBucket> buckets;
  final ValueNotifier<int?> touchedBucketNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: touchedBucketNotifier,
      builder: (context, touchedIndex, _) {
        final selectedIndex = clampBucketIndex(touchedIndex, buckets.length);
        final bucket = buckets[selectedIndex];
        final label = monthly
            ? formatDateLabel(bucket.hour)
            : formatHourLabel(bucket.hour);
        return Row(
          children: [
            IconButton(
              tooltip: 'Previous interval',
              onPressed: selectedIndex == 0
                  ? null
                  : () => touchedBucketNotifier.value = selectedIndex - 1,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: (buckets.length - 1).toDouble(),
                divisions: buckets.length - 1,
                value: selectedIndex.toDouble(),
                label: label,
                onChanged: (value) =>
                    touchedBucketNotifier.value = value.round(),
              ),
            ),
            IconButton(
              tooltip: 'Next interval',
              onPressed: selectedIndex >= buckets.length - 1
                  ? null
                  : () => touchedBucketNotifier.value = selectedIndex + 1,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          // `labelMicro`, the brief's small-tag slot. This was a raw 11sp, which
          // made the legend the only text in the card sized by a fourth
          // arbitrary number.
          style: AppType.labelMicro.copyWith(color: AppSurfaces.onSurface),
        ),
      ],
    );
  }
}

class _LegendValue extends StatelessWidget {
  const _LegendValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${value.toStringAsFixed(2)}',
          style: AppType.labelMicro.copyWith(color: AppSurfaces.onSurface),
        ),
      ],
    );
  }
}
