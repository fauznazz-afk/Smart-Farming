import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

/// Hero card: live PV power, battery SOC gauge, and where the power is going.
class LivePowerCard extends StatelessWidget {
  const LivePowerCard({
    super.key,
    required this.pvPower,
    required this.acPower,
    required this.batteryPower,
    required this.soc,
    required this.pzemStale,
    required this.pzemAgeLabel,
  });

  final double? pvPower;
  /// The house draw in watts, or `null` if the meter has not reported.
  final double? acPower;

  /// DC power into the battery, positive while charging. Derived by the caller
  /// because the BMS reports voltage and current rather than power.
  ///
  /// `null` when the BMS has not reported.
  final double? batteryPower;

  /// The state of charge as a percentage, or `null` when the BMS has not
  /// reported.
  final double? soc;
  final bool pzemStale;
  final String? pzemAgeLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            pzemStale: pzemStale,
            ageLabel: pzemAgeLabel,
          ),
          const SizedBox(height: 14),
          _PowerFlow(
            pvPower: pvPower,
            acPower: acPower,
            batteryPower: batteryPower,
            soc: soc,
          ),
        ],
      ),
    );
  }
}

/// Where the solar power is going, right now.
class _PowerFlow extends StatelessWidget {
  const _PowerFlow({
    required this.pvPower,
    required this.acPower,
    required this.batteryPower,
    required this.soc,
  });

  final double? pvPower;
  final double? acPower;
  final double? batteryPower;
  final double? soc;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final solar = pvPower;
    if (solar == null) {
      return Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 13, color: faint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Power flow unavailable until the inverter reports',
              style: AppType.labelMicro.copyWith(color: faint),
            ),
          ),
        ],
      );
    }

    final solarForBar = solar.clamp(0.0, double.infinity);
    final loadForBar = acPower?.clamp(0.0, double.infinity);
    final chargeState =
        batteryPower == null ? null : batteryChargeState(batteryPower!);
    final charging = chargeState == BatteryChargeState.charging;
    final discharging = chargeState == BatteryChargeState.discharging;
    final knownShare = loadForBar != null && solarForBar > 0;
    final loadShare =
        knownShare ? (loadForBar / solarForBar).clamp(0.0, 1.0) : 0.0;
    final coversLoad = knownShare && solarForBar >= loadForBar;
    final spareWatts = knownShare ? solarForBar - loadForBar : 0.0;
    final batterySupplies = discharging && batteryPower!.abs() > spareWatts;
    final batteryMakesUp = discharging && !coversLoad;

    final solarLabel = 'Solar';
    final houseLabel = 'House';
    final batteryLabel = chargeState?.label ?? 'Battery';

    // Category hues: Solar = PV (accent/yellow), House = AC (secondary/periwinkle), Battery = Battery (primary/coral)
    final solarHue = categoryColor(MetricCategory.pv);
    final houseHue = categoryColor(MetricCategory.ac);
    final batteryHue = categoryColor(MetricCategory.battery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final labels = [solarLabel, houseLabel, batteryLabel];
            final natural = _labelNaturalWidths(context, labels);
            final available = constraints.maxWidth - 2 * _kArrowWidth;

            // Measured, not arithmetic. See [_planLabelSlots] for why the
            // proportional split this replaced was wrong above a 2.0 text scale.
            final columns = _planLabelSlots(
              context,
              labels,
              natural: natural,
              available: available,
            );

            // Three columns stop being a diagram once a label has to break
            // inside a single word's worth of glyphs: at 320 dp and a 3.0 scale
            // the column plan wants five lines and draws `Solar` as one letter
            // per line. Stacked, each term gets the whole card width and the
            // worst label needs two lines.
            final stacked = columns.lines > _kMaxColumnLabelLines;
            final plan = stacked
                ? _planLabelSlots(
                    context,
                    labels,
                    natural: natural,
                    available: constraints.maxWidth,
                  )
                : columns;

            final figureScale = _sharedFigureScale(
              context,
              slotWidths: plan.widths,
              watts: [solarForBar, acPower, batteryPower],
              color: faint,
            );

            final labelHeight = _labelBlockHeight(context, [plan.lines]);

            Widget arrow(IconData glyph) => Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
              child: Icon(glyph, size: 15, color: faint),
            );

            final terms = [
              _Term(
                icon: Icons.wb_sunny_rounded,
                label: solarLabel,
                labelHeight: labelHeight,
                labelLines: plan.lines,
                watts: solarForBar,
                color: solarHue,
                figureScale: figureScale,
              ),
              _Term(
                icon: Icons.home_rounded,
                label: houseLabel,
                labelHeight: labelHeight,
                labelLines: plan.lines,
                watts: acPower,
                color: houseHue,
                figureScale: figureScale,
              ),
              _Term(
                icon: charging
                    ? Icons.battery_charging_full
                    : discharging
                    ? Icons.battery_5_bar_rounded
                    : Icons.battery_std_rounded,
                label: batteryLabel,
                labelHeight: labelHeight,
                labelLines: plan.lines,
                watts: batteryPower,
                color: batteryHue,
                figureScale: figureScale,
              ),
            ];

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < terms.length; i++) ...[
                    Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(width: plan.widths[i], child: terms[i]),
                    ),
                    if (i < terms.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, top: 6, bottom: 6),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: 15,
                          color: faint,
                        ),
                      ),
                  ],
                ],
              );
            }

            final totalWidth = plan.widths.fold(0.0, (a, b) => a + b);

            Widget slot(int index) => Flexible(
              flex: (plan.widths[index] / totalWidth * 1000).round().clamp(1, 1000),
              child: terms[index],
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                slot(0),
                arrow(Icons.arrow_right_alt_rounded),
                slot(1),
                arrow(
                  charging
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                ),
                slot(2),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.bar),
            child: SizedBox(
              height: 8,
              child: solarForBar > 0
                  ? Row(
                      children: [
                        Expanded(
                          flex: (loadShare * 1000).round().clamp(1, 1000),
                          child: ColoredBox(color: houseHue),
                        ),
                        if (loadShare < 1)
                          Expanded(
                            flex: ((1 - loadShare) * 1000).round().clamp(1, 1000),
                            child: ColoredBox(color: solarHue),
                          ),
                      ],
                    )
                  : ColoredBox(color: AppSurfaces.track),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SocLine(soc: soc),
        const SizedBox(height: 8),
        Text(
          acPower == null
              ? 'House draw unavailable until the meter reports'
              : batteryMakesUp
              ? 'The array is short, and the battery adds '
                    '${batteryPower!.abs().toStringAsFixed(0)} W'
              : !coversLoad
              ? 'The array is not covering the house load right now'
              : batterySupplies
              ? 'The array covers the house, and the battery adds '
                    '${batteryPower!.abs().toStringAsFixed(0)} W'
              : spareWatts > 0.5
              ? 'The array covers the house, '
                    '${spareWatts.toStringAsFixed(0)} W spare'
              : 'The array is just covering the house load',
          style: AppType.labelMicro.copyWith(
            color: acPower != null && !coversLoad && !batteryMakesUp
                ? statusWarn
                : faint,
          ),
        ),
      ],
    );
  }
}

