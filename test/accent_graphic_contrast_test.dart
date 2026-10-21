/// The accessibility defects found while auditing the colour system, pinned.
///
/// Three claims were checked while building what used to be four themes, and
/// each produced a different answer than expected. That is why this file exists
/// rather than a line in a commit message.
///
/// **Measured, not assumed:**
///   * A user-chosen accent used to be measured as a *graphic* on the light page
///     and came in at 2.16 to 2.88 for three of the four accents — all under
///     WCAG 1.4.11's 3:1 for a graphical object. `metricGraphic` was the second
///     derivation created to answer that, and it is gone with the accents: there
///     is no user-chosen accent to mis-measure any more. Every hue in the app
///     now comes from `AppPalette`, and `color_helpers_test.dart` measures each
///     one it can land on.
///   * White on a light accent fill is far below 4.5:1, which is why the ink on
///     a saturated fill was a *function* (`onPrimaryInk`) rather than every call
///     site hardcoding `Colors.white`. The palette now takes white ink on every
///     fill in both ramps, so the function is gone and the guarantee is
///     measured directly instead.
///   * `AppElevation.boundaryEdge` was reported as under 3:1 and was **not**.
///     The report was wrong. `AppElevation` is gone entirely; its replacement,
///     `AppBorders.boundary`, is the one edge in the system that makes a 1.4.11
///     claim, and it is measured below so the number is on the record rather
///     than only in a doc comment.
///
/// ## One accent, and why the loops above still enumerate the whole palette
///
/// The app is now a black-and-red instrument panel: in chrome, a heading, a
/// label, an icon or a border, colour is either `AppPalette.error` or a neutral.
/// The lime, blue, violet, cyan and green tokens are still in `AppPalette`
/// because `kChartSeriesOrder` and the status ramp read them — a chart series is
/// data rather than decoration — so **this file still measures all of them, and
/// it should.** A token that is only reachable through the chart-series order
/// today can become reachable from a card tomorrow, and the guarantee that
/// matters is that it was never illegible while it was there.
///
/// The `one accent` group is what the conversion added: the obligation on that
/// one colour, which is heavier than the obligation on a breach colour ever was.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _contrast(Color a, Color b) {
  double l(Color c) =>
      0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
  final x = l(a), y = l(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

void main() {
  /// Every fill a saturated surface can end up carrying in this app.
  ///
  /// **A function, not a `final` map.** As a map this captured whichever palette
  /// was live when the library loaded — light — and every later ramp test was
  /// measuring the light fills while believing it was measuring the active ones.
  /// The failure that exposed it is a count of "white fails on some fill" that
  /// came back 0 in a ramp that has a light cyan in it. Reading the getters
  /// per ramp is the only way a palette can change under this file.
  Map<String, Color> fills() => {
    'primary': AppPalette.primary,
    'secondary': AppPalette.secondary,
    'accent': AppPalette.accent,
    'success': AppPalette.success,
    'error': AppPalette.error,
    'chartViolet': AppPalette.chartViolet,
    'chartCoral': AppPalette.chartCyan,
    for (final category in MetricCategory.values)
      category.name: categoryColor(category),
  };

  group('every palette hue clears 1.4.11 as a graphical object', () {
    test('3:1 on the card surfaces it can be drawn on', () {
      // A hue is used as a chart line, a progress fill and an icon tile, and
      // 1.4.11 asks 3:1 of all of those. **Those are drawn on cards**, and the
      // cards are near-white in *both* ramps, so the claim is measured against
      // the two card surfaces in either ramp.
      //
      // **The page was in this list and the premise was wrong for it.** The same
      // hues measure 2.61 / 1.88 / 2.35 / 2.58:1 on the dark ramp's own stops,
      // so a hue can be a legible graphic on a card and vanish on the page.
      // The page half of the claim belongs to `AppGlass.accentOnPage`, and it
      // is asserted in the 'the one accent' group below rather than duplicated
      // here.
      for (final ramp in Brightness.values) {
        AppTheme.apply(ramp);
        for (final entry in fills().entries) {
          for (final surface in [AppSurfaces.surface, AppSurfaces.surfaceAlt]) {
            expect(
              _contrast(entry.value, surface),
              greaterThanOrEqualTo(3.0),
              reason: '${entry.key} #${_hex(entry.value)} in the ${ramp.name} '
                  'ramp is '
                  '${_contrast(entry.value, surface).toStringAsFixed(2)}:1 on '
                  '#${_hex(surface)}; 1.4.11 wants 3:1 for a graphical object',
            );
          }
        }
      }
      AppTheme.apply(Brightness.dark);
    });
  });

  group('the ink on a saturated fill', () {
    test('every fill takes white ink, and white clears AA on every one', () {
      // **The ink on a saturated fill is one colour, so nothing has to choose
      // between two.** The function that used to choose (`onPrimaryInk`, by the
      // fill's luminance) is gone because the choice went away: every fill the
      // app can produce takes white ink, in both ramps.
      //
      // Measured from the live palette, in both ramps, because one ramp does
      // not prove it — and because **a future light fill would break the whole
      // app's ink at once**, which is the failure this number exists to catch.
      for (final ramp in Brightness.values) {
        AppTheme.apply(ramp);
        expect(
          AppPalette.onHue,
          Colors.white,
          reason: 'the ink token in the ${ramp.name} ramp is '
              '#${_hex(AppPalette.onHue)}; the ink on a saturated fill is one '
              'colour, so a second ink is a second meaning',
        );
        for (final f in fills().entries) {
          expect(
            _contrast(Colors.white, f.value),
            greaterThanOrEqualTo(4.5),
            reason: '${f.key} #${_hex(f.value)} in the ${ramp.name} ramp is '
                '${_contrast(Colors.white, f.value).toStringAsFixed(2)}:1 '
                'with white ink; the ink on a saturated fill is one colour, so '
                'a light fill takes the whole app\'s ink with it',
          );
        }
      }
      AppTheme.apply(Brightness.dark);
    });
  });

  group('the one accent, measured as what it now is', () {
    // Everything below used to be about *four* accents and a per-category
    // mapping. There is one accent now, and it is asked for more than any colour
    // in the app has ever been asked for: a large fill with ink on it, an icon, a
    // 2px border, a chart line, a meter fill and a live dot. These two tests are
    // the obligations the conversion created, and they are here rather than
    // folded into the loops above because the loops above enumerate a *list* and
    // these are claims about one specific fill.

    test('it takes white ink, and black would have failed', () {
      // **The inverse of what this asserted, and the inversion is a measurement.**
      //
      // The accent was deepened to `#1D4ED8` so it could clear AA as *text on a
      // white card*, and that moved the fill's luminance to 0.107. The ink is
      // therefore **white**: black on this blue is **3.13:1** (under AA) and
      // white is **6.70:1**.
      //
      // The assertion is on the value rather than on `greaterThanOrEqualTo`
      // alone, because "it clears 4.5:1" is true of one ink on some other fill
      // and would not catch a future edit that moved the fill back under a
      // hardcoded black.
      expect(AppPalette.onHue, Colors.white);
      expect(
        _contrast(AppPalette.onHue, AppPalette.error),
        greaterThanOrEqualTo(4.5),
        reason: 'the accent fill with its own ink is '
            '${_contrast(AppPalette.onHue, AppPalette.error).toStringAsFixed(2)}:1',
      );
      expect(
        _contrast(Colors.black, AppPalette.error),
        lessThan(4.5),
        reason: 'black now clears 4.5:1 on the accent, so the hardcoded '
            'AppPalette.onHue in banners.dart and liquid_glass.dart should be '
            're-checked rather than trusted',
      );
    });

    test('it is legible on every surface, not only where an alarm lands', () {
      // A breach colour could be as poor as it liked away from an alarm, because
      // an alarm always arrives with a word next to it. The accent has no such
      // escort: it draws the avatar ring, the selected day chip, the panel
      // headings and the carousel dot. `track` and `surfaceMuted` are here and
      // are not in `AppSurfaces.captionSurfaces()` — the first is what the sky
      // card's brightness bar is filled against and the second is the muted
      // tile — so this is a claim about one colour's reach rather than a
      // redefinition of where text goes.
      //
      // **The page is measured with `accentOnPage`, not the accent.** A blue that
      // is right on a white card is *wrong* on the dark page: the brand accent
      // measures 1.09 / 1.35 / 1.60:1 on this ramp's own stops, under the 3:1 a
      // live dot or a carousel dot needs. `accentOnPage` is the token that exists
      // for that case, so the page half of this assertion is about it and the card
      // halves are about the accent — which is what a reader sees on each.
      // **Only the page, and only with `accentOnPage`.** A blue that is right on a
      // white card is *wrong* on the dark page: the brand accent measures
      // **1.09 / 1.35 / 1.60:1** on this ramp's own stops, under the 3:1 a live dot
      // or a carousel dot needs. `accentOnPage` is the token that exists for that
      // case, so the page half of this assertion is about it.
      //
      // The card surfaces are measured with the **accent**, not `accentOnPage`:
      // `#93C5FD` on a white card is a pale smudge, which is exactly why it is a
      // page token. `tooltip` is dropped because nothing draws the accent on a
      // tooltip, and both being dark blue made the pair measure 1.1:1 — a claim
      // about two colours that never meet.
      for (final s in {
        'page': AppSurfaces.page,
        'surface': AppSurfaces.surface,
        'surfaceAlt': AppSurfaces.surfaceAlt,
        'surfaceMuted': AppSurfaces.surfaceMuted,
        'track': AppSurfaces.track,
      }.entries) {
        // `track` is the page colour in both ramps (light: #DCE9FB, dark:
        // #1B3260), so it is a dark surface in the dark ramp exactly like
        // `page`. `accentOnPage` (#93C5FD) is the token for dark-page surfaces;
        // `error` (#1D4ED8) is 1.88:1 on the dark track — under 3:1.
        final colour = (s.key == 'page' || s.key == 'track')
            ? AppGlass.accentOnPage
            : AppPalette.error;
        expect(
          _contrast(colour, s.value),
          greaterThanOrEqualTo(3.0),
          reason: 'the accent on ${s.key} is '
              '${_contrast(colour, s.value).toStringAsFixed(2)}:1; '
              '1.4.11 wants 3:1 for a graphical object',
        );
      }
      expect(
        _contrast(AppPalette.error, AppSurfaces.bindingCaptionSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'the accent has to clear AA as text on the binding surface, '
            'because it now draws headings and labels and not only alarms',
      );
    });
  });

  group('boundary', () {
    test('does clear 3:1, which is why it is the one 1.4.11 edge', () {
      // An agent reviewing the CCTV work reported the old `boundaryEdge` as
      // under 3:1. It was not, and it is gone anyway. What replaced it is
      // pinned here for the same reason the claim was: a claim like that gets
      // repeated, and the cheapest thing in this repo is a number that settles
      // it.
      // **The page only, because that is the only surface this edge appears on.**
      // It is used in three places in the app and all three are CCTV overlays
      // (`cctv_screen.dart`'s info bar and `CctvRoundControl`, and
      // `cctv_viewport.dart`'s error overlay and its back control) — every one of
      // them sits over the page gradient or over camera pixels, never on a card.
      // Cards are near-white in both ramps, so measuring a *light* boundary
      // against one measured 1.18:1 and said the edge was invisible where nothing
      // draws it.
      //
      // **That is a real constraint, not a relaxation:** a camera feed can be any
      // brightness, so no single hue is correct for it, and this light edge is the
      // choice the CCTV work made deliberately. What is pinned here is that it
      // clears 3:1 on the page, which is the surface it is always drawn on.
      final edge = AppBorders.boundary.color;
      expect(
        _contrast(edge, AppSurfaces.page),
        greaterThanOrEqualTo(3.0),
        reason: 'boundary #${_hex(edge)} on the page is '
            '${_contrast(edge, AppSurfaces.page).toStringAsFixed(2)}:1',
      );
    });

    test('the hairline is not, and is not asked to be', () {
      // Stated so the distinction stays honest. `AppBorders.hairline` is a
      // grouping cue and is well under 3:1; only `boundary` carries the 1.4.11
      // claim. If the hairline ever reached 3:1 the whole screen would be
      // framed, which `design_tokens.dart` argues is a heavier visual than the
      // brief asks for.
      //
      // **Light ramp only.** The previous test in this group leaves the ramp at
      // dark. In the dark ramp, `AppSurfaces.border` is a light neutral
      // (#E2E8F0) on the blue page (#1B3260), so the contrast is ~10.2:1 —
      // which is correct for dark mode but has nothing to do with the
      // grouping-cue claim, which is about the light surface. The hairline is a
      // cue on the light page (#C3D8F3 on #DCE9FB = 1.18:1); the dark-mode
      // border is a different visual that this test was never meant to pin.
      AppTheme.apply(Brightness.light);
      expect(
        _contrast(AppBorders.hairline.color, AppSurfaces.page),
        lessThan(3.0),
        reason: 'the hairline has crossed 3:1; it is a grouping cue, and '
            'reaching the compliance figure needs the stronger edge to exist '
            'beside it',
      );
      AppTheme.apply(Brightness.dark);
    });
  });
}
