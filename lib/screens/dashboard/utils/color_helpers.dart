import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Dracula's purple, `#BD93F9`, and the seed the Dracula preset is built on.
///
/// **Dracula's own purple already clears AA on every surface in the theme, and
/// that is the finding that makes the preset affordable.** Measured against the
/// Dracula ramp, at full opacity:
///
/// | surface            | ratio  | | surface      | ratio  |
/// |--------------------|--------|-|--------------|--------|
/// | page `#282A36`     | 5.90:1 | | input `#21222C` | 6.55:1 |
/// | chrome `#343746`   | 4.89:1 | | track `#1E1F29` | 6.78:1 |
///
/// 4.89 on the chrome step is the binding one, because chrome is the lightest
/// surface in the ramp — 0.0390 of relative luminance against the page's
/// 0.0237 — so anything that clears it clears the rest. So the seed is
/// Dracula's palette value verbatim and is not re-derived.
///
/// **The pipeline is what breaks it, not the colour.** Carried through the
/// existing accent functions as a plain dark-mode seed it comes out as
/// `#A479E2` at **4.35:1** on the page and 3.60:1 on chrome, and
/// `strongMetricColor` gives `#975CEB` at 3.42:1, which is under AA by a mile.
/// Through `ColorScheme.fromSeed` it is worse still — primary lands on
/// `#6B538C`, a colour that is both far too dark and visibly not Dracula
/// purple, and the reason is that Material's tonal mapping darkens a seed to
/// stay legible on a *light* surface, which is exactly the wrong direction here.
///
/// The other Dracula hues were measured on `#282A36` for the same comparison:
/// green 8.90:1, cyan 8.03:1, orange 7.22:1, pink 5.18:1 — all compliant, and
/// all rejected as the accent anyway. Purple is what people mean when they say
/// "Dracula", and picking green would be a second place where the app decides a
/// colour on the user's behalf.
const Color draculaAccent = Color(0xFFBD93F9);

/// The HSL lightness Dracula's accent needs, and why it is not `0.68`.
///
/// **HSL lightness is not perceptual across hues, and this is the whole reason
/// a Dracula accent has to be derived at all.** At the dark theme's lightness of
/// 0.68 the app's default green measures 8.98:1 on Dracula's page while
/// Dracula's purple measures 4.35:1 — the same number, a factor of two apart,
/// because green carries far more luminance than purple does at equal HSL
/// lightness. Any single lightness that satisfies one hue breaks another, which
/// is the same trap as the per-index hue rotation this file already reverted:
/// a formula that is right on average and wrong for the colour in front of it.
///
/// So the lightness is per theme and the *ratio* is asserted rather than the
/// hex. `0.78` is the lowest Dracula purple lightness whose worst surface is
/// comfortably clear of AA; at `0.74` it is 4.62 on chrome, a margin of 0.12,
/// and this repo has a documented history of values that cleared AA by less
/// than 0.2 and then failed the next time a surface moved.
const double _draculaMetricLightness = 0.78;

/// `0.82` for the strong variant, and the relationship inverts here.
///
/// The dark theme makes `strongMetricColor` *darker* than `metricColor` (0.64
/// against 0.68) on the reasoning that a more saturated colour of lower
/// lightness reads heavier. That does not work in Dracula, because purple is
/// already at the bottom of the useful range: the strongest purple that still
/// clears AA on chrome at the metric's saturation is `#BF9BF3` at 5.16:1,
/// which is *less* contrasty than the metric colour's 5.45 and would make a
/// hero value quieter than an ordinary one. So the strong variant goes up in
/// lightness instead, and it is pinned on the property that actually matters —
/// greater worst-case contrast than the metric colour, not a lightness
/// relationship that only holds for two of the three themes. `0.82` at
/// saturation 0.90 is `#CAA8FA`: 7.12:1 on the page, **5.89:1 on chrome**, the
/// best clearance of the pair, against AA's 4.5.
const double _draculaStrongLightness = 0.82;

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

