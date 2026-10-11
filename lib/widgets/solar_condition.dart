/// The card that reads the sky off the greenhouse lux sensor.
///
/// **The vocabulary and the thresholds live in `utils/solar_irradiance.dart`,
/// and the colour in `screens/dashboard/utils/color_helpers.dart`.** This file
/// is the presentation half and imports both; it re-exports neither, so
/// `dashboard_screen.dart`'s import resolves only `SolarConditionCard`.
///
/// ## Why lux and not W/m2
///
/// The first version of this card converted the reading to irradiance and showed
/// `412 W/m2`. It took the user about one look to say it was the wrong number to
/// show: a W/m2 figure is a quantity the dashboard's own PV card is the authority
/// on, and a user who wants to know whether the array is producing wants to know
/// what the *sky* is doing, not what the conversion of a photometric sensor to a
/// radiometric one estimates.
///
/// So the card shows what the sensor actually measured — lux — plus the
/// condition that number lands in. `luxToIrradiance` is still used, but only to
/// drive the brightness bar: the fraction of one sun is a well-defined thing to
/// fill a bar with, and it does not need to be spelled out in units to be
/// useful. The words do the answering.
library;

import 'package:flutter/material.dart';

import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';
import '../utils/solar_irradiance.dart';
import '../widgets/liquid_glass.dart';

/// A card reading the sky off the greenhouse lux sensor.
///
/// **On Overview and not on Hydroponics, because Overview is where the PV card
/// poses the question.** The PV card says "the array is producing that"; this
/// card says "and the sky is currently offering this". Those two belong together.
/// The Hydroponics tab owns the sensor's *numbers* — temperature, humidity, lux
/// in the environment grid — and a second reading of the same sensor one tab away
/// is a duplication.
class SolarConditionCard extends StatelessWidget {
  const SolarConditionCard({
    super.key,
    required this.lux,
    this.lastUpdate,
    this.staleMinutes = 10,
  });

  /// The greenhouse lux reading in lx.
  final double? lux;

  /// When that reading was taken, for the stale notice.
  final DateTime? lastUpdate;

  /// How old a reading may be before it is called stale.
  final int staleMinutes;

  @override
  Widget build(BuildContext context) {
    final reading = lux;
    final stale =
        lastUpdate != null &&
        DateTime.now().difference(lastUpdate!) >
            Duration(minutes: staleMinutes);
    final condition = reading == null ? null : skyConditionFor(reading);

    // **Through `AppCard.semanticLabel`, not a `Semantics` of our own.**
    //
    // `AppCard` already owns this: it wraps the card in a `Semantics` carrying
    // the label *with* `excludeSemantics: true`, because a container node on its
    // own does not stop a screen reader walking the children — the reader would
    // get the summary and then go on to read every `Text` underneath it. A
    // hand-rolled `Semantics(container: true, label: ...)` around the card omits
    // the exclusion, so the summary competes with the tree instead of replacing
    // it. Two other cards in this app already pass `semanticLabel`; this is the
    // third, and it is the same call rather than a second way of doing it.
    // **The reading is on the RIGHT of the header row, not on a line of its
    // own below it.** The card used to be a single left-aligned column: a header
    // row, the figure, the condition, the bar. On a 411 dp phone that is four
    // lines of content in a card 387 dp wide, and the figure — the one thing on
    // it worth reading — occupied about a fifth of the width with 300 dp of bare
    // card to its right. That is the "banyak space kosong" the user reported, and
    // it is a layout claim rather than a matter of taste: a card whose content
    // fills a third of its own width is not a card, it is a paragraph.
    //
    // So the header row now carries the figure on its trailing edge, baseline-
    // aligned with the condition, and the two halves are given a `Spacer` rather
    // than each taking `MainAxisSize.min` in a column that grows downward. Same
    // information, same tokens, one line shorter and roughly twice the density.
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: reading == null
          ? 'Sky: no reading'
          : 'Sky: ${reading.round()} lux, ${condition!.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The sun glyph is the accent. It was `AppPalette.primary` — lime — which
              // is a *chart-series* colour, and a chart series is data. An icon
              // in a label row is chrome, and chrome has one colour. The same
              // hue also fills the brightness bar below, which is the one thing
              // on the card that is a meter, so the glyph and the meter now
              // agree with each other as well as with the rest of the app.
              const Icon(
                Icons.wb_sunny_rounded,
                size: 20,
                color: AppPalette.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              // **The left half is the *name*, the right half is the *reading*.**
              // `Expanded` on the label column rather than `Spacer` between
              // fixed pieces, because the condition label is variable-width —
              // `Heavily overcast` is nearly twice `Clear sky` — and a `Spacer`
              // would let the figure slide left or right depending on which one
              // the card happened to be showing.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sky',
                      style: AppType.labelUppercase.copyWith(color: faintColor),
                    ),
                    const SizedBox(height: 2),
                    // **The condition is the answer, and it sits directly under
                    // the label it qualifies.** The question the card exists to
                    // answer is "is it bright enough for the array to be doing
                    // something", and the words that answer it are worth more
                    // than a second line of figure.
                    Text(
                      reading == null ? 'No reading' : condition!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.labelUppercase.copyWith(
                        color: reading == null
                            ? faintColor
                            : skyConditionColor(condition!),
                      ),
                    ),
                  ],
                ),
              ),
              if (reading != null) ...[
                const SizedBox(width: AppSpacing.sm),
                // **The reading, in the sensor's own units.** No conversion and
                // no derived quantity: the number is what the greenhouse lux
                // sensor reported. A user who trusts the gauge can check it
                // against the value in the environment grid on Hydroponics,
                // which is the same number.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${reading.round()}',
                      style: AppType.numeralLg.copyWith(color: appPrimaryText),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'lx',
                      style: AppType.labelMicro.copyWith(color: faintColor),
                    ),
                  ],
                ),
              ],
              if (stale) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.schedule, size: 14, color: statusWarn),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'stale',
                  style: AppType.labelMicro.copyWith(color: statusWarn),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _BrightnessBar(fraction: sunFraction(reading ?? 0)),
        ],
      ),
    );
  }
}

