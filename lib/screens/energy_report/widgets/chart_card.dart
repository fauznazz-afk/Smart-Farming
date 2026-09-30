import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../utils/format_helpers.dart';
import '../utils/chart_helpers.dart';
import '../../../services/energy_report_service.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.isDark,
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  final bool isDark;
  final bool monthly;
  final List<EnergyBucket> buckets;
  final ValueNotifier<int?> touchedBucketNotifier;

  @override
  Widget build(BuildContext context) {
    final chartWidth = calculateChartWidth(buckets, monthly);
    final maxY = calculateMaxY(buckets);
    final barGroups = createBarChartGroups(buckets: buckets, monthly: monthly);

    return Semantics(
      label: 'Energy bar chart showing ${buckets.length} intervals',
      child: Card(
        child: Padding(
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
                isDark: isDark,
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
                        // The swap animation runs on *every* data change, not
                        // just the first paint, and this chart is rebuilt
                        // whenever a bucket is touched, when the period changes
                        // and on the 5-minute refresh. So the rods spent 150ms
                        // lerping between the same two numbers several times a
                        // session. The dashboard's LineChart already opts out
                        // with `duration: Duration.zero`
                        // (dashboard/widgets/chart_card.dart:285) for the same
                        // reason. fl_chart names the BarChart equivalent
                        // `swapAnimationDuration`; its default is 150ms.
                        BarChartData(
                          maxY: maxY,
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
                              maxY: maxY,
                              isDark: isDark,
                            ),
                            bottomTitles: createBottomTitles(
                              buckets: buckets,
                              monthly: monthly,
                              isDark: isDark,
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
                  _Legend(label: 'PV', color: const Color(0xFFFFC857)),
                  const SizedBox(width: 20),
                  _Legend(label: 'AC', color: const Color(0xFF69B7FF)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Readout of the currently selected (touched) interval above the chart.
class _SelectedBucketReadout extends StatelessWidget {
  const _SelectedBucketReadout({
    required this.isDark,
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  final bool isDark;
  final bool monthly;
  final List<EnergyBucket> buckets;
  final ValueNotifier<int?> touchedBucketNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: touchedBucketNotifier,
      builder: (context, touchedIndex, _) {
        final bucket = buckets[clampBucketIndex(touchedIndex, buckets.length)];
        // A readout, so it is cut into the card it sits in: the track fill, not
        // a second raised surface. It was `white @ 0.07` / `black @ 0.045`,
        // which over a now-opaque card is a wash of nothing, and it carried no
        // edge at all.
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppSurfaces.track(isDark),
            borderRadius: AppRadius.all(AppRadius.badge),
            border: Border.all(color: appDivider(isDark: isDark, opacity: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  monthly
                      ? formatDateLabel(bucket.hour)
                      : formatHourLabel(bucket.hour),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _LegendValue(
                label: 'PV',
                value: bucket.pvKwh,
                color: const Color(0xFFFFC857),
              ),
              const SizedBox(width: 12),
              _LegendValue(
                label: 'AC',
                value: bucket.acKwh,
                color: const Color(0xFF69B7FF),
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