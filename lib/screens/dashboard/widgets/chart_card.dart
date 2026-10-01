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
///
/// This used to fall through to `'Battery'` for anything it did not recognise,
/// which is a quiet way to be wrong: the greenhouse prefix would have titled its
/// chart "Battery" and nobody would have known why until someone opened that
/// page. The names live with the charts now.
String prefixTitle(String prefix) => chartPageTitle(prefix) ?? prefix;

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
    required this.seedColor,
    this.refreshing = false,
  });

  final String title;

  /// Still a `bool`, and deliberately.
  ///
  /// Everything this header paints is text or an accent at a hand-picked HSL
  /// lightness: `appPrimaryText`, `faintColor` and `themeColor(lightness:)`.
  /// The first two are shared by the two dark presets and take a brightness; the
  /// third has no `AppTheme` overload, so a bool is the honest parameter here
  /// and the Dracula call site supplies `theme.isDark`.
  ///
  /// **This is also where a known Dracula weakness lives, deliberately not fixed
  /// in a signature migration.** The three accent call sites below all ask for
  /// `themeColor(lightness: 0.68)`, which on Dracula's preset purple reads
  /// `#A47BE0` — measured 4.40:1 on the page and 3.64:1 on chrome, against
  /// AA's 4.5 for the 10–11sp text they paint. That is why `metricColor` needed
  /// a per-theme lightness (`#C1A3EB`, 6.58 and 5.45). The repair is to route
  /// them through `metricColor(theme:)`, which changes three colours and so
  /// belongs in a change with its own measurement. `live_power_card.dart` has
  /// the same three numbers and the same note.
  final bool isDark;

  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;
  final VoidCallback onPickRange;

  /// The theme accent, so the "Live" indicator is not a status green.
  final Color seedColor;

  /// True while a request for this view's data is in flight.
  final bool refreshing;

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
                    // `appPrimaryText`, not `faintColor`: this is the section
                    // heading, and the range label beside it already carries the
                    // secondary tone. It was `Colors.white70` / `Colors.black54`,
                    // which is the pair `color_helpers.dart` replaced because it
                    // measures about 3.4:1 — and 14sp is below the 18.66px
                    // large-text floor, so AA 4.5:1 is what applies here, not 3:1.
                    color: appPrimaryText(isDark),
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
        // The calendar button is gone, and so is the only route to a custom
        // date range. It was the one place `showDateRangePicker` was reachable;
        // the date strip on Overview can only pick a single day. The range the
        // user is looking at is still named in the label beside the title, so
        // nothing becomes ambiguous -- it just cannot be changed from here.
        //
        // It was also a control that had been through three sizes: it was 32dp
        // with `visualDensity: compact` stacked on an explicit tighter
        // constraint, then it was raised to the 48dp Material floor, and now
        // there is nothing to hit. Six of these were about to exist across the
        // greenhouse and fish pages alone, which is most of the reason to
        // remove it rather than keep shrinking it.
        //
        // Says "Updating" only while a request for this view is actually in
        // flight, and nothing at all otherwise.
        //
        // It is here because of what its absence looked like. Switching between
        // PV, AC and Battery refetches, and the chart deliberately keeps showing
        // the previous numbers rather than blanking — which is right, and was
        // completely silent. On a slow ThingsBoard that is a second or two of a
        // card that looks frozen, and "frozen" reads as broken in a way that
        // "updating" does not. Silence is only good news when nothing is wrong;
        // here something was happening and the screen was saying otherwise.
        if (refreshing) ...[
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: themeColor(
                seedColor: seedColor,
                lightness: isDark ? 0.68 : 0.38,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Updating',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: faintColor(isDark),
            ),
          ),
        ],
        // A live connection takes the accent, not green. Green here was a status
        // colour used for a condition that is normally fine, which is the same
        // thing the dashboard's other "everything is OK" greens were doing.
        Icon(
          realtimeConnected ? Icons.wifi : Icons.wifi_off,
          size: 13,
          color: realtimeConnected
              ? themeColor(seedColor: seedColor, lightness: isDark ? 0.68 : 0.38)
              : (faintColor(isDark)),
        ),
        const SizedBox(width: 3),
        Text(
          realtimeConnected ? 'Live' : 'Polling',
          style: TextStyle(
            fontSize: 10,
            color: realtimeConnected
                ? themeColor(
                    seedColor: seedColor,
                    lightness: isDark ? 0.68 : 0.38,
                  )
                : (faintColor(isDark)),
          ),
        ),
      ],
    );
  }
}

