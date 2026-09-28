import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';

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
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
  });

  final double? pvPower;
  final double acPower;

  /// DC power into the battery, positive while charging. Derived by the caller
  /// because the BMS reports voltage and current rather than power.
  final double batteryPower;
  final double soc;
  final bool pzemStale;
  final String? pzemAgeLabel;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(pzemStale: pzemStale, ageLabel: pzemAgeLabel, isDark: isDark, seedColor: seedColor),
          const SizedBox(height: 14),
          _PowerFlow(
            pvPower: pvPower,
            acPower: acPower,
            batteryPower: batteryPower,
            soc: soc,
            isDark: isDark,
            seedColor: seedColor,
          ),
        ],
      ),
    );
  }
}

/// Where the solar power is going, right now.
///
/// This replaced a row of three shortcut capsules labelled PV output, AC load and
/// battery. All three were already on this same card: the PV figure is the number
/// directly above in the hero, the battery charge is the gauge beside it, and as
/// navigation they duplicated the bottom bar, which has PV, AC and Battery tabs.
/// The progress bars under them were the weakest part of all — PV was divided by
/// a hard-coded 300 W and the load by 2000 W, so a bar could read full while the
/// number beside it was wrong.
///
/// What none of it said is the thing a solar dashboard exists to answer: is the
/// array covering the house, and what is the battery doing about it. That is
/// arithmetic on numbers already on screen, and it was the number missing.
///
/// It states the three real readings rather than a derived "short by", because the
/// three come from two devices that do not update in step. On the test rig the
/// array read 8 W while the battery reported charging at 21 W, and a derived
/// shortfall said the array was 5 W short of a 14 W load at the same moment it
/// said the battery was taking in 21 W. Two claims that contradict each other read
/// as a fault in the app rather than as what is actually happening, so the strip
/// prints the readings, draws the proportion, and stops there.
class _PowerFlow extends StatelessWidget {
  const _PowerFlow({
    required this.pvPower,
    required this.acPower,
    required this.batteryPower,
    required this.soc,
    required this.isDark,
    required this.seedColor,
  });

  final double? pvPower;
  final double acPower;
  final double batteryPower;
  final double soc;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(isDark);
    final solar = pvPower;
    if (solar == null) {
      // No reading is not the same as no output, and saying so is more useful
      // than drawing a bar of zeroes that looks like a dead array.
      return Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 13, color: faint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Power flow unavailable until the inverter reports',
              style: TextStyle(fontSize: 12, color: faint),
            ),
          ),
        ],
      );
    }

    // Clamped only for the bar: a sensor glitch of -1 W would otherwise draw a
    // negative segment. The printed figures stay unclamped, because hiding a
    // wrong reading is worse than showing one.
    final solarForBar = solar.clamp(0.0, double.infinity);
    final loadForBar = acPower.clamp(0.0, double.infinity);
    // Three states, not two, and the mapping lives in utils/battery_sign.dart so
    // it can be pinned by a test. It used to be two comparisons here with a
    // comment asserting a convention that a BMS swap had since invalidated, and
    // the comment outlived the hardware it described.
    //
    // The sign is the BMS's own and nothing here flips it, so the figure printed
    // below matches the figure one tab away on the Battery page. Negating to make
    // the number "look right" was tried and reverted: two screens reporting
    // different numbers for one measurement is worse than an odd-looking minus.
    final chargeState = batteryChargeState(batteryPower);
    final charging = chargeState == BatteryChargeState.charging;
    final discharging = chargeState == BatteryChargeState.discharging;
    final coversLoad = solarForBar >= loadForBar;
    final loadShare =
        solarForBar <= 0 ? 0.0 : (loadForBar / solarForBar).clamp(0.0, 1.0);

    final accent = themeColor(
      seedColor: seedColor,
      lightness: isDark ? 0.74 : 0.42,
    );
    final loadColor = themeColor(
      seedColor: seedColor,
      lightness: isDark ? 0.62 : 0.34,
      saturation: 0.46,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The flow IS the hero now. It used to sit under a 48 px PV number that
        // said the same thing again as the first term, so the largest element on
        // the card was the least informative number on it — one reading, printed
        // twice, with the relationship between three readings shrunk underneath.
        //
        // Expanded on all three so the slots are equal. `mainAxisSize.min` let the
        // widest term set the width for all three, which is why "Discharging"
        // used to squeeze its neighbours and why a longer label would have pushed
        // the row past the card rather than reflowing it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Term(
                icon: Icons.wb_sunny_rounded,
                label: 'Solar',
                watts: solarForBar,
                color: accent,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
              child: Icon(Icons.arrow_right_alt_rounded, size: 15, color: faint),
            ),
            Expanded(
              child: _Term(
                icon: Icons.home_rounded,
                label: 'House',
                watts: acPower,
                color: loadColor,
                isDark: isDark,
              ),
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
            Expanded(
              child: _Term(
                icon: charging
                    ? Icons.battery_charging_full
                    : discharging
                    ? Icons.battery_5_bar_rounded
                    : Icons.battery_std_rounded,
                label: chargeState.label,
                // Not `.abs()`. The Battery page prints the same figure with the
                // same sign, and two screens reporting different numbers for one
                // measurement is worse than an odd-looking minus. No explicit "+"
                // either, because the Battery page does not print one.
                watts: batteryPower,
                color: accent,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // The house's share of the array's output. A proportion of something on
        // screen, not a claim about where the power physically went.
        //
        // The explicit width matters. `SizedBox(height: 5)` alone leaves maxWidth
        // at infinity, so the Row below it is unbounded and the Expanded segments
        // resolve to nothing at all — the bar rendered as empty space, silently,
        // with no exception to notice. A Column with `CrossAxisAlignment.start`
        // does pass a bounded maxWidth down, so `double.infinity` resolves to the
        // card's content width rather than to an unbounded one.
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              // 8, not 5. At 5 px the bar was a hairline that read as a divider
              // rather than as a proportion, so the one thing the card was
              // actually saying about the array had no visual weight.
              height: 8,
              child: solarForBar > 0
                  ? Row(
                      children: [
                        Expanded(
                          flex: (loadShare * 1000).round().clamp(1, 1000),
                          child: ColoredBox(color: loadColor),
                        ),
                        if (loadShare < 1)
                          Expanded(
                            flex: ((1 - loadShare) * 1000).round().clamp(1, 1000),
                            child: ColoredBox(color: accent),
                          ),
                      ],
                    )
                  : ColoredBox(color: faint.withValues(alpha: 0.18)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // State of charge, on its own line under the flow rather than as a dial
        // beside the hero number. Two reasons. It groups with the other battery
        // facts instead of floating away from them — charge and direction are one
        // fact about one device, and a gauge opposite the flow read as a separate
        // instrument. And the dial repeated "SOC" in words under a percentage that
        // already carried a unit, which is the same "say it twice" problem the PV
        // number had.
        //
        // Not tinted by level. Green would be a second colour system beside the
        // theme for a condition that is boring when true, and the user did not
        // choose it; the fill uses the same accent as the rest of the card.
        _SocLine(soc: soc, isDark: isDark, seedColor: seedColor),
        const SizedBox(height: 8),
        Text(
          !coversLoad
              ? 'The array is not covering the house load right now'
              : solarForBar - loadForBar > 0.5
              ? 'The array covers the house, '
                    '${(solarForBar - loadForBar).toStringAsFixed(0)} W spare'
              : 'The array is just covering the house load',
          style: TextStyle(
            fontSize: 11,
            color: !coversLoad ? statusWarn(isDark) : faint,
          ),
        ),
      ],
    );
  }
}

