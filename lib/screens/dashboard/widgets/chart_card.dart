import '../utils/color_helpers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../charts/series_scale.dart';
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
  });

  final String title;
  final bool isDark;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;
  final VoidCallback onPickRange;

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

/// The three quantities a device chart plots together.
///
/// Voltage, current and power are three different units on three completely
/// different scales — on the AC page, power runs to 3500 W while current stays
/// under 16 A and voltage sits near-constant at 220. Drawn on one shared raw
/// axis only the largest is legible, so the chart scales each series against its
/// own range and the axis reads as a percentage. That is the only way three
/// units fit on one plot, and it is why the real numbers are printed under the
/// chart rather than left to the axis.
///
/// The colours are fixed red, green and blue rather than derived from the theme
/// accent. That was tried and reverted: three lightness steps of one hue are too
/// close to tell apart on a phone, and distinguishing them with dash patterns
/// was worse still. Three obviously different colours need no legend decoding,
/// and the chart is the one place in the app where an identity of "voltage is
/// red" is worth more than consistency with the surrounding theme.
class _MetricSpec {
  const _MetricSpec(this.label, this.unit, this.icon, this.light, this.dark);

  final String label;
  final String unit;
  final IconData icon;

  /// The series colour in each mode. Two values rather than a closure, because a
  /// `const` list cannot hold a function call and this table wants to be
  /// `const` so a stray edit shows up as a compile error rather than as a
  /// rebuild.
  final int light;
  final int dark;

  Color color(bool isDark) => Color(isDark ? dark : light);
}

const _metricSpecs = [
  _MetricSpec('Tegangan', 'V', Icons.bolt_outlined, 0xFFE53935, 0xFFFF5252),
  _MetricSpec('Arus', 'A', Icons.electrical_services_outlined, 0xFF43A047,
      0xFF69F0AE),
  _MetricSpec('Daya', 'W', Icons.wb_sunny_outlined, 0xFF1E88E5, 0xFF448AFF),
];

/// A series plus the scaling that lets it share an axis with two others.
class _Scaled {
  const _Scaled(this.series, this.spots, this.base, this.span, this.spec);

  final ChartSeries series;

  /// Downsampled spots, rescaled to 0..1.
  final List<FlSpot> spots;

  /// The real value that a normalised 0 corresponds to.
  final double base;

  /// The real value range that normalised 0..1 covers.
  final double span;

  final _MetricSpec spec;

  /// Back to real units, for the tooltip and the readout.
  double unscale(double normalised) => base + normalised * span;
}

/// Glass card plotting voltage, current and power for one device prefix.
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
  });

  final String prefix;

  /// The theme accent, so the plotted series follows the chosen palette.
  final Color seedColor;
  final bool isDark;
  final bool performanceMode;

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
    final scaled = _buildSeries();
    final bounds = boundsCache.putIfAbsent(
      prefix,
      () => ChartBounds.fromSeries(scaled.map((s) => s.series).toList()),
    );
    final hasData = scaled.any((item) => item.series.points.isNotEmpty);
    final title = prefixTitle(prefix);

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      // A loading spinner or an empty message does not need a full plot's worth of
      // height; reserving it pushed everything below the fold for nothing.
      height: (loading || !hasData) ? 170 : 400,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      semanticLabel: '$title tegangan, arus dan daya '
          '${describeHistoryRange(selectedDate: selectedDate, rangeStart: rangeStart, rangeEnd: rangeEnd)}',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
          ? const Center(child: Text('Tidak ada data untuk rentang ini'))
          : Column(
              children: [
                _SeriesLegend(series: scaled, isDark: isDark),
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
                Row(children: scaled.map((s) => _SeriesStatistics(s)).toList()),
              ],
            ),
    );
  }

  /// All three metrics, each rescaled to its own range so one axis serves all.
  List<_Scaled> _buildSeries() {
    return [
      for (var i = 0; i < _metricSpecs.length; i++)
        _scaleSeries(_metricSpecs[i], i),
    ];
  }

  _Scaled _scaleSeries(_MetricSpec spec, int index) {
    // The history keys are English, while the labels shown to the user are not.
    // Deriving one from the other is what let them drift apart in the first
    // place, so the suffix is written out and the key is composed here.
    const suffixes = ['voltage', 'current', 'power'];
    final key = '${prefix}_${suffixes[index]}';
    final seriesPoints = points[key] ?? const <TelemetryPoint>[];
    final series = ChartSeries(
      spec.label,
      spec.unit,
      seriesPoints,
      spots.putIfAbsent(key, () => processSpots(seriesPoints)),
      spec.color(isDark),
      stats[key] ?? SeriesStats.fromPoints(seriesPoints),
    );

    // Scale from the *downsampled* points rather than the raw series, so the
    // expensive reduction still happens once and only the mapping is repeated.
    // See SeriesScale for why the scale is built from the reduced points.
    final scale = SeriesScale.of(series.spots);
    return _Scaled(
      series,
      scale.apply(series.spots),
      scale.base,
      scale.span,
      spec,
    );
  }

  LineChartData _lineChartData(List<_Scaled> series, ChartBounds bounds) {
    return LineChartData(
      minX: bounds.minX,
      maxX: bounds.maxX,
      // The plot is normalised: 0 is the bottom of a series' own range and 1 its
      // top. Raw min/max from the bounds are deliberately ignored, because they
      // are the range of whichever unit happened to be largest.
      minY: 0,
      maxY: 1,
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
              // Unscale before printing. The y on the spot is a fraction of the
              // series' range, so showing it raw would print 0.42 W.
              for (final spot in touchedSpots)
                '${formatAxisNumber(series[spot.barIndex].unscale(spot.y))} '
                    '${series[spot.barIndex].series.unit}',
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
      lineBarsData: [
        for (final item in series)
          LineChartBarData(
            spots: item.spots,
            isCurved: false,
            color: item.series.color,
            barWidth: 2.5,
            // Solid. Dash patterns were tried so three lightness steps of one
            // hue could be told apart, and they were dropped: three red, green
            // and blue lines need no legend decoding, and a dashed trace on a
            // phone reads as broken rather than as styled.
            dashArray: const [],
            dotData: const FlDotData(show: false),
          ),
      ],
    );
  }

  FlGridData _gridData(ChartBounds bounds) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      // The vertical axis is normalised, so the interval is a fixed half rather
      // than whatever `niceStep` worked out for the raw value range.
      horizontalInterval: 0.5,
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
          reservedSize: 34,
          interval: 0.5,
          // A percentage, not a unit. Each series is scaled to its own range, so
          // the axis is only meaningful as "how far through its own range", and
          // the real value in volts, amperes or watts is in the tooltip and in
          // the readout under the chart.
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            space: 4,
            child: Text(
              '${(value * 100).round()}%',
              style: labelStyle,
            ),
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
                  style: TextStyle(
                    color: series.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Terakhir ${formatAxisNumber(stats.latest)} ${series.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            '↓ ${formatAxisNumber(stats.minimum)}  '
            '↑ ${formatAxisNumber(stats.maximum)} ${series.unit}',
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
  const _SeriesLegend({required this.series, required this.isDark});

  final List<_Scaled> series;
  final bool isDark;

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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: item.series.color,
          ),
        ),
        if (latest != null) ...[
          const SizedBox(width: 5),
          Text(
            '${formatAxisNumber(latest)} ${item.series.unit}',
            style: TextStyle(fontSize: 12, color: faintColor(isDark)),
          ),
        ],
      ],
    );
  }
}
