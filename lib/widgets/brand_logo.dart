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
    // **The wordmark is the accent plus a neutral.** Both defaults were once
    // *category* hues doing a *brand* job, which is the same mistake the file's
    // earlier note made about a second green: a colour that means something on
    // one screen is spending that meaning here.
    //
    // So `primary` is the app's one accent and `secondary` is
    // `AppSurfaces.onSurfaceVariant`. A wordmark in cyan and grey is a wordmark;
    // a wordmark in two chart hues is two charts with no axis.
    //
    // Both parameters are still honoured: a caller that wants its own pair can
    // have one, and the defaults no longer contradict the palette.
    final primary = accentColor ?? AppPalette.accent;
    final secondary = secondaryColor ?? AppSurfaces.onSurfaceVariant;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // **The same lift every other surface carries.** The logo used to take a
        // tier of its own; there is one lift in the system now, so it takes that
        // one rather than a fourth variant of the same idea.
        boxShadow: AppShadows.subtle,
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
