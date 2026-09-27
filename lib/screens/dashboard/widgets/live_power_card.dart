import 'package:flutter/material.dart';

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
          const SizedBox(height: 8),
          _ValueRow(
            pvPower: pvPower,
            soc: soc,
            isDark: isDark,
            seedColor: seedColor,
          ),
          const SizedBox(height: 14),
          _PowerFlow(
            pvPower: pvPower,
            acPower: acPower,
            batteryPower: batteryPower,
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
    required this.isDark,
    required this.seedColor,
  });

  final double? pvPower;
  final double acPower;
  final double batteryPower;
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
    // Three states, not two. The pack genuinely sits in standby for stretches, and
    // at zero current the sign of the reading is pure noise, so picking one of two
    // labels would flip the card between "Charging" and "Discharging" several times
    // a minute while asserting a direction the data does not establish. Standby is
    // the state that gets skipped, and it is the one this BMS reports most often.
    //
    // The sign is the BMS's own: negative while charging, which is the opposite of
    // what most people assume and is confirmed on the Battery page. Nothing here
    // flips it, so the figure printed below matches the figure one tab away.
    const standbyWatts = 1.0;
    final charging = batteryPower < -standbyWatts;
    final discharging = batteryPower > standbyWatts;
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Term(
              icon: Icons.wb_sunny_rounded,
              label: 'Solar',
              watts: solarForBar,
              color: accent,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 0, 7, 13),
              child: Icon(Icons.arrow_right_alt_rounded, size: 15, color: faint),
            ),
            _Term(
              icon: Icons.home_rounded,
              label: 'House',
              watts: acPower,
              color: loadColor,
              isDark: isDark,
            ),
            const SizedBox(width: 14),
            _Term(
              icon: charging
                  ? Icons.battery_charging_full
                  : discharging
                  ? Icons.battery_5_bar_rounded
                  : Icons.battery_std_rounded,
              label: charging
                  ? 'Charging'
                  : discharging
                  ? 'Discharging'
                  : 'Standby',
              // Not `.abs()`. The Battery page prints the same figure with the
              // same sign, and two screens reporting different numbers for one
              // measurement is worse than an odd-looking minus. No explicit "+"
              // either, because the Battery page does not print one.
              watts: batteryPower,
              color: accent,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 9),
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
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
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
        const SizedBox(height: 5),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: faint),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: faint)),
          ],
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              watts.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text('W', style: TextStyle(fontSize: 10, color: faint)),
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

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.pvPower,
    required this.soc,
    required this.isDark,
    required this.seedColor,
  });

  final double? pvPower;
  final double soc;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(isDark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Semantics(
                    label: pvPower == null
                        ? 'PV output power unavailable'
                        : 'PV output: ${pvPower!.toStringAsFixed(0)} watts',
                    child: Text(
                      pvPower == null ? '--' : pvPower!.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Text('W', style: TextStyle(fontSize: 20, color: faint)),
                  ),
                ],
              ),
            ],
          ),
        ),
        GlassCircularGauge(
          progress: soc / 100,
          centerLabel: '${soc.toStringAsFixed(0)}%',
          centerSubLabel: 'SOC',
          trackColor: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          progressColor: seedColor,
          size: 90,
          strokeWidth: 9,
          semanticLabel:
              'Battery State of Charge: ${soc.toStringAsFixed(0)} percent',
        ),
      ],
    );
  }
}
