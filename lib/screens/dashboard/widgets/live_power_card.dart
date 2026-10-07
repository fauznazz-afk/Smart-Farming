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

    // The surplus, and the battery's own contribution, as two plain numbers, so
    // the verdict below states both rather than deriving one from the other.
    //
    // **The verdict used to be a function of the array and the house alone**, and
    // the card could therefore print "The array covers the house, 7 W spare" on
    // the same line as "Discharging -19 W". Each of those is true on its own and
    // together they say something neither says: the first reads as the array
    // carrying the house by itself, the second as an idle battery standing
    // alongside it. Measured on the test device on 2 October 2026, the surplus
    // was 7 W while the battery was delivering 19 W, so the array was the
    // *smaller* of the two contributors -- the opposite of what the sentence
    // implied. This is the `FEATURE.md` 18.8 class of defect: a widget that looks
    // as though it is saying one thing while it says another, with no exception
    // and nothing for `flutter analyze` to catch.
    //
    // `>` and not a sign test, deliberately. The sentence only has to mention the
    // battery when what the battery delivers is *larger* than the surplus; below
    // that the array genuinely is the larger contributor and the original sentence
    // was fair, so this does not add a clause to every dusk reading.
    //
    // `batteryPower!` is safe on this branch rather than merely convenient:
    // `discharging` is only ever true when `chargeState` was derived from a
    // non-null `batteryPower`, and `&&` short-circuits, so the bang is never
    // reached with a null.
    final spareWatts = knownShare ? solarForBar - loadForBar : 0.0;
    final batterySupplies = discharging && batteryPower!.abs() > spareWatts;

    // The other half of the same omission, and the louder one.
    //
    // **A shortfall the battery is covering is not a shortfall the user needs
    // warning about.** This card painted `statusWarn` on the sentence "The array
    // is not covering the house load right now" whenever the array came in under
    // the house, and on a battery-backed system that is not a fault -- it is the
    // design working. On the test device at 15:50 on 2 October 2026 the card read
    // `Solar 5 W / House 17 W / Discharging -30 W` with that sentence in amber:
    // the house was fully supplied, the array was not the supplier, and the card
    // was warning about it.
    //
    // The point is that the condition is *structurally guaranteed* to be true
    // every evening, which is what makes it a false alarm rather than a warning.
    // `AGENTS.md` already rejected the mirror image of this -- "a permanent green
    // 'semua normal' badge ... asserted a condition that is boring when true" --
    // and a warning that cannot stop being true has the same defect with the
    // opposite sign. Status colour means a condition, and a battery discharging at
    // dusk is not one.
    //
    // The wording stays parallel to the surplus branch on purpose, so both
    // battery-involved sentences have the same shape: what the array did, and what
    // the battery added. Neither claims where the power physically went.
    //
    // Scoped to `discharging` on purpose. If the array is short and the battery is
    // in standby, nothing is making the difference up, and the original amber
    // sentence is the correct and only warning on the card.
    final batteryMakesUp = discharging && !coversLoad;

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

    // The three slot labels, so the label block can be given one height for all of
    // them. See [_labelBlockHeight] for why that is needed, and for why the slot
    // width comes from a `LayoutBuilder` rather than from arithmetic on the screen
    // width: the card sits in a page whose padding, and this card's own, are two
    // more numbers that would have to be right.
    final solarLabel = 'Solar';
    final houseLabel = 'House';
    final batteryLabel = chargeState?.label ?? 'Battery';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The flow IS the hero now. It used to sit under a 48 px PV number that
        // said the same thing again as the first term, so the largest element on
        // the card was the least informative number on it — one reading, printed
        // twice, with the relationship between three readings shrunk underneath.
        //
        // **Equal slots until the labels say otherwise, then slots in proportion to
        // the labels.**
        //
        // Three `Expanded` children is the design: the flow reads as three equal
        // stations, and `mainAxisSize.min` used to let the widest term set the
        // width for all three. It also cannot hold "Discharging" on one line at
        // 2x -- 11 characters at 22 sp needs about 100 dp and a third of a 381 dp
        // card is 89 -- so the label had to wrap, and a single word wrapping breaks
        // mid-word. On the emulator it read `Dischargi / ng`.
        //
        // Three alternatives were rejected:
        //
        //  * Ellipsis, which is where this started. `Dis...` is not a direction.
        //  * Proportional slots *always*, which would double the battery slot at 1.0
        //    and quietly redesign the card at the scale almost everyone uses.
        //  * A soft hyphen in the string, which gives correct typography
        //    (`Dis-charging`) but changes the string a screen reader announces and
        //    the one `find.text` in the battery tests matches on.
        //
        // So the split is on whether the labels fit, which is measured rather than
        // assumed: at 1.0 the answer is yes and the card is laid out exactly as it
        // was, and at 2.0 the answer is no and the battery station gets the room
        // its own word needs. `Flexible` rather than `Expanded` in that branch,
        // because the whole point is that the three are no longer equal.
        LayoutBuilder(
          builder: (context, constraints) {
            // Two arrow glyphs, each 15 wide with 2 dp of padding either side.
            const arrow = 15 + 4;
            final fairShare = (constraints.maxWidth - 2 * arrow) / 3;
            final needed = _labelNaturalWidths(
              context,
              [solarLabel, houseLabel, batteryLabel],
            );
            final allLabelsFitOnOneLine = needed.every((w) => w <= fairShare);
            final total = needed.fold(0.0, (a, b) => a + b);
            final available = constraints.maxWidth - 2 * arrow;

            // **The width a slot will actually get, which is not the width it
            // asked for.**
            //
            // This is the second wrong attempt at this, and the emulator showed it.
            // `Flexible(flex:)` distributes the row in proportion to the flex
            // values, so when the labels together want more room than the row has,
            // *every* slot is shrunk proportionally -- including the longest one,
            // which is still the one that does not fit. Sizing the label block
            // against `needed[i] + 1` therefore reserved one line while the
            // paragraph got less than it needed, wrapped to a second line, and the
            // one-line block clipped it. The screen read `Dischargir`.
            //
            // The number that matters is `available * need / total`, which is the
            // share the row will hand this slot, and a line count measured against
            // anything else is a line count about a layout that does not exist.
            //
            // **Still keyed to the labels alone, on purpose.** Reallocating each
            // slot as `max(its label, its figure)` so the figures could claim
            // room was implemented and measured, and it moved the shared scale by
            // about 1% while breaking where the labels wrap -- ten tests in `the
            // battery state label is never amputated`. The labels dominate the
            // total demand, so the narrowest slot lands within a pixel or two of
            // where it already was. See [_sharedFigureScale].
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
                    // Half a pixel of slack, for the same rounding reason the
                    // date strip carries: a paragraph one rounding step wider than
                    // its box wraps, and a wrapped word breaks where it hurts most.
                    slotWidth: slotWidthAt(i) + 0.5,
                  ),
              ],
            );

            // A slot widget that is a third of the row at 1.0 and proportional to
            // the text at 2.0. `flex` is an int, so the widths are rounded -- at
            // these magnitudes a half-unit of flex is well under a pixel, and
            // `Flexible` distributes the remainder anyway.
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
                color: accent,
                isDark: theme.isDark,
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
                color: loadColor,
                isDark: theme.isDark,
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
                // Not `.abs()`. The Battery page prints the same figure with the
                // same sign, and two screens reporting different numbers for one
                // measurement is worse than an odd-looking minus. No explicit "+"
                // either, because the Battery page does not print one.
                watts: batteryPower,
                color: accent,
                isDark: theme.isDark,
                figureScale: figureScale,
              ),
              2,
            ),
          ],
            );
          },
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
              : batteryMakesUp
              ? 'The array is short, and the battery adds '
                    '${batteryPower!.abs().toStringAsFixed(0)} W'
              : !coversLoad
              ? 'The array is not covering the house load right now'
              : batterySupplies
              // Ahead of the surplus branch, and not after it. A battery that is
              // delivering more than the array has spare is the more surprising
              // fact of the two, and printing the surplus first would bury it
              // under the reassuring half of the sentence.
              ? 'The array covers the house, and the battery adds '
                    '${batteryPower!.abs().toStringAsFixed(0)} W'
              : spareWatts > 0.5
              ? 'The array covers the house, '
                    '${spareWatts.toStringAsFixed(0)} W spare'
              : 'The array is just covering the house load',
          style: TextStyle(
            fontSize: 11,
            // `!batteryMakesUp` on the warning, and it is the same fact as the
            // branch above it: a shortfall the battery is covering keeps the
            // ordinary faint text, because it is not a warning. A shortfall with
            // the battery in standby still gets the amber.
            color: acPower != null && !coversLoad && !batteryMakesUp
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
    // **Both labels are `Flexible`, and neither may be cut.**
    //
    // They were plain `Text` children, so each got unbounded main-axis width and
    // the pair could claim more than the row had. Measured on a 320 dp viewport at
    // a 3.0 scale, `Charge` and `80%` overflowed by 38 px and `RenderFlex` drew
    // the stripe. A percentage is not a word that can be shortened, and a stripe
    // across a charge figure is the same failure as a stripe across the power
    // figure -- so `Flexible` on both, and no `maxLines`, means they wrap instead
    // of being amputated.
    //
    // The bar stays `Expanded` and therefore takes what is left. A bar that gets
    // narrow is still a bar; a percentage that gets cut is a wrong number.
    return Row(
      children: [
        Flexible(
          child: Text(
            'Charge',
            style: TextStyle(fontSize: 11, color: faint),
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
                  // A groove: the lip shades the top, the floor is the token.
                  // The token is kept as a stop so the track is still exactly
                  // `AppSurfaces.track` where it meets the fill — Dracula's is
                  // the one darker than its own page, and the test pins that.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(
                            AppSurfaces.track(theme),
                            const Color(0xFF000000),
                            0.18,
                          )!,
                          AppSurfaces.track(theme),
                        ],
                      ),
                    ),
                  ),
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
        Flexible(
          child: Semantics(
            label: clamped == null
                ? 'State of charge: not reporting'
                : 'State of charge: ${clamped.toStringAsFixed(0)} percent',
            child: Text(
              clamped == null ? '--' : '${clamped.toStringAsFixed(0)}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: appPrimaryText(theme.isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// How many lines one flow-row label takes at the width its slot actually gets.
///
/// Measured rather than assumed, and **without a `maxLines` cap**, which is the
/// part that took two attempts. The first attempt laid the painter out with
/// `maxLines: 2` and read `computeLineMetrics().length`, then gave every label a
/// two-line block. The widget test caught it immediately, and the reason string
/// said why: at 2x on a 381 dp viewport "Discharging" was still drawn as `Dis…`,
/// because it needs three lines in a 89 dp slot, not two. A cap inside the
/// *measuring* code silently clamps the answer, which is the one place a cap must
/// not exist — and capping the widget to the same number would then have hidden it
/// again.
/// The style a flow-row label is actually painted with.
///
/// Resolved from the ambient `DefaultTextStyle` rather than written out, for the
/// same reason `DateStrip` resolves its own: the theme supplies `family: Roboto`
/// and `letterSpacing: 0.3`, and a hand-written `TextStyle(fontSize: 11)` is
/// missing both. The `DateStrip` version of this mistake shipped first and the
/// test caught it -- the strip measured every day name 0.9 px narrow and went on
/// clipping `Mon` and `Wed` at 2x. There is no reason to repeat it in a second
/// file, and copying the number would have been the mistake.
TextStyle _termLabelStyle(BuildContext context) => DefaultTextStyle.of(context)
    .style
    .copyWith(fontSize: 11)
    // The label is an annotation, not a heading, so the weight is left as the
    // theme has it. Setting one here would be a guess about which weight an
    // annotation wants, and it would be a fourth number to keep in step.
    ;

/// The width of one string on one line at the current text scale.
///
/// The single place a `TextPainter` is asked "how wide is this", so that every
/// measurement in this file resolves the same scaler and direction. The label
/// widths, the label block height and the flow-row solver all need this number
/// and none of them may compute their own -- a measurement that hand-writes the
/// style it is measuring is a copy, and this file has already produced four
/// bugs that way (see [_labelBlockHeight]).
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

/// The figure's own style, and the unit beside it.
///
/// **Defined once and used by both the widget and the measurement that sizes
/// it.** See [_naturalWidth] for why a hand-written copy of a style is a bug
/// waiting to happen here rather than a stylistic choice.
TextStyle _termFigureStyle({required Color color}) => TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w800,
  height: 1.0,
  color: color,
);

TextStyle _termUnitStyle({required Color color}) =>
    TextStyle(fontSize: 11, color: color);

/// The figure's text, as the card prints it.
///
/// `--` for no reading, matching `MetricGrid` and `SystemStatusStrip`. A `0` here
/// would be a measurement, and there is not one.
///
/// Shared with [_sharedFigureScale] so the string that was measured is provably
/// the string that gets drawn.
String? _figureText(double? watts) =>
    watts == null ? '--' : watts.toStringAsFixed(0);

/// The **one** scale all three flow-row figures are drawn at.
///
/// This is the fix for a device-found regression: each `_Term` carried its own
/// `FittedBox(scaleDown)`, so at a 2.0 system font on the Xiaomi 24090RA29G the
/// `250` in `Solar 250 W / House 17 W / Charging 93 W` drew visibly smaller and
/// raised above `17` and `93` -- it was the only one of the three wide enough to
/// need to shrink at all. Measured, the three were 11.3 / 16.9 / 29.8 px, a 2.6x
/// spread. The card's own comment says the row "reads as three equal stations",
/// and a figure at a different size reads as a different *quantity*.
///
/// ### The constraint that decides the size
///
/// **The figure gets half its slot, not the rest of it.** The figure and the
/// unit `W` are two `Flexible` siblings, so `Flex` divides what is left after the
/// icon and the gaps *equally*, whatever their natural widths. At 381 dp and 2.0,
/// slots of 87 / 87 / 137 px become flex shares of 34 / 34 / 59 px. Assuming
/// `slotWidth - 19` here overstates the room by exactly 2x, and the symptom of
/// getting that wrong is a scale too large to fit -- which leaves the `FittedBox`
/// to shrink anyway and so *reproduces the very difference being fixed*.
///
/// Text advance width is linear in font size, and the unit and figure share a
/// slot equally, so for one term:
///
/// ```text
///   s <= (slotWidth - icon - gaps) / 2 / max(w_fig, w_unit)
/// ```
///
/// and the shared scale is the smallest such `s`, capped at 1.0 so nothing is
/// ever enlarged. The unit scales with the figure, which keeps each station's
/// proportions and keeps the three identical.
///
/// ### What was tried and rejected: sizing the slots by figure demand too
///
/// The slots are allocated by *label* width, so `Solar` -- the shortest label --
/// gets the narrowest slot, and it is the one holding the three-digit `250`
/// while `Charging` gets 137 px for a two-digit `93`. That allocation is
/// inverted with respect to what the figures need, so reallocating each slot as
/// `max(its label, its figure)` and solving the scale against *that* allocation
/// looks like the real fix.
///
/// It was implemented and measured, and it is **not worth it**: the scale moved
/// from 0.2331 to 0.2359 -- about 1% -- because the labels, not the figures,
/// dominate the total demand. At 2.0 the three labels measure 111 / 111 / 178 px
/// into a 313 px row, so the label block overruns the row before any figure is
/// placed and the narrowest slot lands within a pixel or two of where it already
/// was. It also moved where the labels wrap, which broke ten existing tests in
/// `the battery state label is never amputated`.
///
/// The ceiling is the labels, then, and raising it means a layout change -- not
/// a scale change. Recorded rather than shipped.
///
/// **`FittedBox` deliberately stays.** Without it this function is only an
/// optimisation; with it, a slot too narrow even at this scale degrades to
/// shrinking rather than to a stripe across the number. That has shipped twice in
/// this app -- `109....` and `239...` -- and both times the toolchain was green.
double _sharedFigureScale(
  BuildContext context, {
  required List<double> slotWidths,
  required List<double?> watts,
  required Color color,
}) {
  const icon = 13.0;
  const gaps = 4.0 + 2.0;

  // Measured once, at scale 1. Every step below is arithmetic on these.
  final figureNeeds = [
    for (final w in watts)
      _naturalWidth(context, _figureText(w)!, _termFigureStyle(color: color)),
  ];
  final unitNeed = _naturalWidth(context, 'W', _termUnitStyle(color: color));

  var scale = 1.0;
  for (var i = 0; i < watts.length; i++) {
    // The share each of the two flexible children receives. Not
    // `slotWidth - icon - gaps`: see the note above.
    final share = (slotWidths[i] - icon - gaps) / 2;
    if (share <= 0) continue;
    final text = math.max(figureNeeds[i], unitNeed);
    if (text > 0) scale = math.min(scale, share / text);
  }
  return scale.clamp(0.0, 1.0);
}

/// Each label's width on one line, at the current text scale.
List<double> _labelNaturalWidths(BuildContext context, List<String> labels) {
  final style = _termLabelStyle(context);
  return [for (final label in labels) _naturalWidth(context, label, style)];
}

/// How many lines one flow-row label takes at the width its slot actually gets.
///
/// Measured rather than assumed, and **without a `maxLines` cap**, which is the
/// part that took two attempts. The first attempt laid the painter out with
/// `maxLines: 2` and read `computeLineMetrics().length`, then gave every label a
/// two-line block. The widget test caught it immediately, and the reason string
/// said why: at 2x on a 381 dp viewport "Discharging" was still drawn as `Dis…`,
/// because it needs three lines in a 89 dp slot, not two. A cap inside the
/// *measuring* code silently clamps the answer, which is the one place a cap must
/// not exist -- and capping the widget to the same number would then have hidden
/// it again.
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

/// The height every flow-row label block gets, so the three figures share a row.
///
/// The tallest label's line count, times one measured line's height at the same
/// scale. At 1.0 that is one line and the card is laid out exactly as it was
/// before; at 2.0 the battery label needs more, so all three blocks grow and the
/// figures below them stay on one line.
///
/// **The line height is measured with the resolved style, and getting that wrong
/// was the fourth bug in this one widget.** The probe used a hand-written
/// `const TextStyle(fontSize: 11)`, which has no `height` multiplier and no
/// family, so it answered 11 px where the paragraph the chip actually paints
/// needs 16 -- the theme sets `height: 1.4`. The block was therefore short by 45%
/// at *every* font scale, and a `SizedBox` that is too short does not overflow: it
/// silently fails to paint the rest of the text, with no stripe and no exception.
///
/// That is the same mistake four times over in three files now -- a measurement
/// that hand-writes the style it is measuring is a copy, and this repo has been
/// bitten by a stale copy three separate ways. The width measurement and the line
/// count both resolve the style; so does this.
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
    required this.isDark,
    this.labelHeight,
    this.figureScale = 1,
  });

  final IconData icon;
  final String label;

  /// A shared height for the label block, or `null` for the label's natural size.
  ///
  /// Set to the tallest of the three flow-row labels, so the figures underneath
  /// them share a baseline. See [_labelBlockHeight].
  final double? labelHeight;

  /// **The same value for all three terms, deliberately.**
  ///
  /// 1.0 unless a figure genuinely does not fit the slot the row hands it, in
  /// which case every figure is drawn at this fraction of 24 sp. The previous
  /// code gave each `_Term` its own `FittedBox` and let it settle at its own
  /// factor, which is what made `250` draw smaller than `17` and `93` on the
  /// device at a 2.0 system font. See [_solveFlowRow].
  final double figureScale;

  /// This term's figure in watts, or `null` when there is no reading to print.
  final double? watts;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(isDark);
    final labelText = Text(
      label,
      // **Two lines, and it is measured rather than assumed.** This was
      // `maxLines: 1` with `ellipsis`, and a comment that accepted the
      // consequence: "the label gets the full slot and ellipsises on its own if a
      // future one is longer still." On an emulator at a 2x system font scale it
      // produced `Dischar…` on the third term.
      //
      // A truncated state name is the one string on this card that cannot be
      // recovered by the reader, and it is the one the app is *least* allowed to
      // get wrong: `AGENTS.md` is explicit that the direction of the battery has
      // to be carried by the label, because a minus sign alone is not a
      // direction and the two are deliberately not interchangeable. A half-word
      // for a direction is the failure mode this whole module is built to avoid.
      //
      // Wrapping alone would have been worse, though, and that is why
      // [labelHeight] exists. The row is `CrossAxisAlignment.start`, so a
      // two-line third label would drop the *Discharging* figure one line below
      // the Solar and House figures and read as a rendering fault. The figures are
      // the content; the labels are the annotation, and the annotation is not
      // allowed to misalign the content.
      // **Unbounded, and that is the point.**
      //
      // The `maxLines` a label may use is decided once, by [_labelLineCount], from
      // the width its slot actually got and the user's actual text scale. Capping
      // it here as well would be a second, different answer to the same question:
      // the first attempt capped both, the measurement silently clamped to 2, and
      // the widget test reported the label drawn as `Dis…` at 2x. Two places
      // answering "how many lines" is one too many.
      //
      // The block is a `SizedBox` of the tallest label's height, so a label that
      // wrapped further than the measurement predicted would overflow visibly --
      // which is the correct failure. It is better than a silent one.
      style: _termLabelStyle(context).copyWith(color: faint),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The label sits above the number, not beside it. "Discharging" is eleven
        // characters and the slot is a third of the card, so beside-the-number it
        // forced the row wide enough to overflow; above it, the label gets the
        // full slot.
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
                  // `_figureText`, not an inline format, so the string the scale
                  // was solved against is provably the string drawn here.
                  _figureText(watts)!,
                  style: _termFigureStyle(
                    color: watts == null ? faint : color,
                  ).copyWith(fontSize: 24 * figureScale),
                ),
              ),
            ),
            const SizedBox(width: 2),
            // **`Flexible` on the unit too, and the comment that used to be here
            // was wrong.** It said the unit "keeps its own size because it is
            // nowhere near the limit". That was true at the 381 dp viewport with
            // the card rendered edge to edge, and false everywhere else: with the
            // dashboard's 24 dp page margin on each side the slot is 48 dp
            // narrower, and at a 2.5 or 3.0 system font an 11 sp `W` is wide
            // enough to be the thing that pushes the row over. It overflowed by
            // 3.7 px.
            //
            // The number beside it was already given a `FittedBox` for exactly
            // this reason, and the unit was left rigid on the assumption it would
            // never need one. A row whose only rigid parts are a 13 px icon and
            // two 2-4 px gaps cannot overflow at all, which is a property worth
            // more than the unit keeping its size — a scaled-down `W` is still
            // perfectly legible, and the number is what has to survive.
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
        //
        // **And `FittedBox(scaleDown)` rather than `ellipsis`, which is the second
        // half of a defect the comment above describes as being in the age label.**
        // Two things had to be true for the age label to be the victim: the title
        // had to be flexible, and the title had to be willing to shrink. It was
        // flexible but it was ellipsising, so once the dashboard's 24 dp page
        // margin took 48 dp off the card width -- which no test in this file
        // accounted for, because it rendered the card edge to edge -- the title
        // claimed the space and the device showed `Live po...`.
        //
        // A cut word is not a word. The title is a name rather than a reading, so
        // it is the right thing to scale: a slightly smaller `Live power` reads
        // perfectly well, and the age label keeps its own ellipsis as the thing
        // that gives way when the two genuinely cannot coexist. This is the same
        // reasoning as the figure's `FittedBox` below and for the same stated
        // reason: this project has shipped a truncated figure twice.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Live power',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: faintColor(theme.isDark),
              ),
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
