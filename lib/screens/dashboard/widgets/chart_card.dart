import '../utils/color_helpers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/date_helpers.dart';
import '../utils/history_range.dart';

/// Human readable name for a dashboard page prefix.
String prefixTitle(String prefix) => switch (prefix) {
  'pv' => 'PV',
  'ac' => 'AC',
  _ => 'Battery',
};

/// Title + range label + live/polling indicator above a telemetry chart.
class ChartSectionHeader extends StatelessWidget {
  const ChartSectionHeader({
    super.key,
    required this.title,
    required this.isDark,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.realtimeConnected,
    required this.onPickRange,
    this.metric,
    this.onMetricChanged,
  });

  final String title;
  final bool isDark;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;
  final VoidCallback onPickRange;

  /// The metric currently plotted, and how to change it.
  ///
  /// The chart used to draw Voltage, Current and Power on one shared Y axis.
  /// They are three different units on three completely different scales, so
  /// only the largest was ever legible: for PV, Power runs to a few hundred
  /// watts while Current stays under 3 A, and the current trace collapsed onto
  /// the X axis. The legend made all three look equally available. Picking one
  /// metric at a time is the only way three units fit on an axis.
  final ChartMetric? metric;
  final ValueChanged<ChartMetric>? onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = describeHistoryRange(
      selectedDate: selectedDate,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rangeLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: faintColor(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Choose custom telemetry date range',
          child: IconButton(
            tooltip: 'Choose date range',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: onPickRange,
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          realtimeConnected ? Icons.wifi : Icons.wifi_off,
          size: 13,
          color: realtimeConnected
              ? Colors.green
              : (faintColor(isDark)),
        ),
        const SizedBox(width: 3),
        Text(
          realtimeConnected ? 'Live' : 'Polling',
          style: TextStyle(
            fontSize: 10,
            color: realtimeConnected
                ? Colors.green
                : (faintColor(isDark)),
          ),
        ),
      ],
    );
  }
}

/// One of the three metrics a device chart can plot.
enum ChartMetric {
  voltage('Voltage', 'V', 'volt'),
  current('Current', 'A', 'ampere'),
  power('Power', 'W', 'watt');

  const ChartMetric(this.label, this.unit, this.keyFragment);

  final String label;
  final String unit;

  /// Matches the suffix `historyKeysForPrefix` uses, e.g. `power_dc` or `power`.
  final String keyFragment;

  /// The history key for a page prefix, e.g. `pv` + power -> `power_dc`.
  String keyFor(String prefix) => prefix == 'battery' ? 'power' : 'power_$prefix';
}

/// Glass card plotting one metric for one device prefix.
///
/// The [points], [spots], [stats] and [boundsCache] maps are owned by the
/// caller so that downsampling and bounds stay memoized across rebuilds.
class TelemetryChartCard extends StatelessWidget {
  const TelemetryChartCard({
    super.key,
    required this.prefix,
    required this.isDark,
    required this.performanceMode,
    required this.points,
    required this.spots,
    required this.stats,
    required this.boundsCache,
    required this.loading,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPointerActive,
    required this.seedColor,
    required this.onMetricChanged,
    this.metric = ChartMetric.power,
  });

  final String prefix;

  /// The theme accent, so the plotted series follows the chosen palette.
  final Color seedColor;
  final bool isDark;
  final bool performanceMode;

  /// Which metric to plot. The card plots exactly one, see [ChartMetric].
  final ChartMetric metric;

  final ValueChanged<ChartMetric> onMetricChanged;
  final Map<String, List<TelemetryPoint>> points;
  final Map<String, List<FlSpot>> spots;
  final Map<String, SeriesStats?> stats;
  final Map<String, ChartBounds> boundsCache;
  final bool loading;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<bool> onPointerActive;

