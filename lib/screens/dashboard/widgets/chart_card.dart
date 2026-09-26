import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/date_helpers.dart';

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
    required this.rangeStart,
    required this.rangeEnd,
    required this.realtimeConnected,
    required this.onPickRange,
  });

  final String title;
  final bool isDark;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = rangeStart != null && rangeEnd != null
        ? '${rangeStart!.day}/${rangeStart!.month}/${rangeStart!.year}'
              '–${rangeEnd!.day}/${rangeEnd!.month}/${rangeEnd!.year}'
        : 'Last 24 hours';
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
                    color: isDark ? Colors.white54 : Colors.black45,
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
              : (isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(width: 3),
        Text(
          realtimeConnected ? 'Live' : 'Polling',
          style: TextStyle(
            fontSize: 10,
            color: realtimeConnected
                ? Colors.green
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ],
    );
  }
}

/// Glass card plotting Voltage, Current, and Power for one device prefix.
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
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPointerActive,
  });

  final String prefix;
  final bool isDark;
  final bool performanceMode;
  final Map<String, List<TelemetryPoint>> points;
  final Map<String, List<FlSpot>> spots;
  final Map<String, SeriesStats?> stats;
  final Map<String, ChartBounds> boundsCache;
  final bool loading;
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
      height: 400,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      semanticLabel: '$title Voltage, Current, and Power chart showing ${_rangeLabel() ?? 'the last 24 hours'}',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
          ? const Center(child: Text('No historical data available'))
          : Column(
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: series.map(_ChartLegend.new).toList(),
                ),
                const SizedBox(height: 16),
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

  String? _rangeLabel() {
    if (rangeStart == null || rangeEnd == null) return null;
    return '${rangeStart!.day}/${rangeStart!.month}/${rangeStart!.year} '
        'to ${rangeEnd!.day}/${rangeEnd!.month}/${rangeEnd!.year}';
  }

  List<ChartSeries> _buildSeries() {
    Color tint(bool isDark, Color light, Color dark) => isDark ? dark : light;
    return [
      _seriesFor(
        'Voltage',
        'V',
        tint(isDark, const Color(0xFFE53935), const Color(0xFFFF5252)),
      ),
      _seriesFor(
        'Current',
        'A',
        tint(isDark, const Color(0xFF43A047), const Color(0xFF69F0AE)),
      ),
      _seriesFor(
        'Power',
        'W',
        tint(isDark, const Color(0xFF1E88E5), const Color(0xFF448AFF)),
      ),
    ];
  }

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
      fontSize: 8,
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
          reservedSize: 48,
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
  double _edgeShift(TitleMeta meta) {    const halfLabelWidth = 14.0;
    if (meta.axisPosition < halfLabelWidth) return halfLabelWidth;
    if (meta.axisPosition > meta.parentAxisSize - halfLabelWidth) {
      return -halfLabelWidth;
    }
    return 0;
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend(this.series);

  final ChartSeries series;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: series.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('${series.label} (${series.unit})', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

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
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Latest ${formatAxisNumber(stats.latest)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Avg ${formatAxisNumber(stats.average)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Min ${formatAxisNumber(stats.minimum)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Max ${formatAxisNumber(stats.maximum)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