/// The three quantities a device chart plots together, on one dynamic Y axis.
///
/// The axis carries real values, not a percentage. Rescaling each series against
/// its own range so all three would fill the plot height was tried, and reverted
/// at the user's request: a reader who sees "0%, 50%, 100%" has to look up three
/// different scales in the legend to learn anything, whereas a real axis can be
/// read directly. It also makes the common case worse. On the PV and battery
/// pages the three quantities are within an order of magnitude of each other, so
/// the raw axis is already perfectly readable; only the AC page has power two
/// orders above current, and a flat trace there is honest rather than broken.
///
/// The colours are fixed red, green and blue rather than derived from the theme
/// accent. That was tried and reverted: three lightness steps of one hue are too
/// close to tell apart on a phone, and distinguishing them with dash patterns was
/// worse still. Three obviously different colours need no legend decoding, and
/// the chart is the one place in the app where an identity of "voltage is red" is
/// worth more than consistency with the surrounding theme.
class _MetricSpec {
  const _MetricSpec(this.series, this.icon);

  /// The declared series: the telemetry key, the label, the unit, and either the
  /// fixed triad colour or null for "use the user's accent".
  final ChartSeriesSpec series;

  final IconData icon;

  String get label => series.label;

  String get unit => series.unit;

  Color color(bool isDark, Color accent) => series.color(isDark, accent);
}

