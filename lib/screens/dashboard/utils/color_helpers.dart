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

/// The outline around a glass card, tinted with the theme accent.
///
/// It was a neutral white or black hairline, so a card's contents followed the
/// accent the user picked while its edge did not: in an amber theme a card held
/// amber numbers inside a cold grey frame, which is what made the palette read
/// as two systems rather than one.
///
/// [accent] is the theme's `colorScheme.primary`, not the raw seed. That matters,
/// because `ColorScheme.fromSeed` maps the seed to a tonal colour chosen to stay
/// legible on the surface, so the border cannot drift out of contrast the way a
/// bare seed would at the darker and lighter ends of the palette. It is also why
/// the card needs no new parameter: the accent is already in the theme, and
/// threading a `seedColor` through every call site would only let the two
/// disagree later.
Color glassBorderColor({required Color accent, required bool isDark}) =>
    accent.withValues(alpha: isDark ? 0.30 : 0.28);

/// Alarm severity, for the alarm history list.
///
/// These were a second, unpinned red and amber living one file away from
/// [statusBad] and [statusWarn], and both light values failed WCAG AA as the
/// 11 to 13dp text they are used at: `0xFFF57C00` measured 2.44:1 and
/// `0xFFD32F2F` measured 4.50:1. The AA work was done once, in this file, and
/// four call sites outside it did not adopt it. Duplicating the palette is what
/// let the two drift, so these now resolve to the pinned values instead of
/// carrying their own.
///
/// The icon circle behind each row still uses a wash of the same colour, so the
/// critical row reads red and the warning row reads amber exactly as before.
Color alarmCritical(bool isDark) => statusBad(isDark);

Color alarmWarning(bool isDark) => statusWarn(isDark);

/// The color for secondary text: units, captions, timestamps.
///
/// The pair this replaces, `Colors.white54` on dark and `Colors.black45` on
/// light, fails WCAG AA on the surfaces actually used here — about 3.4:1 in light
/// mode against white, for text as small as 9dp.
///
/// The light value was `0xFF6B7671` and was still wrong: measured against the
/// glass card fill `#F2F5F3` it is 4.29:1, and these captions really are 9 to
/// 11dp. The dark value clears 6.4:1 and was already fine.
///
/// **The light value moved a second time, and the reason is worth recording
/// because the test that should have caught it did not.** `0xFF606A65` was
/// measured against `0xFFF1F4F2`, which is the *pre-restyle* page colour. The
/// soft-UI work darkened the page to `0xFFE1E7E4` so the light half of every
/// shadow pair would have somewhere to be lighter to, and this value was not
/// re-measured against the new one. On the page that actually renders it is
/// **4.47:1** — under AA for the 9 to 11dp text it is used at. It is now
/// `0xFF5F6964`, which is 4.56:1 on the real page.
///
/// The change is 1.3% darker and was found by scaling every channel by 0.987,
/// not by moving HSL lightness. HSL is the obvious tool here and it is the
/// wrong one: stepping lightness on this desaturated green moved its hue from
/// 150.00° to 146.67°, and a caption colour that shifts hue when you darken it
/// is a caption colour that will read warm next to a green theme.
const Color _faintDark = Color(0xFFA8B3AC);
const Color _faintLight = Color(0xFF5F6964);

Color faintColor(bool isDark) => isDark ? _faintDark : _faintLight;

/// Status colors, used instead of the raw Material `green`/`orange`/`red`.
///
/// Those are tuned for large fills, not for small text on a near-white
/// surface: `Colors.green` at 9dp measures about 2.3:1. These clear AA.
///
/// The light values were originally `0xFF2E7D32` and `0xFFB26500`, and the amber
/// one was the worst thing in this file: 4.02:1 on the glass card fill, well
/// under the 4.5:1 that WCAG AA requires for text this small. `0xFF9A5500`
/// still reads as amber rather than brown. Green was raised to `0xFF2A7530` for
/// margin.
///
/// **Red and orange were re-measured for the same reason as [faintColor] and
/// moved for the same reason.** They were tuned against `0xFFF1F4F2`; the page
/// is now `0xFFE1E7E4`, and on it they measured 4.48:1 and 4.47:1. Both are now
/// channel-scaled rather than lightness-stepped — see the note on
/// [_faintLight] for why that distinction is not pedantic — which is a 1.1% and
/// 1.3% darkening and lands them at 4.56:1. Green and amber already cleared on
/// the real page (4.55 and 4.56) and are untouched.
///
/// These are measured, and a value tuned against a surface the app no longer
/// paints is not tuned at all. `test/color_helpers_test.dart` now reads its
/// surface list out of `AppSurfaces`, so that mistake cannot be made a third
/// time.
Color statusOk(bool isDark) =>
    isDark ? const Color(0xFF6DD58C) : const Color(0xFF2A7530);

Color statusWarn(bool isDark) =>
    isDark ? const Color(0xFFFFCA6B) : const Color(0xFF9A5500);

Color statusBad(bool isDark) =>
    isDark ? const Color(0xFFFF8A80) : const Color(0xFFC42828);

/// A status color for an alert accent that is neither clearly good nor bad.
Color statusAlert(bool isDark) =>
    isDark ? const Color(0xFFFFAB80) : const Color(0xFFBD350C);