/// The bar: how much of one sun the sky is currently offering.
///
/// **Extracted because the empty state needs one too.** The card used to draw
/// the bar only when there was a reading, so a card whose sensor had never
/// reported was a header row and nothing else — a short strip of card with a
/// hole where the instrument should be. The track at rest reads as *nothing to
/// report yet*, which is what is true, and it keeps the card the same shape in
/// every state so the page does not jump when the sensor comes alive.
///
/// The bar is still driven by `sunFraction`, the conversion the card no longer
/// prints in units: a fraction of one sun is a bounded quantity to fill a
/// bounded track with. An un-clamped 200 000 lx reading would overflow it.
///
/// **`width: double.infinity`, and it is load-bearing rather than tidy.** The
/// column this sits in is `crossAxisAlignment: start`, so a child with no
/// intrinsic width does not stretch — the track was sizing itself to its own
/// child, which is a `FractionallySizedBox` of 0.5376 × the card's width. The
/// result was a bar 208 dp wide on a card 387 dp *inside*, so every reading drew
/// a bar that looked full and a caption that said otherwise.
///
/// Nothing caught it for a while: the bar never overflowed its track (they were
/// the same width), so `never draws wider than its track` passed, and the
/// percentage was only ever asserted as *text*. The first widget test that read
/// the bar's rendered width against the track's found it.
class _BrightnessBar extends StatelessWidget {
  const _BrightnessBar({required this.fraction});

  /// The fraction of one sun, already clamped by `sunFraction`.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 10,
      decoration: BoxDecoration(
        color: AppSurfaces.track,
        borderRadius: BorderRadius.circular(AppRadius.bar),
        border: AppBorders.hairlineBorder,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.bar),
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: DecoratedBox(
            // **The fill is the accent, and the glow is the only glow in the app.**
            //
            // It was lime, matching the sun glyph above it — which is the reason
            // that pairing was worth breaking: the two were consistent with each
            // other and inconsistent with every other card on the dashboard.
            // `AppShadows.glow` is reserved for a meter fill, and a meter fill is
            // the accent; `design_tokens.dart` says so and this is now the only
            // place that obeys it.
            decoration: BoxDecoration(
              color: AppPalette.error,
              borderRadius: BorderRadius.circular(AppRadius.bar),
              boxShadow: AppShadows.glow(AppPalette.error, strength: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
