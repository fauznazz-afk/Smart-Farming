import 'package:flutter/material.dart';

import '../screens/dashboard/utils/design_tokens.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final Color? accentColor;
  final Color? secondaryColor;

  const BrandLogo({
    super.key,
    this.size = 52,
    this.showName = false,
    this.accentColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // **The wordmark's two colours are palette tokens now, and the second one
    // used to be a second green.** `#35A968` was a free-hand green in an app
    // whose green (`AppPalette.success`) means "a problem is absent" — exactly
    // the hue-collision rule `color_helpers.dart` spells out, broken by a
    // logo. `secondary` is the categorical blue, so the wordmark reads as the
    // brand accent plus a category rather than as two unrelated brand colours.
    //
    // Both parameters are still honoured: a caller that wants its own pair can
    // have one, and the defaults no longer contradict the palette.
    final primary = accentColor ?? AppPalette.primary;
    final secondary = secondaryColor ?? AppPalette.secondary;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // **No blur.** The brief bans soft shadows outright, so the logo carries
        // the stamped displacement like every other surface. A blurred halo
        // here was the last soft shadow in the app.
        boxShadow: AppShadows.stamped,
      ),
      child: Image.asset(
        'assets/energrow_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Logo EnerGrow',
      ),
    );

    if (!showName) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            // The display family at its display weight, rather than a literal
            // 25sp/700. `showName` is false at both call sites today, so this
            // branch is the one place the wordmark still renders by hand — which
            // is why it took the token rather than a second set of numbers.
            style: AppType.numeralLg,
            children: [
              TextSpan(
                text: 'Ener',
                style: TextStyle(color: primary),
              ),
              TextSpan(
                text: 'Grow',
                style: TextStyle(color: secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
