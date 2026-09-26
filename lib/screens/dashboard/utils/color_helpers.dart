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

/// How far apart each metric's hue is rotated from the accent.
///
/// Around 40 degrees, which is enough to tell green from amber from cyan at a
/// glance without any of them drifting so far that it stops looking like the
/// chosen accent. Every palette in the app is derived from one seed, so this is
/// the only lever that gives the PV, AC and battery pages distinct identities.
const double _hueStep = 0.11; // 360 * 0.11 ≈ 40 degrees

/// Creates the accent color for a given metric index and theme.
///
/// [index] used to be accepted and ignored, so every metric in the app rendered
/// in the same hue and the PV, AC and battery page headers were told apart only
/// by their icon. Rotating the hue per index is what the parameter always meant.
Color metricColor({
  required Color seedColor,
  required int index,
  required bool isDark,
}) {
  final base = HSLColor.fromColor(seedColor);
  return base
      .withHue((base.hue + index * _hueStep) % 1.0)
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
  final base = HSLColor.fromColor(seedColor);
  return base
      .withHue((base.hue + index * _hueStep) % 1.0)
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
/// mode against white, for text as small as 9dp. These two clear 5:1 on their
/// respective surfaces, and the difference is visible as legibility rather than
/// as a colour change.
const Color _faintDark = Color(0xFFA8B3AC);
const Color _faintLight = Color(0xFF6B7671);

Color faintColor(bool isDark) => isDark ? _faintDark : _faintLight;

/// Status colors, used instead of the raw Material `green`/`orange`/`red`.
///
/// Those are tuned for large fills, not for small text on a near-white
/// surface: `Colors.green` at 9dp measures about 2.3:1. These clear AA.
Color statusOk(bool isDark) =>
    isDark ? const Color(0xFF6DD58C) : const Color(0xFF2E7D32);

Color statusWarn(bool isDark) =>
    isDark ? const Color(0xFFFFCA6B) : const Color(0xFFB26500);

Color statusBad(bool isDark) =>
    isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);

/// A status color for an alert accent that is neither clearly good nor bad.
Color statusAlert(bool isDark) =>
    isDark ? const Color(0xFFFFAB80) : const Color(0xFFBF360C);
