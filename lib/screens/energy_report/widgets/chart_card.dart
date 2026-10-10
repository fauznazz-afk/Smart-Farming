import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart'
    show AppSurfaces, AppBorders, AppRadius, AppCard;
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
    final barGroups = createBarChartGroups(buckets: buckets, monthly: monthly);
    final pvColor = categoryColor(MetricCategory.pv);
    final acColor = categoryColor(MetricCategory.ac);

    return Semantics(
      label: 'Energy bar chart showing ${buckets.length} intervals',
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Energy per interval',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
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
                            final index =
                                response?.spot?.touchedBarGroupIndex;
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _LegendValue(
                label: 'PV',
                value: bucket.pvKwh,
                color: pvColor,
              ),
              _LegendValue(
                label: 'AC',
                value: bucket.acKwh,
                color: acColor,
              ),
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
        Text(label, style: const TextStyle(fontSize: 11)),
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}