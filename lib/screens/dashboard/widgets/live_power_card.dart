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
    required this.theme,
    required this.seedColor,
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

  /// The appearance to paint, as an `AppTheme`.
  ///
  /// The card's own `AppCard` draws the `raised` pair, which Dracula derives
  /// separately, and the flow strip below it fills its empty-state track with
  /// **`AppSurfaces.track`** — a token that is *darker* than Dracula's page,
  /// the inverse of both existing modes. Neither fact survives a boolean, so
  /// this takes the enum and passes `theme.isDark` only to the text and status
  /// colours, which are shared by the two dark presets.
  final AppTheme theme;

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      theme: theme,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            pzemStale: pzemStale,
            ageLabel: pzemAgeLabel,
            theme: theme,
            seedColor: seedColor,
          ),
          const SizedBox(height: 14),
          _PowerFlow(
            pvPower: pvPower,
            acPower: acPower,
            batteryPower: batteryPower,
            soc: soc,
            theme: theme,
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
    required this.theme,
    required this.seedColor,
  });

  final double? pvPower;

  /// See [LivePowerCard.acPower].
  final double? acPower;

  /// See [LivePowerCard.batteryPower].
  final double? batteryPower;

  /// See [LivePowerCard.soc].
  final double? soc;

  /// See [LivePowerCard.theme].
  final AppTheme theme;

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(theme.isDark);
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
    final loadForBar = acPower?.clamp(0.0, double.infinity);
    // Three states, not two, and the mapping lives in utils/battery_sign.dart so
    // it can be pinned by a test. It used to be two comparisons here with a
    // comment asserting a convention that a BMS swap had since invalidated, and
    // the comment outlived the hardware it described.
    //
    // The sign is the BMS's own and nothing here flips it, so the figure printed
    // below matches the figure one tab away on the Battery page. Negating to make
    // the number "look right" was tried and reverted: two screens reporting
    // different numbers for one measurement is worse than an odd-looking minus.
    final chargeState =
        batteryPower == null ? null : batteryChargeState(batteryPower!);
    final charging = chargeState == BatteryChargeState.charging;
    final discharging = chargeState == BatteryChargeState.discharging;
    // A proportion of a real number over a real number. When either side is
    // missing there is no proportion to draw, so the bar stays as the empty
    // track rather than filling to 0% or to 100% off a fabricated operand.
    //
    // This was the furthest-reaching part of the absent-data bug. `coversLoad`
    // compared a genuine solar figure against `acPower`'s fabricated zero, so an
    // absent meter produced "The array covers the house load" -- a confident
    // sentence, in words, about the user's own house, derived from data that
    // never arrived.
    final knownShare = loadForBar != null && solarForBar > 0;
    final loadShare =
        knownShare ? (loadForBar / solarForBar).clamp(0.0, 1.0) : 0.0;
    final coversLoad = knownShare && solarForBar >= loadForBar;

    // `theme.isDark` and not a three-way switch, and that is a deliberate
    // no-change rather than an oversight: these two are hand-picked HSL
    // lightnesses, not a token with a per-theme answer, so Dracula takes the
    // dark values unchanged.
    //
    // **They do not all clear AA on Dracula, and that is recorded here rather
    // than fixed here.** Measured on the Dracula ramp with the preset purple
    // `#BD93F9` as the seed: 0.74/0.62 reads `#B594E6` at 5.66:1 on the page and
    // 4.68:1 on chrome, which clears; 0.62 at saturation 0.46 reads `#9672CB` at
    // 3.77 and 3.13, and the 0.68 in `_SocLine` below reads `#A47BE0` at 4.40
    // and 3.64. The first is a 24sp bold figure where 3:1 applies, so it is a
    // margin question; the second is a 12sp percentage, where 4.5:1 applies, so
    // it is a genuine shortfall on Dracula.
    //
    // The repair is to move all three to `metricColor(theme:)`, which is the
    // function that already solves Dracula's purple (`#C1A3EB`, 6.58 on the page
    // and 5.45 on chrome). That changes three colours and drops two
    // hand-picked saturations, so it wants its own measurement rather than
    // riding along in a signature migration.
    final accent = themeColor(
      seedColor: seedColor,
      lightness: theme.isDark ? 0.74 : 0.42,
    );
    final loadColor = themeColor(
      seedColor: seedColor,
      lightness: theme.isDark ? 0.62 : 0.34,
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
                isDark: theme.isDark,
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
                isDark: theme.isDark,
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
                label: chargeState?.label ?? 'Battery',
                // Not `.abs()`. The Battery page prints the same figure with the
                // same sign, and two screens reporting different numbers for one
                // measurement is worse than an odd-looking minus. No explicit "+"
                // either, because the Battery page does not print one.
                watts: batteryPower,
                color: accent,
                isDark: theme.isDark,
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
            borderRadius: AppRadius.all(AppRadius.bar),
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
                  : ColoredBox(color: AppSurfaces.track(theme)),
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
        _SocLine(soc: soc, theme: theme, seedColor: seedColor),
        const SizedBox(height: 8),
        Text(
          // **Three branches before the three verdicts, and the first one used
          // not to exist.** This sentence was computed from `coversLoad`, which
          // compared a genuine solar figure against `acPower`'s fabricated zero
          // when the meter had not reported -- so the card asserted "The array
          // covers the house load" about a house it had no measurement for.
          // A confident sentence is worse than a confident number here, because
          // there is no minus sign to make the reader suspicious.
          //
          // It also gets its own colour. `statusWarn` is for a measured shortfall;
          // an absent meter is not a shortfall and must not wear its colour.
          acPower == null
              ? 'House draw unavailable until the meter reports'
              : !coversLoad
              ? 'The array is not covering the house load right now'
              : solarForBar - loadForBar > 0.5
              ? 'The array covers the house, '
                    '${(solarForBar - loadForBar).toStringAsFixed(0)} W spare'
              : 'The array is just covering the house load',
          style: TextStyle(
            fontSize: 11,
            color: acPower != null && !coversLoad
                ? statusWarn(theme.isDark)
                : faint,
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
    required this.theme,
    required this.seedColor,
  });

  /// See [LivePowerCard.soc].
  final double? soc;

  /// See [LivePowerCard.theme].
  ///
  /// The track behind the charge bar is the per-theme part: `AppSurfaces.track`
  /// is *darker* than Dracula's page where it is lighter in light and dark.
  final AppTheme theme;

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(theme.isDark);
    // No reading means an empty track and `--`, not a zero-length fill and `0%`.
    // The track is already the visual language for "nothing here", so this needs
    // no new element: it is the same appearance as a pack at zero, except that
    // the number no longer claims a measurement.
    final clamped = soc?.clamp(0.0, 100.0);
    // The third of the three hand-picked lightnesses, and the one that misses AA
    // on Dracula — see the note on `_PowerFlow`'s accent above for the measured
    // numbers and for why the fix is a separate change.
    final accent = themeColor(
      seedColor: seedColor,
      lightness: theme.isDark ? 0.68 : 0.38,
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
            borderRadius: AppRadius.all(AppRadius.bar),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppSurfaces.track(theme)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    // Absent means no fill at all, rather than a fill of zero
                    // width: an empty `FractionallySizedBox` is still a widget
                    // doing layout work for a reading that does not exist.
                    widthFactor: (clamped ?? 0) / 100,
                    child: ColoredBox(color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: clamped == null
              ? 'State of charge: not reporting'
              : 'State of charge: ${clamped.toStringAsFixed(0)} percent',
          child: Text(
            clamped == null ? '--' : '${clamped.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: appPrimaryText(theme.isDark),
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
  /// This term's figure in watts, or `null` when there is no reading to print.
  final double? watts;
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
            // **`Flexible` plus `scaleDown`, and this is not decoration.**
            //
            // A non-flex child in a `Row` gets unbounded main-axis width, so this
            // figure could never shrink no matter how little room it had. On the
            // documented 381 dp viewport each of the three slots in the flow row is
            // roughly 89 dp, and a battery figure of `-1250` needs about that much
            // for a sign, four digits, the icon, the gaps and the unit at 24 sp.
            // Any system font scale above 1.0 pushed it over, and `RenderFlex`
            // draws the overflow stripe straight across the number.
            //
            // `scaleDown` and not `ellipsis`, for the same reason the energy
            // report readout is a `Wrap`: this project has shipped a truncated
            // figure twice -- `109....` and `239...` -- and both times
            // `flutter analyze`, a release build and every existing test passed.
            // A number scaled down is still readable; a cut-off number cannot be
            // told apart from a rounded one. The unit keeps its own size because
            // it is nowhere near the limit.
            //
            // `--` for no reading, matching `MetricGrid` and
            // `SystemStatusStrip`. A `0` here would be a measurement, and there
            // is not one.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  watts == null ? '--' : watts!.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: watts == null ? faint : color,
                  ),
                ),
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
    required this.theme,
    required this.seedColor,
  });

  final bool pzemStale;
  final String? ageLabel;

  /// See [LivePowerCard.theme].
  ///
  /// Needed here only for the icon's accent: `metricColor` takes an `AppTheme`
  /// because Dracula's purple needs its own HSL lightness. Everything else in
  /// this header is a caption or a status colour and passes `theme.isDark`.
  final AppTheme theme;

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.wb_sunny_rounded,
          size: 18,
          color: metricColor(
            seedColor: seedColor,
            index: 2,
            theme: theme,
          ),
        ),
        const SizedBox(width: 6),
        // Names the card, not the reading. "PV Output" appeared three times on
        // one card: here, directly under the big number, and again on the first
        // capsule. The capsule label is the one that has to be there, because
        // three identical tiles in a row are indistinguishable without it.
        //
        // **`Flexible`, because this `Text` could never shrink.** A non-flex child
        // in a `Row` is laid out at its intrinsic width, and the `Spacer` after it
        // absorbs whatever is left over, which is zero in exactly the case that
        // matters. Measured: "Live power" plus "Updated 12 minutes ago" is about
        // 229 dp at scale 1.0 against 304 dp of card content, and about 343 dp at
        // scale 1.5 -- so it overflowed from around 1.3 upwards, and the age label
        // is the half that gets cut, which silently removes the only liveness
        // indicator on the card.
        Flexible(
          child: Text(
            'Live power',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: faintColor(theme.isDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Always shown, not only when stale. There was no persistent indication
        // of liveness anywhere in the Overview, so a dashboard that had quietly
        // stopped updating looked exactly like a live one until something else
        // failed. Stale now means amber, fresh means quiet.
        if (ageLabel != null)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pzemStale ? Icons.warning_amber_rounded : Icons.schedule,
                  size: 12,
                  color: pzemStale
                      ? statusWarn(theme.isDark)
                      : faintColor(theme.isDark),
                ),
                const SizedBox(width: 4),
                // The age is the half that gives way. It is a caption and the
                // title is not, and this is the only liveness indicator on the
                // card, so it keeps its text for as long as it can. `Flexible`
                // plus `scaleDown` rather than `ellipsis` again: "Updated 12
                // minute..." is a worse thing to read than a smaller "12m ago".
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
                        color: pzemStale
                            ? statusWarn(theme.isDark)
                            : faintColor(theme.isDark),
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
