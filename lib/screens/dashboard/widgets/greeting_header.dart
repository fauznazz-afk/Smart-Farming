import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';

import 'package:flutter/material.dart';

import '../utils/date_helpers.dart';
import '../utils/design_tokens.dart';

/// Time-of-day greeting with the signed-in user's name and today's date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.displayName});

  final String displayName;

  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 15) return 'Good afternoon';
    if (now.hour < 18) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final glyph = appPrimaryText;
    return Row(
      children: [
        // **The brief's `avatar` component, and it is the only thing on the
        // Overview page allowed to wear the brand accent as a ring.** The spec is
        // `size 48px, rounded full, borderColor primary, borderWidth 2px, no
        // shadow` — and the brief lists "avatar ring" among the six sanctioned
        // uses of `{colors.primary}` alongside the CTA, the active tab and the
        // live dot.
        //
        // What this replaces was a 44dp circle filled with `AppSurfaces.track`
        // and outlined in the neutral hairline at 1.5px: a grey disc on a grey
        // page, distinguishable from the page only by 0.5px of width. The fill is
        // gone because the brief's avatar has none — the 2px ring is the whole
        // boundary, and a tinted disc behind it would be a second element saying
        // the same thing.
        //
        // Kept as a `BoxShape.circle` rather than an `AppRadius.round`: this is
        // the one place the shape is a circle by definition rather than by
        // radius, and `BoxDecoration.shape` is what a `borderRadius` cannot
        // express.
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppPalette.primary, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/user_icon.png',
              fit: BoxFit.contain,
              color: glyph,
              colorBlendMode: BlendMode.srcIn,
              semanticLabel: 'User profile',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greetingFor(now)}${displayName.isNotEmpty ? ', $displayName!' : '!'}',
                // `headlineLg`, not `numeralLg`: a greeting is a title, and the
                // brief's `headline-lg` is the style for one. Both are 24sp/900,
                // so this is a naming correction rather than a visual one — but
                // `numeralLg` carries tabular figures, and a greeting has no
                // column of digits to align.
                style: AppType.headlineLg.copyWith(color: appPrimaryText),
              ),
              Text(
                '${dayNameFull(now.weekday)}, ${now.day} ${monthName(now.month)} ${now.year}',
                style: AppType.labelMicro.copyWith(color: faintColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
