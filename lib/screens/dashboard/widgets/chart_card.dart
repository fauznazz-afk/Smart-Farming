import '../utils/color_helpers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import 'chart_groups.dart';
import '../utils/date_helpers.dart';
import '../utils/design_tokens.dart';
import '../utils/history_range.dart';

/// Human readable name for a dashboard page prefix.
String prefixTitle(String prefix) => chartPageTitle(prefix) ?? prefix;

/// Title + range label + live/polling indicator above a telemetry chart.
class ChartSectionHeader extends StatelessWidget {
  const ChartSectionHeader({
    super.key,
    required this.title,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.realtimeConnected,
    required this.onPickRange,
    required this.seedColor,
    this.refreshing = false,
  });

  final String title;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;
  final VoidCallback onPickRange;
  final Color seedColor;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = describeHistoryRange(
      selectedDate: selectedDate,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    final accent = categoryColorForKey('power_dc') ?? AppPalette.primary;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelUppercase.copyWith(color: appPrimaryText),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rangeLabel,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelMicro.copyWith(color: faintColor),
                ),
              ),
            ],
          ),
        ),
        if (refreshing) ...[
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Updating',
            style: AppType.labelMicro.copyWith(color: faintColor),
          ),
        ],
        Icon(
          realtimeConnected ? Icons.wifi : Icons.wifi_off,
          size: 13,
          color: realtimeConnected ? accent : faintColor,
        ),
        const SizedBox(width: 3),
        Text(
          realtimeConnected ? 'Live' : 'Polling',
          style: AppType.labelMicro.copyWith(
            color: realtimeConnected ? accent : faintColor,
          ),
        ),
      ],
    );
  }
}

/// The three quantities a device chart plots together, on one dynamic Y axis.
class _MetricSpec {
  const _MetricSpec(this.series, this.icon);

  final ChartSeriesSpec series;
  final IconData icon;

  String get label => series.label;
  String get unit => series.unit;

  Color color(bool isDark, Color accent) => series.color(isDark, accent);
}

IconData _iconForSeries(ChartSeriesSpec spec) => switch (spec.key) {
  'voltage_dc' || 'voltage_ac' || 'voltage' => Icons.bolt_outlined,
  'current_dc' || 'current_ac' || 'current' =>
    Icons.electrical_services_outlined,
  'power_dc' || 'power_ac' || 'power' => Icons.wb_sunny_outlined,
  'temp_dht' => Icons.device_thermostat,
  'temp_ds18b20' => Icons.thermostat,
  'humidity_dht' => Icons.water_drop,
  'lux' => Icons.light_mode,
  'tds_ppm' => Icons.science,
  'ph' => Icons.science_outlined,
  'suhu' => Icons.thermostat,
  'turbidity_ntu' => Icons.blur_on,
  _ => Icons.show_chart,
};

List<_MetricSpec> _specsFor(ChartGroup group) => [
  for (final series in group.series)
    _MetricSpec(series, _iconForSeries(series)),
];

/// A series paired with the spec that named and coloured it.
class _Scaled {
  const _Scaled(this.series, this.spec);

  final ChartSeries series;
  final _MetricSpec spec;
}

/// Glass card plotting voltage, current and power for one device prefix.
class TelemetryChartCard extends StatelessWidget {
  const TelemetryChartCard({
    super.key,
    required this.prefix,
    required this.group,
    required this.points,
    required this.spots,
    required this.stats,
    required this.boundsCache,
    required this.loading,
    required this.loadFailed,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPointerActive,
    required this.seedColor,
  });

  final String prefix;
  final ChartGroup group;
  final Color seedColor;
  final Map<String, List<TelemetryPoint>> points;
  final Map<String, List<FlSpot>> spots;
  final Map<String, SeriesStats?> stats;
  final Map<String, ChartBounds> boundsCache;
  final bool loading;
  final bool loadFailed;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<bool> onPointerActive;