/// The accent for a **graphical object** — an icon, a dot, a bar, an indicator —
/// as opposed to text or a value.
///
/// **This exists because 1.4.11 and 1.4.3 ask for different things.** Text needs
/// 4.5:1; a graphical object that carries meaning needs 3:1. [metricColor] is
/// built for text, and measured against the light page it does not reach 3:1 for
/// three of the four accents the user can pick:
///
/// | accent | `metricColor` on the light card | first lightness that clears 3:1 |
/// |---|---|---|
/// | EnerGrow green | 2.28:1 | 0.34 |
/// | Solar amber | 2.88:1 | 0.39 |
/// | Ocean cyan | 2.16:1 | 0.33 |
/// | Forest teal | 2.21:1 | 0.33 |
///
/// **Why not just darken `metricColor`.** Two reasons, and the second is the
/// one that decides it. First, a fixed HSL lightness cannot serve all hues —
/// amber needs 0.39 and cyan needs 0.33, so any single value that clears one
/// overshoots the other, which is the same non-perceptual-lightness trap
/// [metricColor] already documents for Dracula. Second, and more decisively:
/// darkening `metricColor` would change every metric *value* in the app, which
/// is a visible restyle of the whole product dressed up as a contrast fix. The
/// defect is in the graphical uses; the surgical fix is in the graphical uses.
///
/// Dark and Dracula reuse their existing steps, measured: light-dark `metricColor`
/// is 10.3:1 to 10.7:1 and Dracula's is 5.45:1, so both clear 3:1 with room and
/// re-stepping them would be changing values that are already correct.
const double _graphicLightness = 0.32;

Color metricGraphic({
  required Color seedColor,
  required int index,
  required AppTheme theme,
}) {
  if (!theme.isDark) {
    return HSLColor.fromColor(seedColor)
        .withSaturation(0.72)
        .withLightness(_graphicLightness)
        .toColor();
  }
  return metricColor(seedColor: seedColor, index: index, theme: theme);
}

/// The ink to put **on top of** an accent fill, chosen so it clears WCAG AA.
///
/// **Why this is a function and not a constant.** The app's accent fills are
/// light in every dark theme and the Dracula preset's is lighter still, so
/// `Colors.white` — the obvious choice and the one this button used — measures
/// 2.16:1 on Dracula's `#C1A3EB` and is under the 3:1 that WCAG 1.4.11 asks of
/// a control. A dark ink measures 7.81:1 on the same fill. But a constant dark
/// ink is wrong too: `main.dart`'s `filledButtonTheme` derives its own label
/// colour from the fill's lightness for exactly this reason, and a second,
/// independent rule in a different file is how the two drift.
///
/// So this picks by luminance rather than by theme, which means it stays correct
/// if a fourth accent or a fourth theme lands. The 0.5 pivot is the point where
/// white and this ink give the same ratio, so either choice is at least as good
/// as the other at the crossover.
const Color _darkInkOnAccent = Color(0xFF10201A);

Color onPrimaryInk(Color fill) =>
    fill.computeLuminance() > 0.18 ? _darkInkOnAccent : Colors.white;

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
///
/// **The brightness parameter is an [AppTheme] and not a `bool`, and the accent
/// is the one reason that change was needed.** The text and status colours in
/// this file still take a `bool isDark`, because they are genuinely shared
/// between the two dark themes and duplicating them would protect nothing — see
/// [AppTheme.isDark] for the measurement. The accent is not shared: Dracula
/// needs a different HSL lightness for purple than dark does for any hue, and
/// a boolean has nowhere to put that. Taking [AppTheme] here also means a call
/// site cannot reach for `isDark: true` and silently get a colour that measures
/// 4.35:1, which is what the boolean version would have let it do the first
/// time somebody turned the preset on.
Color metricColor({
  required Color seedColor,
  required int index,
  required AppTheme theme,
}) {
  final hsl = HSLColor.fromColor(seedColor);
  return switch (theme) {
    // 0.64 saturation is the dark theme's own value, reused so that a Dracula
    // accent differs from a dark one in lightness alone and the hue
    // round-trip can be asserted at the same 0.5 degree tolerance.
    AppTheme.dracula => hsl
        .withSaturation(0.64)
        .withLightness(_draculaMetricLightness)
        .toColor(),
    AppTheme.dark => hsl.withSaturation(0.64).withLightness(0.68).toColor(),
    AppTheme.light => hsl.withSaturation(0.72).withLightness(0.40).toColor(),
  };
}

