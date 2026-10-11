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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: reading == null
          ? 'Sky: no reading'
          : 'Sky: ${reading.round()} lux, ${condition!.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                size: 19,
                color: AppPalette.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Sky',
                style: AppType.labelUppercase.copyWith(color: faintColor),
              ),
              const Spacer(),
              if (stale) ...[
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
          if (reading == null)
            Text(
              'No reading',
              style: AppType.bodySm.copyWith(color: faintColor),
            )
          else ...[
            // **The reading, in the sensor's own units.** No conversion and no
            // derived quantity: the number is what the greenhouse lux sensor
            // reported, and the sentence under it says what that means. A user
            // who trusts the gauge can check it against the value in the
            // environment grid on Hydroponics, which is the same number.
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
            const SizedBox(height: AppSpacing.sm),
            // **The condition carries the answer, and it is the largest thing on
            // the card after the number.** The question the card exists to answer
            // is "is it bright enough for the array to be doing something", and
            // five words in the answer's own slot is a stronger answer than a
            // figure in a unit the reader has to interpret.
            Text(
              condition!.label,
              style: AppType.labelUppercase.copyWith(
                color: skyConditionColor(condition),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // The bar is the fraction of one sun. It is driven by the same
            // conversion the card no longer shows, because a bar needs a bounded
            // quantity and "fraction of a clear noon" is exactly that — an
            // un-clamped reading of 200 000 lx overflows the track, and a bar
            // scaled by W/m2 directly is a number nobody can read off a track.
            // **`width: double.infinity`, and it is load-bearing rather than
            // tidy.** The column this sits in is `crossAxisAlignment: start`,
            // so a child with no intrinsic width does not stretch — the track
            // was sizing itself to its own child, which is a
            // `FractionallySizedBox` of 0.5376 × the card's width. The result
            // was a bar 208dp wide on a card 387dp *inside*, so every reading
            // drew a bar that looked full and a caption that said otherwise.
            //
            // Nothing caught it for a while: the bar never overflowed its track
            // (they were the same width), so `never draws wider than its track`
            // passed, and the percentage was only ever asserted as *text*. The
            // first widget test that read the bar's rendered width against the
            // track's found it.
            //
            // It is the same conversion the card no longer displays in units: a
            // fraction of one sun is a bounded thing to fill a track with, and
            // the track has to be the full width for the fraction to mean
            // anything.
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: AppSurfaces.track,
                borderRadius: BorderRadius.circular(AppRadius.bar),
                border: AppBorders.hairlineBorder,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.bar),
                child: FractionallySizedBox(
                  widthFactor: sunFraction(reading),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(AppRadius.bar),
                      boxShadow: AppShadows.glow(
                        AppPalette.primary,
                        strength: 0.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