/// The state of charge, as a label, a track and a percentage.
class _SocLine extends StatelessWidget {
  const _SocLine({
    required this.soc,
  });

  final double? soc;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final clamped = soc?.clamp(0.0, 100.0);
    final accent = categoryColor(MetricCategory.battery);

    return Row(
      children: [
        Flexible(
          child: Text(
            'Charge',
            style: AppType.labelMicro.copyWith(color: faint),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.bar),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(
                            AppSurfaces.track,
                            const Color(0xFF000000),
                            0.18,
                          )!,
                          AppSurfaces.track,
                        ],
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (clamped ?? 0) / 100,
                    child: ColoredBox(color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Semantics(
            label: clamped == null
                ? 'State of charge: not reporting'
                : 'State of charge: ${clamped.toStringAsFixed(0)} percent',
            child: Text(
              clamped == null ? '--' : '${clamped.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: AppType.numeralLg.copyWith(color: appPrimaryText),
            ),
          ),
        ),
      ],
    );
  }
}

/// The style for a flow-row label.
///
/// **Left inheriting from `DefaultTextStyle` deliberately, and the reason is a
/// failed hypothesis worth recording.** Setting every field here was tried,
/// because the ambient style now carries [AppType]'s `letterSpacing: 0.12em` and
/// an eleven-character `Discharging` at a 3.0 system scale plausibly gains 40 dp
/// from that tracking -- enough to force a third line past `maxLines: 2`.
///
/// It made the symptom *worse*, not better: `Solar` went from `S…` to `…`, which
/// means the slot collapsed rather than the text overran. So the tracking is not
/// the cause and the width allocation is. Recorded because the next reader will
/// have the same idea, and the measurement that refutes it is not free.
///
/// The three terms all share one height so a wrapped label cannot push its figure
/// below the other two.
TextStyle _termLabelStyle(BuildContext context) => DefaultTextStyle.of(context)
    .style
    .copyWith(fontSize: 11);

double _naturalWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

TextStyle _termFigureStyle({required Color color}) => TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w800,
  height: 1.0,
  color: color,
);

TextStyle _termUnitStyle({required Color color}) =>
    TextStyle(fontSize: 11, color: color);

