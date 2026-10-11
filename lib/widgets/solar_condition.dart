/// The card that renders a solar reading from the greenhouse lux sensor.
///
/// **The maths and the vocabulary live in `utils/solar_irradiance.dart`, and
/// the colour in `screens/dashboard/utils/color_helpers.dart`.** This file is
/// the presentation half and imports both; it re-exports neither, so
/// `dashboard_screen.dart`'s `import '../widgets/solar_condition.dart';` keeps
/// resolving `SolarConditionCard` and nothing else leaks out of it.
///
/// The conversion, the thresholds and why they land where they do are documented
/// at length on the util, where a test can reach them without a widget.
library;

import 'package:flutter/material.dart';

import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';
import '../utils/solar_irradiance.dart';
import '../widgets/liquid_glass.dart';

/// A card reading the sky off the greenhouse lux sensor.
///
/// **Its own card rather than a line in the environment grid, because it answers
/// a different question.** The grid says what the sensor measured; this says
/// what that means for the solar array today, and it needs the lux figure, the
/// conversion and the condition side by side to say it. It also gives the
/// dashboard a second use for a sensor that was previously only a number in a
/// list.
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
    // **Through `AppCard.semanticLabel`, not a `Semantics` of our own.**
    //
    // `AppCard` already owns this: it wraps the card in a `Semantics` carrying the
    // label *with* `excludeSemantics: true`, because a container node on its own
    // does not stop a screen reader walking the children — the reader would get
    // the summary and then go on to read every `Text` underneath it. A hand-rolled
    // `Semantics(container: true, label: ...)` around the card omits the exclusion,
    // so the summary competes with the tree instead of replacing it. Two other
    // cards in this app already pass `semanticLabel`; this is the third, and it is
    // the same call rather than a second way of doing it.
    return AppCard(
      padding: const EdgeInsets.all(12),
      semanticLabel: reading == null
          ? 'Sun: no reading'
          : 'Sun: ${luxToIrradiance(reading).round()} W/m², '
                '${skyConditionFor(reading).label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 19,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Sun',
                style: AppType.labelUppercase.copyWith(color: faintColor),
              ),
              const Spacer(),
              if (stale) ...[
                Icon(Icons.schedule, size: 14, color: statusWarn),
                const SizedBox(width: 4),
                Text(
                  'stale',
                  style: AppType.labelMicro.copyWith(color: statusWarn),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (reading == null)
            Text(
              'No reading',
              style: AppType.bodySm.copyWith(color: faintColor),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${luxToIrradiance(reading).round()}',
                  style: AppType.numeralLg.copyWith(color: appPrimaryText),
                ),
                const SizedBox(width: 4),
                Text(
                  'W/m²',
                  style: AppType.labelMicro.copyWith(color: faintColor),
                ),
              ],
            ),
          const SizedBox(height: 4),
          if (reading != null) ...[
            Text(
              skyConditionFor(reading).label,
              style: AppType.labelUppercase.copyWith(
                color: skyConditionColor(skyConditionFor(reading)),
              ),
            ),
            const SizedBox(height: 10),
            // The bar is the fraction of one sun. Lime fill with a glow, because
            // this is the one place the app reports the sun itself, and the
            // track is the depressed recipe from the brief.
            Container(
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
            const SizedBox(height: 4),
            Text(
              '${(sunFraction(reading) * 100).round()}% of a clear noon',
              style: AppType.labelMicro.copyWith(color: faintColor),
            ),
          ],
        ],
      ),
    );
  }
}
