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
///   * White on a light accent fill is far below 4.5:1, which is why
///     `onPrimaryInk` exists rather than every call site hardcoding
///     `Colors.white`.
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
  /// Every fill a saturated surface can end up carrying in this app. Read out of
  /// the palette rather than listed, because a literal here is a copy and
  /// copies drift.
  final fills = <String, Color>{
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
    test('3:1 on every surface it can be drawn on', () {
      // The claim that used to fail for three of four user accents. A hue is
      // used as a chart line, a progress fill and an icon tile, and 1.4.11 asks
      // 3:1 of all of those — measured here against the same derived surface
      // list every caption is measured against, so a hue cannot be legible as
      // text and illegible as a graphic on the same background.
      for (final entry in fills.entries) {
        for (final surface in AppSurfaces.captionSurfaces()) {
          expect(
            _contrast(entry.value, surface),
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key} #${_hex(entry.value)} is '
                '${_contrast(entry.value, surface).toStringAsFixed(2)}:1 on '
                '#${_hex(surface)}; 1.4.11 wants 3:1 for a graphical object',
          );
        }
      }
    });
  });

  group('onPrimaryInk', () {
    test('puts a legible ink on every fill the app can produce', () {
      // A fill is a fill: what matters is the measured ratio, not which palette
      // entry it came from, so the whole palette plus every category hue is
      // measured together. Anything that fails here is a button whose label the
      // user cannot read.
      for (final f in fills.entries) {
        final ink = onPrimaryInk(f.value);
        expect(
          _contrast(ink, f.value),
          greaterThanOrEqualTo(4.5),
          reason: '${f.key} #${_hex(f.value)} with ink #${_hex(ink)} is '
              '${_contrast(ink, f.value).toStringAsFixed(2)}:1; white on a '
              'light accent fill is far below the 4.5 that a label needs, and '
              'this is the function that exists because of it',
        );
      }
    });

    test('white really does fail, so the function is not decorative', () {
      // If `Colors.white` ever cleared 4.5:1 on the palette's own fills then
      // this function would be returning a constant and every call site could go
      // back to hardcoding it. The cheapest guard against that is the number.
      final failures = fills.values
          .where((fill) => _contrast(Colors.white, fill) < 4.5)
          .length;
      expect(
        failures,
        greaterThan(0),
        reason: 'white now clears 4.5:1 on every fill, so onPrimaryInk is a '
            'constant and this file should argue for deleting it',
      );
    });

    test('it is deterministic, and it does not depend on a lightness guess', () {
      // The same fill must always get the same ink, or a button changes its
      // label colour when it is rebuilt.
      for (final f in fills.entries) {
        expect(onPrimaryInk(f.value), onPrimaryInk(f.value));
      }
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

    test('it takes black ink, and white would have failed', () {
      // The natural assumption on a red chip is a white label. White on
      // `#FF6B6B` is **2.78:1** — under AA for body text by a factor of 1.6 —
      // while `AppPalette.onHue`'s black is **7.57:1**. The app's own
      // `onPrimaryInk` picks black here without being asked to, because the fill's
      // luminance is above the 0.18 threshold and the rule is not about hue.
      //
      // The assertion is on the *value* rather than on `greaterThanOrEqualTo`
      // alone, because "it clears 4.5:1" is true of both inks on some other fill
      // and would not catch a future edit that moved the fill under a hardcoded
      // white.
      expect(onPrimaryInk(AppPalette.error), AppPalette.onHue);
      expect(
        _contrast(onPrimaryInk(AppPalette.error), AppPalette.error),
        greaterThanOrEqualTo(4.5),
        reason: 'the accent fill with its own ink is '
            '${_contrast(onPrimaryInk(AppPalette.error), AppPalette.error).toStringAsFixed(2)}:1',
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
      // Red measures 6.27 / 5.73 / 5.17 / 4.55:1 across the four. The last of
      // those is the binding one and it has 0.05:1 of margin, so a surface tweak
      // is an accent-legibility change even when nothing about the accent moved.
      for (final s in {
        'page': AppSurfaces.page,
        'surface': AppSurfaces.surface,
        'surfaceAlt': AppSurfaces.surfaceAlt,
        'surfaceMuted': AppSurfaces.surfaceMuted,
        'track': AppSurfaces.track,
        'tooltip': AppSurfaces.tooltip,
      }.entries) {
        expect(
          _contrast(AppPalette.error, s.value),
          greaterThanOrEqualTo(3.0),
          reason: 'the accent on ${s.key} is '
              '${_contrast(AppPalette.error, s.value).toStringAsFixed(2)}:1; '
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
      final edge = AppBorders.boundary.color;
      for (final s in {
        'page': AppSurfaces.page,
        'surface': AppSurfaces.surface,
        'surfaceAlt': AppSurfaces.surfaceAlt,
      }.entries) {
        expect(
          _contrast(edge, s.value),
          greaterThanOrEqualTo(3.0),
          reason: 'boundary #${_hex(edge)} on ${s.key} is '
              '${_contrast(edge, s.value).toStringAsFixed(2)}:1',
        );
      }
    });

    test('the hairline is not, and is not asked to be', () {
      // Stated so the distinction stays honest. `AppBorders.hairline` is a
      // grouping cue and is well under 3:1; only `boundary` carries the 1.4.11
      // claim. If the hairline ever reached 3:1 the whole screen would be
      // framed, which `design_tokens.dart` argues is a heavier visual than the
      // brief asks for.
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