  @override
  Widget build(BuildContext context) {
    final specs = _specsFor(group);
    final accent = categoryColorForKey(specs.first.series.key) ?? AppPalette.primary;
    final scaled = _buildSeries(specs, accent);
    final bounds = boundsCache.putIfAbsent(
      '$prefix/${group.title}',
      () => ChartBounds.fromSeries(
        scaled.map((s) => s.series).toList(),
        zeroAnchored: group.zeroAnchored,
      ),
    );
    final hasData = scaled.any((item) => item.series.points.isNotEmpty);
    final title = group.title;

    return AppCard(
      height: (loading || !hasData)
          ? 170
          : (group.height ?? 400),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      semanticLabel: '$title, ${scaled.map((s) => s.spec.label).join(', ')}. '
          '${describeHistoryRange(selectedDate: selectedDate, rangeStart: rangeStart, rangeEnd: rangeEnd)}',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
          ? Center(
              child: Text(
                loadFailed
                    ? 'Could not load this range'
                    : 'No data for this range',
                style: AppType.bodyMd.copyWith(color: faintColor),
              ),
            )
          : Column(
              children: [
                _SeriesLegend(series: scaled, accent: accent),
                const SizedBox(height: 10),
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => onPointerActive(true),
                    onPointerUp: (_) => onPointerActive(false),
                    onPointerCancel: (_) => onPointerActive(false),
                    child: RepaintBoundary(
                      child: LineChart(
                        _lineChartData(scaled, bounds),
                        duration: Duration.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                if (scaled.length == 1)
                  _SingleSeriesStatistics(scaled.first)
                else
                  Row(
                    children: [
                      for (var i = 0; i < scaled.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        _SeriesStatistics(scaled[i]),
                      ],
                    ],
                  ),
              ],
            ),
    );
  }

  List<_Scaled> _buildSeries(List<_MetricSpec> specs, Color accent) {
    return [for (final spec in specs) _seriesFor(spec, accent)];
  }

  _Scaled _seriesFor(_MetricSpec spec, Color accent) {
    final key = spec.series.key;
    final seriesPoints = points[key] ?? const <TelemetryPoint>[];
    return _Scaled(
      ChartSeries(
        spec.label,
        spec.unit,
        seriesPoints,
        spots.putIfAbsent(key, () => processSpots(seriesPoints)),
        spec.color(false, accent),
        stats[key] ?? SeriesStats.fromPoints(seriesPoints),
      ),
      spec,
    );
  }

  LineChartData _lineChartData(List<_Scaled> series, ChartBounds bounds) {
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
          tooltipRoundedRadius: AppRadius.tile,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          tooltipMargin: 12,
          maxContentWidth: 150,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipBorder: BorderSide(
            color: AppSurfaces.border.withValues(alpha: 0.24),
            width: 1,
          ),
          getTooltipColor: (_) => AppSurfaces.tooltip,
          getTooltipItems: (touchedSpots) {
            if (touchedSpots.isEmpty) return const [];
            final time = formatAxisTime(touchedSpots.first.x);
            final values = <String>[
              for (final spot in touchedSpots)
                '${formatAxisNumber(spot.y)} '
                    '${series[spot.barIndex].series.unit}',
            ];
            final tooltip = LineTooltipItem(
              '$time\n${values.join('  \u00b7  ')}',
              AppType.bodyMd.copyWith(color: appPrimaryText, fontWeight: FontWeight.w700),
            );
            return List<LineTooltipItem?>.generate(
              touchedSpots.length,
              (index) => index == 0 ? tooltip : null,
            );
          },
        ),
      ),
      lineBarsData: [
        for (final item in series)
          LineChartBarData(
            spots: item.series.spots,
            isCurved: false,
            barWidth: 2.5,
            color: item.series.color.withValues(alpha: 0.85),
            dotData: const FlDotData(show: false),
          ),
      ],
    );
  }

  FlGridData _gridData(ChartBounds bounds) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      horizontalInterval: bounds.chartInterval,
      verticalInterval: bounds.timeInterval,
      getDrawingHorizontalLine: (_) => FlLine(
        color: AppSurfaces.border.withValues(alpha: 0.15),
        strokeWidth: 1,
      ),
      getDrawingVerticalLine: (_) => FlLine(
        color: AppSurfaces.border.withValues(alpha: 0.10),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _titlesData(ChartBounds bounds) {
    final labelStyle = AppType.labelMicro.copyWith(color: faintColor);
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
          reservedSize: 40,
          interval: bounds.chartInterval,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide:
                value >= bounds.maxY - bounds.chartInterval / 2
                ? AxisSide.top
                : meta.axisSide,
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
            child: Transform.translate(
              offset: Offset(_edgeShift(meta), 0),
              child: Text(
                formatAxisTick(
                  value,
                  spansMultipleDays: bounds.spansMultipleDays,
                  tickIntervalMs: bounds.timeInterval,
                ),
                style: labelStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _edgeShift(TitleMeta meta) {
    const halfLabelWidth = 16.0;
    if (meta.axisPosition < halfLabelWidth) return halfLabelWidth;
    if (meta.axisPosition > meta.parentAxisSize - halfLabelWidth) {
      return -halfLabelWidth;
    }
    return 0;
  }
}

/// The statistics of a card that charts exactly one series, on one line.
class _SingleSeriesStatistics extends StatelessWidget {
  const _SingleSeriesStatistics(this.scaled);

  final _Scaled scaled;

  @override
  Widget build(BuildContext context) {
    final series = scaled.series;
    final stats = series.stats;
    if (stats == null) return const SizedBox.shrink();

    final unit = series.unit.trim();
    final suffix = unit.isEmpty ? '' : ' $unit';
    final text =
        'Last ${formatAxisNumber(stats.latest)}'
        '  \u00b7  min ${formatAxisNumber(stats.minimum)}'
        '  \u00b7  max ${formatAxisNumber(stats.maximum)}$suffix';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            series.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelUppercase.copyWith(
              color: series.color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesStatistics extends StatelessWidget {
  const _SeriesStatistics(this.scaled);

  final _Scaled scaled;

  @override
  Widget build(BuildContext context) {
    final series = scaled.series;
    final stats = series.stats;
    if (stats == null) return const Expanded(child: SizedBox.shrink());
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  series.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelUppercase.copyWith(
                    color: series.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last ${formatAxisNumber(stats.latest)} ${series.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            'min ${formatAxisNumber(stats.minimum)} ${series.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            'max ${formatAxisNumber(stats.maximum)} ${series.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// One row per series: swatch, name, and the live value in its own unit.
class _SeriesLegend extends StatelessWidget {
  const _SeriesLegend({
    required this.series,
    required this.accent,
  });

  final List<_Scaled> series;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final item in series) _entry(item),
      ],
    );
  }

  Widget _entry(_Scaled item) {
    final latest = item.series.stats?.latest;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.spec.icon, size: 13, color: item.series.color),
        const SizedBox(width: 3),
        Text(
          item.series.label,
          style: AppType.labelUppercase.copyWith(color: item.series.color),
        ),
        if (latest != null) ...[
          const SizedBox(width: 5),
          Text(
            '${formatAxisNumber(latest)} ${item.series.unit}',
            style: AppType.labelMicro.copyWith(color: faintColor),
          ),
        ],
      ],
    );
  }
}