import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../utils/format_helpers.dart';
import '../utils/chart_helpers.dart';
import '../../../services/energy_report_service.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.theme,
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  /// The appearance to paint.
  ///
  /// **This replaced a `bool isDark` and it is not a pure rename**, because the
  /// card draws a surface. The readout well below is filled with
  /// [AppSurfaces.track], and Dracula's track `#1E1F29` is a different colour
  /// from the app's dark `#131A18` — the two are within 0.007 of relative
  /// luminance of each other but they are not the same value, and a `bool`
  /// cannot tell them apart. `createLeftTitles` and `createBottomTitles` still
  /// take a `bool`; they draw text and are on the `faintColor` half of the split,
  /// so they are handed `theme.isDark` below.
  final AppTheme theme;
  final bool monthly;
  final List<EnergyBucket> buckets;
  final ValueNotifier<int?> touchedBucketNotifier;

  @override
  Widget build(BuildContext context) {
    final chartWidth = calculateChartWidth(buckets, monthly);
    final axis = calculateMaxY(buckets);
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
                theme: theme,
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
                            // Both of these still ask a `bool`. They draw axis
                            // text, which is the `faintColor` family, and
                            // Dracula deliberately reuses the app's dark text
                            // palette unchanged — see `faintColor` for the
                            // measurement. So this is the `theme.isDark`
                            // direction of the split, not a leftover.
                            leftTitles: createLeftTitles(
                              maxY: axis.maxY,
                              interval: axis.interval,
                              isDark: theme.isDark,
                            ),
                            bottomTitles: createBottomTitles(
                              buckets: buckets,
                              monthly: monthly,
                              isDark: theme.isDark,
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
    required this.theme,
    required this.monthly,
    required this.buckets,
    required this.touchedBucketNotifier,
  });

  final AppTheme theme;
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
            color: AppSurfaces.track(theme),
            borderRadius: AppRadius.all(AppRadius.badge),
            border: Border.all(color: appDivider(theme: theme, opacity: 0.5)),
          ),
          child: Wrap(
            // **A `Wrap`, not a `Row`, and this is the second time this repo has
            // had to learn it.** It was a `Row` holding an `Expanded` date label
            // and two `_LegendValue`s that are `MainAxisSize.min` with no
            // `Flexible` around them, so at a 2x system font scale the values had
            // nowhere to go. Measured, not predicted:
            //
            // | viewport | text scale | overflow |
            // |---|---|---|
            // | 381 dp | 1.0 | none |
            // | 320 dp | 1.0 | none |
            // | 381 dp | 2.0 | **19 px on the right** |
            // | 320 dp | 2.0 | **80 px on the right** |
            //
            // The obvious fix is `Flexible` plus `TextOverflow.ellipsis`, and
            // that is exactly the regression this project already shipped once:
            // a unit truncated to `109....`, on 27 September 2026, alongside two
            // other label defects in the same session that `flutter analyze`, a
            // release build and every existing test all passed. A truncated
            // energy figure is worse than a wrapped one, because the reader
            // cannot tell a rounded value from a cut-off one.
            //
            // So the values wrap to a second line instead of shrinking. Nothing
            // is ever abbreviated, and the date label gives up its width first
            // because it is the one item that can afford to.
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
                color: const Color(0xFFFFC857),
              ),
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