String? _figureText(double? watts) =>
    watts == null ? '--' : watts.toStringAsFixed(0);

double _sharedFigureScale(
  BuildContext context, {
  required List<double> slotWidths,
  required List<double?> watts,
  required Color color,
}) {
  const icon = 13.0;
  const gaps = 4.0 + 2.0;

  final figureNeeds = [
    for (final w in watts)
      _naturalWidth(context, _figureText(w)!, _termFigureStyle(color: color)),
  ];
  final unitNeed = _naturalWidth(context, 'W', _termUnitStyle(color: color));

  var scale = 1.0;
  for (var i = 0; i < watts.length; i++) {
    final share = (slotWidths[i] - icon - gaps) / 2;
    if (share <= 0) continue;
    final text = math.max(figureNeeds[i], unitNeed);
    if (text > 0) scale = math.min(scale, share / text);
  }
  return scale.clamp(0.0, 1.0);
}

List<double> _labelNaturalWidths(BuildContext context, List<String> labels) {
  final style = _termLabelStyle(context);
  return [for (final label in labels) _naturalWidth(context, label, style)];
}

/// The width one flow arrow takes: the 15 dp glyph plus the 2 dp of padding on
/// each side of it.
const double _kArrowWidth = 15 + 4;

/// The most lines a flow label may wrap to while the three terms still sit side
/// by side. Past this the row is stacking -- see [_PowerFlow].
const int _kMaxColumnLabelLines = 4;

/// How many lines a probe is worth before a viewport is declared too narrow to
/// plan for at all.
const int _kMaxLabelLineProbe = 8;

/// A line count and the slot widths that go with it.
class _LabelPlan {
  const _LabelPlan(this.lines, this.widths);

  /// The most lines any of the labels needs, at the widths in [widths].
  final int lines;

  /// The width each label is given. In the column layout these are shares of the
  /// space between the two arrows; stacked, they are shares of the card.
  final List<double> widths;
}

/// Split [available] between [labels] so that every one of them wraps to at most
/// as many lines as any other.
///
/// **The previous allocation was proportional to each label's one-line width,
/// and the arithmetic behind it is what amputated the labels.** Dividing the
/// total natural width by the available width is a floor on the shared line
/// count, not a description of it, because the engine breaks lines at glyph
/// boundaries inside an unbreakable word and that boundary is not a smooth
/// function of the width. Measured on 10 October 2026:
///
/// - 381 dp, scale 2.0. `Solar` needs 111.3 dp and was allotted 63.1, which the
///   arithmetic scored as 1.77 lines. It broke into three. A 22.3 dp glyph in a
///   63.1 dp slot holds two glyphs and a third, and the greedy break lands on
///   `So`/`la`/`r`; at 70.2 dp the same string breaks `Sol`/`ar` and it is two.
///   So a 7 dp change in slot width -- and the proportional split has nowhere
///   to land but within a few dp of a cliff like that -- is the difference
///   between a word and a syllable.
/// - 381 dp, scale 3.0. The same slot fell below one glyph per line, `Solar`
///   needed five, and `maxLines: 2` drew a bare `…` on the first line because a
///   33 dp glyph and a 33 dp ellipsis no longer fitted in 63 dp either.
/// - 320 dp, scale 1.5. Only 3.5 dp from the same cliff, and `House` drew
///   `H…`.
///
/// So this searches for the smallest line count whose per-label minimum widths
/// fit [available], and measures each minimum against a [TextPainter] rather
/// than deriving it. The slack left over is shared equally, so a long label is
/// not handed the width a short one cannot use and the row does not develop one
/// very wide slot next to two narrow ones.
_LabelPlan _planLabelSlots(
  BuildContext context,
  List<String> labels, {
  required List<double> natural,
  required double available,
}) {
  if (available <= 0) {
    return _LabelPlan(_kMaxLabelLineProbe, List<double>.filled(labels.length, 0));
  }

  final total = natural.fold(0.0, (a, b) => a + b);
  // No label can take fewer than `natural/width` lines, so this is a hard floor
  // on the shared count. Starting there rather than at one is what keeps the
  // search to a single probe in the common case: three labels at ten probes
  // each is not a cost worth paying on every ten-second poll.
  final first = math.max(1, (total / available).ceil());

  var best = _LabelPlan(first, List.of(natural));
  for (var lines = first; lines <= _kMaxLabelLineProbe; lines++) {
    final minima = <double>[
      for (var i = 0; i < labels.length; i++)
        _minWidthForLines(context, labels[i], lines, natural[i]),
    ];
    best = _LabelPlan(lines, minima);

    final used = minima.fold(0.0, (a, b) => a + b);
    if (used <= available) {
      final slack = (available - used) / labels.length;
      return _LabelPlan(lines, [for (final m in minima) m + slack]);
    }
  }

  // Unreachable on a viewport wider than three glyphs, which every phone is.
  // Return the last plan measured rather than throwing: a row that is slightly
  // too narrow beats a row that has lost its labels.
  return best;
}

