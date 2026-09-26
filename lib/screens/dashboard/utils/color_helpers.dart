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

/// Creates a metric color for the given index and theme.
Color metricColor({
  required Color seedColor,
  required int index,
  required bool isDark,
}) {
  final base = HSLColor.fromColor(seedColor);
  return base
      .withSaturation(isDark ? 0.64 : 0.72)
      .withLightness(isDark ? 0.68 : 0.40)
      .toColor();
}

/// Returns the hairline divider color for glass surfaces.
Color glassDividerColor({required bool isDark, double opacity = 0.08}) =>
    isDark
    ? Colors.white.withValues(alpha: opacity)
    : Colors.black.withValues(alpha: opacity);

/// Creates a strong metric color for the given index and theme.
Color strongMetricColor({
  required Color seedColor,
  required int index,
  required bool isDark,
}) {
  final base = HSLColor.fromColor(seedColor);
  return base
      .withSaturation(isDark ? 0.78 : 0.86)
      .withLightness(isDark ? 0.64 : 0.36)
      .toColor();
}