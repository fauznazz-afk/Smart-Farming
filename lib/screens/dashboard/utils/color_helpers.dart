import 'package:flutter/material.dart';

/// Creates a theme color with adjusted lightness and saturation.
Color themeColor({
  required Color seedColor,
  required double lightness,
  double saturation = 0.62,
}) {
  final hsl = HSLColor.fromColor(seedColor);
  return hsl
      .withSaturation(saturation.clamp(0.0, 1.0))
      .withLightness(lightness.clamp(0.0, 1.0))
      .toColor();
}

/// Creates the accent color for a metric, in the same hue as the theme.
///
/// [index] is accepted and deliberately ignored. It used to rotate the hue by
/// 40 degrees per index, so the PV, AC and battery pages each got a different
/// colour for the same accent. That was tried because the pages were hard to
/// tell apart, and it was reverted: a colour the user did not choose is a
/// colour they cannot predict, and the app looked arbitrary rather than themed.
///
/// The pages are told apart by their title and icon, which is unambiguous. If
/// per-page colour is ever wanted, it should be a setting the user picks, not a
/// default that silently changes what "Ocean cyan" means.
Color metricColor({
  required Color seedColor,
  required int index,
  required bool isDark,
}) {
  return HSLColor.fromColor(seedColor)
      .withSaturation(isDark ? 0.64 : 0.72)
      .withLightness(isDark ? 0.68 : 0.40)
      .toColor();
}

/// The stronger sibling of [metricColor], for values that need to carry weight.
Color strongMetricColor({
  required Color seedColor,
  required int index,
  required bool isDark,
}) {
  return HSLColor.fromColor(seedColor)
      .withSaturation(isDark ? 0.78 : 0.86)
      .withLightness(isDark ? 0.64 : 0.36)
      .toColor();
}

/// Returns the hairline divider color for glass surfaces.
Color glassDividerColor({required bool isDark, double opacity = 0.08}) =>
    isDark
    ? Colors.white.withValues(alpha: opacity)
    : Colors.black.withValues(alpha: opacity);

/// The color for secondary text: units, captions, timestamps.
///
/// The pair this replaces, `Colors.white54` on dark and `Colors.black45` on
/// light, fails WCAG AA on the surfaces actually used here — about 3.4:1 in light
/// mode against white, for text as small as 9dp.
///
/// The light value was `0xFF6B7671` and was still wrong: measured against the
/// glass card fill `#F2F5F3` it is 4.29:1, and these captions really are 9 to
/// 11dp. `0xFF606A65` measures 5.11:1 on the same surface. The dark value clears
/// 7.5:1 and was already fine. `test/color_helpers_test.dart` checks all four
/// against the real surfaces, so this cannot silently regress again.
const Color _faintDark = Color(0xFFA8B3AC);
const Color _faintLight = Color(0xFF606A65);

Color faintColor(bool isDark) => isDark ? _faintDark : _faintLight;

/// Status colors, used instead of the raw Material `green`/`orange`/`red`.
///
/// Those are tuned for large fills, not for small text on a near-white
/// surface: `Colors.green` at 9dp measures about 2.3:1. These clear AA.
///
/// The light values were originally `0xFF2E7D32` and `0xFFB26500`, and the amber
/// one was the worst thing in this file: 4.02:1 on the glass card fill, well
/// under the 4.5:1 that WCAG AA requires for text this small. `0xFF9A5500`
/// measures 5.21:1 and still reads as amber rather than brown. Green was raised
/// to `0xFF2A7530` for margin, from 4.67:1 to 5.19:1.
Color statusOk(bool isDark) =>
    isDark ? const Color(0xFF6DD58C) : const Color(0xFF2A7530);

Color statusWarn(bool isDark) =>
    isDark ? const Color(0xFFFFCA6B) : const Color(0xFF9A5500);

Color statusBad(bool isDark) =>
    isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);

/// A status color for an alert accent that is neither clearly good nor bad.
Color statusAlert(bool isDark) =>
    isDark ? const Color(0xFFFFAB80) : const Color(0xFFBF360C);
