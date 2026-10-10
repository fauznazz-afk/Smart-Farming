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
            const arrow = 15 + 4;
            final fairShare = (constraints.maxWidth - 2 * arrow) / 3;
            final needed = _labelNaturalWidths(
              context,
              [solarLabel, houseLabel, batteryLabel],
            );
            final allLabelsFitOnOneLine = needed.every((w) => w <= fairShare);
            final total = needed.fold(0.0, (a, b) => a + b);
            final available = constraints.maxWidth - 2 * arrow;

            double slotWidthAt(int index) => allLabelsFitOnOneLine
                ? fairShare
                : available * needed[index] / total;

            final figureScale = _sharedFigureScale(
              context,
              slotWidths: [
                for (var i = 0; i < needed.length; i++) slotWidthAt(i),
              ],
              watts: [solarForBar, acPower, batteryPower],
              color: faint,
            );

            final labelHeight = _labelBlockHeight(
              context,
              [
                for (var i = 0; i < needed.length; i++)
                  _labelLineCount(
                    context,
                    i == 2 ? batteryLabel : (i == 0 ? solarLabel : houseLabel),
                    slotWidth: slotWidthAt(i) + 0.5,
                  ),
              ],
            );

            Widget slot(Widget child, int index) {
              if (allLabelsFitOnOneLine) return Expanded(child: child);
              return Flexible(
                flex: (needed[index] / total * 1000).round().clamp(1, 1000),
                child: child,
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                slot(
                  _Term(
                    icon: Icons.wb_sunny_rounded,
                    label: solarLabel,
                    labelHeight: labelHeight,
                    watts: solarForBar,
                    color: solarHue,
                    figureScale: figureScale,
                  ),
                  0,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
                  child: Icon(Icons.arrow_right_alt_rounded, size: 15, color: faint),
                ),
                slot(
                  _Term(
                    icon: Icons.home_rounded,
                    label: houseLabel,
                    labelHeight: labelHeight,
                    watts: acPower,
                    color: houseHue,
                    figureScale: figureScale,
                  ),
                  1,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
                  child: Icon(
                    charging
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 15,
                    color: faint,
                  ),
                ),
                slot(
                  _Term(
                    icon: charging
                        ? Icons.battery_charging_full
                        : discharging
                        ? Icons.battery_5_bar_rounded
                        : Icons.battery_std_rounded,
                    label: batteryLabel,
                    labelHeight: labelHeight,
                    watts: batteryPower,
                    color: batteryHue,
                    figureScale: figureScale,
                  ),
                  2,
                ),
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
    this.figureScale = 1,
  });

  final IconData icon;
  final String label;
  final double? labelHeight;
  final double figureScale;
  final double? watts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final labelText = Text(
      label,
      maxLines: 2,
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