/// The narrowest width at which [label] wraps to at most [lines] lines.
///
/// [TextPainter`'s line count][TextPainter.computeLineMetrics] falls
/// monotonically as the width grows, so this is a binary search. The half
/// logical pixel added at the end is not decoration: `RenderFlex` rounds a
/// flexed child's share to whole logical pixels, so the width a slot is finally
/// given can be slightly under the width it was planned at, and a label sitting
/// on a break boundary responds to that by growing a line.
double _minWidthForLines(
  BuildContext context,
  String label,
  int lines,
  double natural,
) {
  if (lines <= 1) return natural + 0.5;

  var lo = 0.0;
  var hi = natural;
  for (var i = 0; i < 7; i++) {
    final mid = (lo + hi) / 2;
    if (_labelLineCount(context, label, slotWidth: mid) <= lines) {
      hi = mid;
    } else {
      lo = mid;
    }
  }

  // Seven steps over a 166 dp range lands within 1.3 dp of the real boundary,
  // and the boundary is a step, so rounding can leave the probe on the wrong
  // side of it. Widen until it measures true rather than trust the search.
  var width = hi;
  for (var i = 0; i < 4 && _labelLineCount(context, label, slotWidth: width) > lines; i++) {
    width = math.min(natural, width + math.max(1.0, width * 0.05));
  }
  return math.min(natural, width + 0.5);
}

int _labelLineCount(
  BuildContext context,
  String label, {
  required double slotWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: _termLabelStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: slotWidth);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return math.max(1, lines);
}

double _labelBlockHeight(BuildContext context, Iterable<int> lineCounts) {
  final probe = TextPainter(
    text: TextSpan(text: 'Solar', style: _termLabelStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final lineHeight = probe.height;
  probe.dispose();

  return lineHeight * lineCounts.fold(1, math.max);
}

/// One labelled figure with a unit, sized to sit in a row of three.
class _Term extends StatelessWidget {
  const _Term({
    required this.icon,
    required this.label,
    required this.watts,
    required this.color,
    this.labelHeight,
    this.labelLines,
    this.figureScale = 1,
  });

  final IconData icon;
  final String label;
  final double? labelHeight;

  /// The shared line count the slot was planned for, and the label's `maxLines`.
  ///
  /// **This is a measured number, not a constant, and the constant it replaced
  /// (`maxLines: 2`) was the amputation itself.** The block above the figure has
  /// always been sized from the line count measured at the width the slot was
  /// given, so at 411 dp and a 2.5 scale `Solar` was allotted a three-line block
  /// and drew two of them: `maxLines: 2` cut `Solar` to `S…` in a box that had
  /// room for three. The old code hid the contradiction behind a fixed constant
  /// that was below the measured value at 8 of the 20 width/scale combinations
  /// the test group covers, and above it at the other 12 -- it passed by
  /// accident, at whichever end it happened to fall.
  ///
  /// Passing the plan's own count keeps the two halves from disagreeing, and
  /// keeps the ellipsis available as the degradation: a slot that somehow ends
  /// up narrower than planned ellipsises, which the sideways detector sees,
  /// instead of growing a line the shared block cannot show.
  final int? labelLines;
  final double figureScale;
  final double? watts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final labelText = Text(
      label,
      maxLines: labelLines,
      style: _termLabelStyle(context).copyWith(color: faint),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelHeight == null)
          labelText
        else
          SizedBox(height: labelHeight, child: labelText),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Icon(icon, size: 13, color: faint),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _figureText(watts)!,
                  style: _termFigureStyle(
                    color: watts == null ? faint : color,
                  ).copyWith(fontSize: 24 * figureScale),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'W',
                  style: _termUnitStyle(
                    color: faint,
                  ).copyWith(fontSize: 11 * figureScale),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pzemStale,
    required this.ageLabel,
  });

  final bool pzemStale;
  final String? ageLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.wb_sunny_rounded,
          size: 18,
          color: categoryColor(MetricCategory.pv),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Live power',
              maxLines: 1,
              softWrap: false,
              style: AppType.labelUppercase.copyWith(color: faintColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (ageLabel != null)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pzemStale ? Icons.warning_amber_rounded : Icons.schedule,
                  size: 12,
                  color: pzemStale ? statusWarn : faintColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      ageLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: pzemStale
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: pzemStale ? statusWarn : faintColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
