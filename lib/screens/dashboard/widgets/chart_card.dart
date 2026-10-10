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
    this.refreshing = false,
  });

  final String title;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;
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
            child: CircularProgressIndicator(strokeWidth: 1.6, color: accent),
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

  Color color() => categoryColorForKey(series.key) ?? AppPalette.primary;
}

IconData _iconForSeries(ChartSeriesSpec spec) => switch (spec.key) {
  'voltage_dc' || 'voltage_ac' || 'voltage' => Icons.bolt_outlined,
  'current_dc' ||
  'current_ac' ||
  'current' => Icons.electrical_services_outlined,
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
  });

  final String prefix;
  final ChartGroup group;
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
    final scaled = _buildSeries(specs);
    final bounds = boundsCache.putIfAbsent(
      '$prefix/${group.title}',
      () => ChartBounds.fromSeries(
        scaled.map((s) => s.series).toList(),
        zeroAnchored: group.zeroAnchored,
      ),
    );
    final hasData = scaled.any((item) => item.series.points.isNotEmpty);
    final title = group.title;

    // Through `AppCard.semanticLabel` rather than a `Semantics` wrapper, and the
    // difference is `excludeSemantics`. A hand-written wrapper here used
    // `explicitChildNodes: true`, which is a *different* claim: it marks the
    // node's children as the explicit ones, but does not stop a screen reader
    // from also walking them, so the summary sentence was read and then every
    // `Text` under it was read again. `AppCard` pairs the caller's summary with
    // `excludeSemantics: true`, which is the behaviour the summary exists for.
    return AppCard(
      height: (loading || !hasData) ? 170 : (group.height ?? 400),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      semanticLabel:
          '$title, ${scaled.map((s) => s.spec.label).join(', ')}. '
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
                _SeriesLegend(series: scaled),
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

  List<_Scaled> _buildSeries(List<_MetricSpec> specs) {
    // One series takes its category hue; more than one cannot, because the PV,
    // AC, battery and greenhouse-temperature groups each plot several series
    // that all belong to *one* category. See [kChartSeriesOrder].
    final multi = specs.length > 1;
    return [
      for (var i = 0; i < specs.length; i++)
        _seriesFor(
          specs[i],
          multi ? kChartSeriesOrder[i % kChartSeriesOrder.length] : null,
        ),
    ];
  }

  // **No `accent` parameter.** It used to be threaded from `build` through here
  // and into `_SeriesLegend`, and read by nobody: every series resolved its hue
  // from `categoryColorForKey` one line below, and the legend did the same. The
  // parameter was verified unused before removal rather than removed on a
  // hunch — this repo has already had a `_history` field deleted on a
  /// well-argued and wrong dead-code claim. [override] replaces it, and unlike
  /// it, it is read: a multi-series group's colour comes from the fixed order
  /// rather than from the category.
  _Scaled _seriesFor(_MetricSpec spec, Color? override) {
    final key = spec.series.key;
    final seriesPoints = points[key] ?? const <TelemetryPoint>[];
    return _Scaled(
      ChartSeries(
        spec.label,
        spec.unit,
        seriesPoints,
        spots.putIfAbsent(key, () => processSpots(seriesPoints)),
        override ?? spec.color(),
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
        // **The tooltip is opaque, on the brief's own tokens.**
        //
        // `AppSurfaces.tooltip` rather than a translucent fill: a tooltip sits
        // over an arbitrary run of the series, and over a crossing it covers
        // both of them. Anything you can see through it is a number you cannot
        // read. `AppRadius.tile` for the corners, and a 1px edge in
        // `AppSurfaces.border` at 24% — enough to separate the fill from the
        // card behind it without drawing a second outline.
        //
        // `fitInsideHorizontally` and `fitInsideVertically` are load-bearing and
        // not padding: they are what stop a tooltip at the far right of the plot
        // from being painted off the edge of the card.
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: AppRadius.tile,
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
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
              AppType.bodyMd.copyWith(
                color: appPrimaryText,
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
            spots: item.series.spots,
            isCurved: false,
            barWidth: 2.5,
            // **The category hue, and 0.85 is about crossings, not shade.**
            //
            // The battery page plots current and power on one axis and both go
            // negative while the pack discharges, so two lines cross each other
            // repeatedly. Full opacity would make the later-drawn line erase the
            // earlier one at every crossing and the reader would lose a series
            // without any indication that it had gone. This is *not* a lightness
            // ramp and must never become one: the hue itself comes from
            // `categoryColorForKey` and the alpha is 0.85 for every series
            // equally, so two series in different categories still read as two
            // categories and two in the same category still read as one.
            color: item.series.color.withValues(alpha: 0.85),
            dotData: const FlDotData(show: false),
          ),
      ],
    );
  }

  // **Hairlines, and no gradient and no glow — the brief's grid, in full.**
  //
  // `AppSurfaces.border` at 15% on the horizontal lines and 10% on the vertical
  // ones, both `strokeWidth: 1`. The vertical pair is the weaker of the two on
  // purpose: a vertical rule on a time axis is a fence, while a horizontal rule
  // is a scale you read against, and the two do not have to be equally loud for
  // the reader to get the same amount out of each.
  //
  // fl_chart's own default is a grey line with no alpha at all, which is how the
  // energy report's grid still gets its colour — see
  // `energy_report/utils/chart_helpers.dart`.
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
    final labelStyle = AppType.labelMicro.copyWith(
      color: AppSurfaces.onSurfaceVariant,
    );
    return FlTitlesData(
      // `showTitles: false` with **no `reservedSize`**. A `reservedSize: 44`
      // sat here once and did nothing at all: `AxisTitles.totalReservedSize`
      // only adds `sideTitles.reservedSize` when `showSideTitles` is true, and
      // that getter requires `sideTitles.showTitles`. So a reserved size on a
      // hidden side is read by nobody, and it genuinely does not buy room for
      // the top label. That comment was checked against fl_chart 0.68 before
      // being kept: it is still true. See the note on `leftTitles` for what does
      // work instead.
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: bounds.chartInterval,
          getTitlesWidget: (value, meta) {
            // **The top label is pulled *inside* the plot by `fitInside`, and
            // measured this is the only option that survives a text scale.**
            //
            // The old code switched the maximum-value label to `AxisSide.top`,
            // which reads like it moves that label above the gridline so it
            // cannot be clipped. It does the opposite of what it reads like:
            // `SideTitlesFlex` centres every child on its own gridline (the
            // offset is `axisPixelLocation - size / 2`), and the `Container`
            // inside `SideTitleWidget` shrink-wraps to its child with no size
            // factor, so the widget's own `alignment` and `margin` cancel out
            // vertically and the child ends up centred whatever side is asked
            // for. All `AxisSide.top` actually changes is *which* side the
            // `space` margin goes on, and a bottom margin under a
            // shrink-wrapped box lifts the label by `space / 2` -- three pixels
            // the wrong way. It also re-centres the text in the 40dp reserved
            // column instead of right-aligning it with the other Y labels.
            //
            // Measured on the unmodified build at 381dp (`test/zz_probe_test`,
            // deleted), against the `LineChart`'s own painted rect:
            //
            // | scale | label hangs above the chart | overlaps the legend |
            // |---|---|---|
            // | 1.0  | 8dp  | none (2dp clear) |
            // | 2.0  | 26dp | 16dp |
            // | 3.0  | 38dp | 28dp |
            //
            // And the same measurement after this change, same probe:
            //
            // | scale | label top vs chart top | label top vs legend bottom |
            // |---|---|---|
            // | 1.0  | +4dp inside | +14dp clear |
            // | 2.0  | +4dp inside | +14dp clear |
            // | 3.0  | +4dp inside | +14dp clear |
            //
            // The chart's own height is byte-identical before and after at
            // every scale (178 / 148 / 116 dp for a 260dp card), so the plot
            // gives up nothing. What moves is the label: it now sits inside the
            // plot instead of taking a strip off the top of it.
            //
            // Two alternatives were measured and rejected:
            //
            //  * **Reserve real space.** A `topTitles` reservation does reach
            //    the plot through `FlTitlesData.allSidesPadding`, but it needs
            //    `showTitles: true` on that side to do anything, and `reservedSize`
            //    is not text-scaled -- the 10dp that fits at scale 1 is 22dp
            //    short at scale 3. A fixed reservation is wrong at every scale
            //    but one, and every chart would pay it.
            //  * **Clamp it by hand.** A `Transform.translate` of half the label
            //    height works, but deriving that height from
            //    `fontSize * height * textScaler` is an arithmetic claim about
            //    text metrics rather than a measured one.
            //
            // `fitInside` is fl_chart's own answer to this and it measures the
            // label in a post-frame callback, so it is correct at any scale and
            // the plot loses no height at all -- the label goes *into* the plot
            // rather than taking a strip off it. It stays on
            // `meta.axisSide`, so the top label is right-aligned with the rest.
            //
            // One cost, stated honestly: the child is measured after the first
            // frame, so the very first paint of a card still shows it centred on
            // the top gridline. Nothing re-triggers it afterwards -- the cached
            // height is only read once and a label's height does not change when
            // its number does.
            final isMax = value >= bounds.maxY - bounds.chartInterval / 2;
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              fitInside: SideTitleFitInsideData.fromTitleMeta(
                meta,
                enabled: isMax,
                // A hair inside the painted edge rather than flush with it, so
                // a rounding pixel cannot put half a label back outside.
                distanceFromEdge: AppSpacing.xs,
              ),
              child: Text(formatAxisNumber(value), style: labelStyle),
            );
          },
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
            style: AppType.labelUppercase.copyWith(color: series.color),
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
                  style: AppType.labelUppercase.copyWith(color: series.color),
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
  const _SeriesLegend({required this.series});

  final List<_Scaled> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [for (final item in series) _entry(item)],
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