  @override
  Widget build(BuildContext context) {
    final series = _buildSeries();
    final bounds = boundsCache.putIfAbsent(
      prefix,
      () => ChartBounds.fromSeries(series),
    );
    final hasData = series.any((item) => item.points.isNotEmpty);
    final title = prefixTitle(prefix);

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      // A loading spinner or an empty message does not need a full plot's worth of
      // height; reserving it pushed everything below the fold for nothing.
      height: (loading || !hasData) ? 170 : 400,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      semanticLabel: '$title ${metric.label} chart showing '
          '${describeHistoryRange(selectedDate: selectedDate, rangeStart: rangeStart, rangeEnd: rangeEnd)}',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
          ? const Center(child: Text('Tidak ada data untuk rentang ini'))
          : Column(
              children: [
                // Picks which single metric is plotted. Three units on one
                // shared axis was the problem this replaces.
                Row(
                  children: [
                    for (final option in ChartMetric.values) ...[
                      if (option != ChartMetric.values.first)
                        const SizedBox(width: 8),
                      _MetricChip(
                        metric: option,
                        selected: option == metric,
                        isDark: isDark,
                        color: option == metric
                            ? strongMetricColor(
                                seedColor: seedColor,
                                index: ChartMetric.values.indexOf(option),
                                isDark: isDark,
                              )
                            : null,
                        onTap: () => onMetricChanged(option),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => onPointerActive(true),
                    onPointerUp: (_) => onPointerActive(false),
                    onPointerCancel: (_) => onPointerActive(false),
                    child: RepaintBoundary(
                      child: LineChart(
                        _lineChartData(series, bounds),
                        duration: Duration.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: series.map(_SeriesStatistics.new).toList()),
              ],
            ),
    );
  }

  /// The colour the plotted metric gets, derived from the theme accent.
  ///
  /// The three series used to be hard-coded Material red, green and blue, which
  /// meant picking the "Ocean cyan" accent changed the cards but left the chart
  /// exactly as it was. It was the one place the theme was ignored.
  Color get _seriesColor {
    final index = ChartMetric.values.indexOf(metric);
    return strongMetricColor(seedColor: seedColor, index: index, isDark: isDark);
  }

  List<ChartSeries> _buildSeries() => [
    _seriesFor(metric.label, metric.unit, _seriesColor),
  ];

  ChartSeries _seriesFor(String label, String unit, Color color) {
    final key = '${prefix}_${label.toLowerCase()}';
    final seriesPoints = points[key] ?? const <TelemetryPoint>[];
    return ChartSeries(
      label,
      unit,
      seriesPoints,
      spots.putIfAbsent(key, () => processSpots(seriesPoints)),
      color,
      stats[key] ?? SeriesStats.fromPoints(seriesPoints),
    );
  }

  LineChartData _lineChartData(List<ChartSeries> series, ChartBounds bounds) {
    return LineChartData(
      minX: bounds.minX,
      maxX: bounds.maxX,
      minY: bounds.minY,
      maxY: bounds.maxY,
      gridData: _gridData(bounds),
      titlesData: _titlesData(bounds),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 14,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          tooltipMargin: 12,
          maxContentWidth: 150,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipBorder: BorderSide(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1,
          ),
          getTooltipColor: (_) =>
              isDark ? const Color(0xCC18211D) : const Color(0xD9FFFFFF),
          getTooltipItems: (touchedSpots) {
            if (touchedSpots.isEmpty) return const [];
            final time = formatAxisTime(touchedSpots.first.x);
            final values = <String>[
              for (final spot in touchedSpots)
                '${formatAxisNumber(spot.y)} ${series[spot.barIndex].unit}',
            ];
            final tooltip = LineTooltipItem(
              '$time\n${values.join('  ·  ')}',
              TextStyle(
                color: isDark ? Colors.white : const Color(0xFF17211C),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            );
            return List<LineTooltipItem?>.generate(
              touchedSpots.length,
              (index) => index == 0 ? tooltip : null,
            );
          },
        ),
      ),
      lineBarsData: series
          .map(
            (item) => LineChartBarData(
              spots: item.spots,
              isCurved: false,
              color: item.color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
          )
          .toList(),
    );
  }

  FlGridData _gridData(ChartBounds bounds) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: bounds.chartInterval,
      verticalInterval: bounds.timeInterval,
      getDrawingHorizontalLine: (_) => FlLine(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.08),
        strokeWidth: 1,
      ),
      getDrawingVerticalLine: (_) => FlLine(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.06),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _titlesData(ChartBounds bounds) {
    final labelStyle = TextStyle(
      fontSize: 10,
      color: isDark ? const Color(0xFFB7C4BD) : const Color(0xFF64748B),
    );
    return FlTitlesData(
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          interval: bounds.chartInterval,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            space: 4,
            child: Text(formatAxisNumber(value), style: labelStyle),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: bounds.timeInterval,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            space: 6,
            // A tick sitting exactly on the plot edge would be half clipped, so
            // nudge the first and last labels back inside the chart.
            child: Transform.translate(
              offset: Offset(_edgeShift(meta), 0),
              child: Text(
                formatAxisTick(
                  value,
                  spansMultipleDays: bounds.spansMultipleDays,
                ),
                style: labelStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pixels to shift a bottom-axis label so it stays inside the plot area.
  ///
  /// Uses the pixel position rather than the axis value, so the guard holds
  /// regardless of how the bounds were aligned.
  double _edgeShift(TitleMeta meta) {    const halfLabelWidth = 16.0;
    if (meta.axisPosition < halfLabelWidth) return halfLabelWidth;
    if (meta.axisPosition > meta.parentAxisSize - halfLabelWidth) {
      return -halfLabelWidth;
    }
    return 0;
  }
}
/// Latest, average and range for the plotted series.
///
/// Was five lines at 9dp in English. Nine dp is below the point where text
/// stops being readable, and five rows of numbers competed with the chart for
/// attention without adding anything, since the range is the only part that is
/// not already visible in the plot.
class _SeriesStatistics extends StatelessWidget {
  const _SeriesStatistics(this.series);

  final ChartSeries series;

  @override
  Widget build(BuildContext context) {
    final stats = series.stats;
    if (stats == null) return const Expanded(child: SizedBox.shrink());
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${series.label} (${series.unit})',
            style: TextStyle(
              color: series.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Terakhir ${formatAxisNumber(stats.latest)} · '
            'rata-rata ${formatAxisNumber(stats.average)} ${series.unit}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            '↓ ${formatAxisNumber(stats.minimum)}  '
            '↑ ${formatAxisNumber(stats.maximum)} ${series.unit}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// One tappable metric choice, sitting where the legend used to be.
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.metric,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  final ChartMetric metric;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  /// Overrides the accent when selected, so the chip matches the plotted line.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? faintColor(isDark);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Show ${metric.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              width: 1,
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.10)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : faintColor(isDark),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                metric.unit,
                style: TextStyle(fontSize: 10, color: faintColor(isDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