/// The icon a declared series is drawn with in the legend.
///
/// Kept here rather than on [ChartSeriesSpec] because it is presentation for the
/// one chart widget, while the spec is shared with the request builder and
/// should not need to import Material to say "this is a pH reading".
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
///
/// The [points], [spots], [stats] and [boundsCache] maps are owned by the
/// caller so that downsampling and bounds stay memoized across rebuilds.
class TelemetryChartCard extends StatelessWidget {
  const TelemetryChartCard({
    super.key,
    required this.prefix,
    required this.group,
    required this.theme,
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

  /// What this card plots. One group per card, because two series on one card
  /// only make sense when they share a unit — which is why the greenhouse gets
  /// four cards and the electrical pages get one.
  final ChartGroup group;

  /// The theme accent, so the plotted series follows the chosen palette.
  final Color seedColor;

  /// The appearance to paint, as an `AppTheme`.
  ///
  /// This card is the strongest case in the directory for the enum over a
  /// bool: it draws a full `AppCard` (raised pair, hairline, page fill), a
  /// single-series accent through `metricColor`, grid and axis rules through
  /// `appDivider`, and the tooltip fill through `AppSurfaces.tooltip` — four
  /// independently derived per-theme tokens, any of which a boolean would put on
  /// the dark values while the plot sits on Dracula's page.
  ///
  /// The text on the card — the axis labels, the legend's live value, the
  /// tooltip's caption — passes `theme.isDark`, because those colours are shared
  /// by the two dark presets and are measured clear of AA on `#282A36` unchanged.
  final AppTheme theme;

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
    final specs = _specsFor(group);
    final accent = metricColor(
      seedColor: seedColor,
      index: 0,
      theme: theme,
    );
    final scaled = _buildSeries(specs, accent);
    // The cache key has to name the group, not just the page. A page that draws
    // four cards -- the greenhouse -- would otherwise have every card share the
    // first card's bounds, and a lux axis from 0 to 190,000 would be applied to
    // a humidity axis from 0 to 90.
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
      theme: theme,
      // A loading spinner or an empty message does not need a full plot's worth of
      // height; reserving it pushed everything below the fold for nothing.
      //
      // The full-plot height is the default and the greenhouse and fish tank ask
      // for less, which is a property of what those pages chart and therefore
      // travels with the group declaration rather than being decided here.
      height: (loading || !hasData)
          ? 170
          : (group.height ?? 400),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      // The label used to read "$title voltage, current and power", hard-coded,
      // so a pH chart announced itself as a power chart. It now names the
      // series it actually draws, which is the only version of this string that
      // a screen reader can say out loud.
      semanticLabel: '$title, ${scaled.map((s) => s.spec.label).join(', ')}. '
          '${describeHistoryRange(selectedDate: selectedDate, rangeStart: rangeStart, rangeEnd: rangeEnd)}',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
          ? const Center(child: Text('No data for this range'))
          : Column(
              children: [
                _SeriesLegend(series: scaled, isDark: theme.isDark, accent: accent),
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
                // A gap between the columns, and a little air above them.
                //
                // These sat edge to edge with no separation, so on the
                // greenhouse temperature chart "min 22.73 °C" ran straight into
                // the "Panel" column and the two readings read as one line of
                // text. A 1px rule would have been a third thing to look at
                // between the plot and the numbers; whitespace is enough.
                const SizedBox(height: 10),
                // One figure per line, but only when there is more than one
                // series to keep apart.
                //
                // Three stacked lines per series exists to stop two series'
                // readings running together, and that problem is a consequence
                // of splitting the card's width between them. A single-series
                // card has the whole width, so the same three lines are just
                // three lines of vertical space describing one quantity -- and
                // on the greenhouse and fish pages that is most of the cards,
                // since four of the seven groups have one series each.
                //
                // Measured: at a third of the width "min 6.98 V  max 21.43 V"
                // ellipsised to "109...." on a three-series card, which is the
                // one number a reader cannot afford to lose. At full width it
                // fits with room, so the layout that was forced by the
                // multi-series case is simply dropped when it does not apply.
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
    // The key comes from the declaration, not from composing a prefix and an
    // index. `const suffixes = ['voltage', 'current', 'power']` indexed by
    // position was correct for exactly three pages and wrong for every other
    // one, and nothing about it said so.
    final key = spec.series.key;
    final seriesPoints = points[key] ?? const <TelemetryPoint>[];
    return _Scaled(
      ChartSeries(
        spec.label,
        spec.unit,
        seriesPoints,
        spots.putIfAbsent(key, () => processSpots(seriesPoints)),
        // The fixed triad is keyed on brightness, not on the theme: a single-series
        // group has `light` and `dark` both null and falls back to the accent,
        // and a multi-series one takes its documented red/green/blue. Dracula
        // takes the dark entry, which is the same rule `ChartSeriesSpec.color`
        // already encodes.
        spec.color(theme.isDark, accent),
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
          // `AppRadius.tile`, and deliberately not the card's 16. The tooltip
          // floats above the plot rather than sitting in the card's plane, so it
          // keeps the tighter radius and does not inherit the card's scale.
          tooltipRoundedRadius: AppRadius.tile,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          tooltipMargin: 12,
          maxContentWidth: 150,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipBorder: BorderSide(
            // `appDivider` at 0.24, which is the strength this border had as
            // `white @ 0.24`. The token's 0.10 default is right for a rule
            // between two rows of a card and too faint for the outline of a
            // floating box that has to separate from an arbitrary series
            // crossing underneath it.
            color: appDivider(theme: theme, opacity: 0.24),
            width: 1,
          ),
          // Opaque. It was `0xCC18211D` and `0xD9FFFFFF`, so the tooltip was
          // showing whichever line happened to pass beneath it through 20% of
          // its own surface — over a red/green/blue crossing, at 11sp.
          getTooltipColor: (_) => AppSurfaces.tooltip(theme),
          getTooltipItems: (touchedSpots) {
            if (touchedSpots.isEmpty) return const [];
            final time = formatAxisTime(touchedSpots.first.x);
            final values = <String>[
              for (final spot in touchedSpots)
                '${formatAxisNumber(spot.y)} '
                    '${series[spot.barIndex].series.unit}',
            ];
            final tooltip = LineTooltipItem(
              '$time\n${values.join('  ·  ')}',
              TextStyle(
                // `appPrimaryText`, replacing `white` and a fourth grey. The
                // light value was `0xFF17211C`, which was a copy of the card's
                // text colour made for this one box and pinned nowhere.
                //
                // `theme.isDark`, not `isDark`: `appPrimaryText` is one of the
                // text colours the two dark presets share, and the tooltip is
                // also the one place in this widget that must paint a Dracula
                // caption on Dracula's own tooltip step.
                color: appPrimaryText(theme.isDark),
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
            spots: item.series.spots,
            isCurved: false,
            barWidth: 2.5,
            // Slightly transparent so a trace that sits on top of another is
            // still visible underneath. Current and power are proportional, so
            // on most devices their lines coincide exactly and the one drawn
            // last would otherwise hide the other completely.
            color: item.series.color.withValues(alpha: 0.85),
            // No dashArray. Dash patterns were tried so three lightness steps of
            // one hue could be told apart, and they were dropped: three red, green
            // and blue lines need no legend decoding, and a dashed trace on a
            // phone reads as broken rather than as styled.
            //
            // Leaving the field unset is what draws a solid line. Passing an
            // empty list does not: fl_chart walks the pattern by
            // `pattern[index % pattern.length]`, so a zero-length list renders
            // nothing at all. The chart came up with an empty plot, correct axes,
            // correct legend and correct statistics, which is the worst kind of
            // failure to spot on a device.
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
        // The two opacities are keyed on brightness alone, unchanged: 0.15
        // horizontal and 0.10 vertical on both dark presets. `appDivider` itself
        // takes the theme because Dracula's white is its own decision.
        color: appDivider(theme: theme, opacity: theme.isDark ? 0.15 : 0.08),
        strokeWidth: 1,
      ),
      getDrawingVerticalLine: (_) => FlLine(
        color: appDivider(theme: theme, opacity: theme.isDark ? 0.10 : 0.06),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _titlesData(ChartBounds bounds) {
    final labelStyle = TextStyle(
      fontSize: 10,
      // `faintColor`, for every mode. The light value was `0xFF64748B`, a
      // Tailwind slate that measures 4.30:1 on the light page — under the 4.5:1
      // that `test/color_helpers_test.dart` requires at this size, and a
      // non-pinned literal is exactly how that suite gets bypassed. The dark
      // value measured 7.5:1 and was already fine, so it is folded into the same
      // function rather than left as a hand-picked hex next to a failing one.
      //
      // The axis is 10sp, the smallest text in the app, and it sits on the plot
      // fill — which is the page colour, and on Dracula a *lighter* one than the
      // dark theme's. The dark faint value still measures 6.58:1 there, so no
      // Dracula variant is warranted; see [AppTheme.isDark].
      color: faintColor(theme.isDark),
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
          reservedSize: 40,
          interval: bounds.chartInterval,
          // Real values, chosen by `niceStep` from the data's own range. The
          // interval is not a percentage of anything: a reader can take a value
          // off this axis and use it.
          //
          // The topmost label hangs *below* its own line rather than being
          // centred on it. Centred, the upper half of it sits outside the plot
          // and the card's padding cuts it in half -- which is exactly what
          // "40000" looked like on the greenhouse Light chart, sliced through
          // the middle by the app bar. The same defect was fixed on the energy
          // report's axis first and this one was left, which is how two charts
          // in one app can disagree about whether their top label is readable.
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
            // A tick sitting exactly on the plot edge would be half clipped, so
            // nudge the first and last labels back inside the chart.
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
/// The statistics of a card that charts exactly one series, on one line.
///
/// The unit is printed once, at the end, rather than three times. Repeating it
/// per figure is what forced the multi-line layout in the first place: "Last
/// 7.42 °C / min 6.37 °C / max 7.75 °C" is three copies of the same suffix
/// saying the same thing, and dropping them is what makes one line enough.
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
        '  ·  min ${formatAxisNumber(stats.minimum)}'
        '  ·  max ${formatAxisNumber(stats.maximum)}$suffix';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // **`Flexible`, without which the two lines below are decorative.**
        //
        // A non-flex child in a `Row` is laid out at its intrinsic width: it gets
        // unbounded main-axis constraints, so `maxLines: 1` and
        // `TextOverflow.ellipsis` can never take effect. The `Flexible` sibling
        // then receives whatever is left, which is zero the moment the label is
        // wide. Today's labels are short -- "Voltage", "Turbidity" -- so this is
        // latent rather than visible, and latent is exactly how it survives.
        //
        // It matters because this is the same widget that already refuses to
        // truncate a number for the sake of a label. The `FittedBox` on the right
        // exists because "max 300..." is worse than a smaller figure; a label
        // that can push the numbers to nothing reintroduces that failure from
        // the other side. The label gives way first because a series name is
        // shorter and less informative than its own figures.
        Flexible(
          flex: 2,
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
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          // Scale down rather than ellipsise.
          //
          // Turbidity is the case that decides it: "Last 2786.34 · min 2395.53 ·
          // max 3001.42 NTU" is 44 characters, and ellipsising it on the device
          // produced "max 300..." -- which is the same failure the three-line
          // layout was built to avoid, reintroduced by flattening it. The
          // original reason for stacking the figures was that losing one is worse
          // than using another line, and that is still true; `scaleDown` gives
          // the number back by making the text smaller instead, and 11sp has
          // room to shrink before it stops being readable.
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
                  style: TextStyle(
                    color: series.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
          // One figure per line. "min 6.98 V  maks 21.43 V" on a single line
          // overflowed a third of the width and ellipsised to "109....", which
          // is the one number a reader cannot afford to lose.
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
    required this.isDark,
    required this.accent,
  });

  final List<_Scaled> series;
  final bool isDark;

  /// The user's accent, for a group whose single series has no fixed colour.
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