/// The state of charge, as a label, a track and a percentage.
///
/// The gauge this replaced was a `GlassCircularGauge` with "SOC" printed inside it
/// under a number that already had a unit, sitting to the right of a hero figure
/// it had nothing to do with. Three elements for one reading.
class _SocLine extends StatelessWidget {
  const _SocLine({
    required this.soc,
    required this.isDark,
    required this.seedColor,
  });

  final double soc;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(isDark);
    final clamped = soc.clamp(0.0, 100.0);
    final accent = themeColor(
      seedColor: seedColor,
      lightness: isDark ? 0.68 : 0.38,
    );
    return Row(
      children: [
        Text(
          'Charge',
          style: TextStyle(fontSize: 11, color: faint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: faint.withValues(alpha: isDark ? 0.16 : 0.12)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: clamped / 100,
                    child: ColoredBox(color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: 'State of charge: ${clamped.toStringAsFixed(0)} percent',
          child: Text(
            '${clamped.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

/// One labelled figure with a unit, sized to sit in a row of three.
class _Term extends StatelessWidget {
  const _Term({
    required this.icon,
    required this.label,
    required this.watts,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final double watts;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The label sits above the number, not beside it. "Discharging" is eleven
        // characters and the slot is a third of the card, so beside-the-number it
        // forced the row wide enough to overflow; above it, the label gets the
        // full slot and ellipsises on its own if a future one is longer still.
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: faint),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Baseline-aligned with the figure rather than centred in the Row, so
            // a 13 px icon sits on the number's baseline instead of floating
            // halfway up a 24 px glyph.
            Icon(icon, size: 13, color: faint),
            const SizedBox(width: 4),
            Text(
              watts.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text('W', style: TextStyle(fontSize: 11, color: faint)),
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
    required this.isDark,
    required this.seedColor,
  });

  final bool pzemStale;
  final String? ageLabel;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.wb_sunny_rounded,
          size: 18,
          color: metricColor(seedColor: seedColor, index: 2, isDark: isDark),
        ),
        const SizedBox(width: 6),
        // Names the card, not the reading. "PV Output" appeared three times on
        // one card: here, directly under the big number, and again on the first
        // capsule. The capsule label is the one that has to be there, because
        // three identical tiles in a row are indistinguishable without it.
        Text(
          'Live power',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: faintColor(isDark),
          ),
        ),
        const Spacer(),
        // Always shown, not only when stale. There was no persistent indication
        // of liveness anywhere in the Overview, so a dashboard that had quietly
        // stopped updating looked exactly like a live one until something else
        // failed. Stale now means amber, fresh means quiet.
        if (ageLabel != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pzemStale ? Icons.warning_amber_rounded : Icons.schedule,
                size: 12,
                color: pzemStale ? statusWarn(isDark) : faintColor(isDark),
              ),
              const SizedBox(width: 4),
              Text(
                ageLabel!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: pzemStale ? FontWeight.w600 : FontWeight.w400,
                  color: pzemStale ? statusWarn(isDark) : faintColor(isDark),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