/// The stronger sibling of [metricColor], for values that need to carry weight.
///
/// Takes an [AppTheme] for the same reason and with the same caveat: read
/// [_draculaStrongLightness] before changing anything, because the ordering
/// relative to `metricColor` is deliberately different in Dracula and asserting
/// it as a lightness comparison would be asserting a property of two themes and
/// not the third.
Color strongMetricColor({
  required Color seedColor,
  required int index,
  required AppTheme theme,
}) {
  final hsl = HSLColor.fromColor(seedColor);
  return switch (theme) {
    AppTheme.dracula => hsl
        .withSaturation(0.90)
        .withLightness(_draculaStrongLightness)
        .toColor(),
    AppTheme.dark => hsl.withSaturation(0.78).withLightness(0.64).toColor(),
    AppTheme.light => hsl.withSaturation(0.86).withLightness(0.36).toColor(),
  };
}

/// The accent a preset theme paints with, or `null` when the user's own seed
/// applies.
///
/// Returning `null` rather than a colour is what keeps the two cases from being
/// confusable: `presetAccent(theme) ?? seedColor` cannot disagree with itself,
/// whereas storing an accent alongside a preset would allow a Dracula theme with
/// a green accent, which is not a preset and not the app's dark mode either.
Color? presetAccent(AppTheme theme) =>
    theme.usesPresetAccent ? draculaAccent : null;

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
///
/// **There is deliberately no Dracula variant, and the reason is measured.** The
/// dark value `0xFFA8B3AC` reads 6.58:1 on Dracula's page `#282A36` and 5.45:1
/// on its chrome step, so it clears AA on the whole ramp unchanged and a second
/// copy would be protecting nothing. This function therefore still takes a
/// `bool isDark`, and a Dracula call site passes `theme.isDark` — the enum, not
/// a literal. If a Dracula-specific caption colour is ever added, the
/// measurement that justified it belongs here first, because a duplicated
/// palette is precisely what let the light values drift for two commits while
/// every test stayed green.
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
///
/// **No Dracula variants either, and this is the one place where the choice was
/// closest.** Dracula's own palette has a red `#FF5555` and a comment `#6272A4`
/// that were measured at 4.53:1 and 3.03:1 on `#282A36`, so the first instinct —
/// take the palette's own colours — fails for the red on chrome (3.75:1) and
/// fails badly for the comment. The app's own `statusBad` `#FF8A80` is 6.24:1 on
/// the page and 5.17:1 on chrome, and `statusOk` 7.83 and 6.48, so every status
/// colour already beats both of the Dracula values it would have replaced. That
/// is a second, independent reason not to swap the palette wholesale: Dracula
/// is a *surface* theme, and its text palette is the app's, not its own.
Color statusOk(bool isDark) =>
    isDark ? const Color(0xFF6DD58C) : const Color(0xFF2A7530);

Color statusWarn(bool isDark) =>
    isDark ? const Color(0xFFFFCA6B) : const Color(0xFF9A5500);

Color statusBad(bool isDark) =>
    isDark ? const Color(0xFFFF8A80) : const Color(0xFFC42828);

/// A status color for an alert accent that is neither clearly good nor bad.
Color statusAlert(bool isDark) =>
    isDark ? const Color(0xFFFFAB80) : const Color(0xFFBD350C);
