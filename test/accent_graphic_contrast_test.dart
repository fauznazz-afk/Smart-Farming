/// The WattVision accessibility claims, pinned.
///
/// WattVision is a single-ramp dark system with cyan data accent, alert red,
/// lime green, amber warning. All contrast claims measured against dark
/// surfaces. `AppBorders.boundary` is the one 1.4.11 edge.
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
  /// was live when the library loaded, and every later assertion was measuring
  /// those fills while believing it was measuring the active ones. Reading the
  /// getters at assertion time is the only way a palette can change under this
  /// file — and it still can: the ramp machinery is intact even though every
  /// ramp resolves to the same dark values.
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
      // 1.4.11 asks 3:1 of all of those. **Those are drawn on cards**, so the
      // claim is measured against the two card surfaces.
      //
      // **The page was in this list and the premise was wrong for it.** A hue
      // can be a legible graphic on a card and vanish on the page. The page half
      // of the claim belongs to `AppGlass.accentOnPage`, and it is asserted in
      // the 'the one accent' group below rather than duplicated here.
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
    test('every fill takes the token ink, and it clears AA on every one', () {
      // WattVision's saturated fills are bright, so their shared fill ink is dark.
      for (final ramp in Brightness.values) {
        AppTheme.apply(ramp);
        expect(
          AppPalette.onHue,
          const Color(0xFF121212),
          reason: 'the ink token in the ${ramp.name} ramp is '
              '#${_hex(AppPalette.onHue)}; the ink on a saturated fill is one '
              'colour, so a second ink is a second meaning',
        );
        for (final f in fills().entries) {
          expect(
            _contrast(AppPalette.onHue, f.value),
            greaterThanOrEqualTo(4.5),
            reason: '${f.key} #${_hex(f.value)} in the ${ramp.name} ramp is '
                '${_contrast(AppPalette.onHue, f.value).toStringAsFixed(2)}:1 '
                'with token ink; the ink on a saturated fill is one colour, so '
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

    test('it takes dark ink, and white would have failed', () {
      expect(AppPalette.onHue, const Color(0xFF121212));
      expect(
        _contrast(AppPalette.onHue, AppPalette.error),
        greaterThanOrEqualTo(4.5),
        reason: 'the accent fill with its own ink is '
            '${_contrast(AppPalette.onHue, AppPalette.error).toStringAsFixed(2)}:1',
      );
      expect(
        _contrast(Colors.white, AppPalette.error),
        lessThan(4.5),
        reason: 'white now clears 4.5:1 on the accent, so the hardcoded '
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
      // **The page is measured with `accentOnPage`, the cards with the accent.**
      // WattVision's cyan is one hue, but a hue measured on a card and on the
      // page are two different claims, so `accentOnPage` exists as its own token
      // for the page-level case — a live dot, a carousel dot, a section heading.
      //
      // `tooltip` is dropped because nothing draws the accent on a tooltip, and a
      // claim about two colours that never meet is not a measurement.
      for (final s in {
        'page': AppSurfaces.page,
        'surface': AppSurfaces.surface,
        'surfaceAlt': AppSurfaces.surfaceAlt,
        'surfaceMuted': AppSurfaces.surfaceMuted,
        'track': AppSurfaces.track,
      }.entries) {
        // `track` is the page colour, so it is a page-level surface exactly like
        // `page` and takes the same token. The cards are measured with the card
        // accent instead.
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
      // them sits over the page or over camera pixels, never on a card. Measuring
      // a *light* boundary against a card would say the edge was invisible where
      // nothing draws it.
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
      // **Measured on the page, where the hairline actually groups things.** It
      // is `#2C2C2E` on `#121212`, a whisper — and it is meant to be one. The
      // stronger edge beside it is `AppBorders.boundary`, which the test above
      // pins at 3:1.
      expect(
        _contrast(AppBorders.hairline.color, AppSurfaces.page),
        lessThan(3.0),
        reason: 'the hairline has crossed 3:1; it is a grouping cue, and '
            'reaching the compliance figure needs the stronger edge to exist '
            'beside it',
      );
    });
  });
}
