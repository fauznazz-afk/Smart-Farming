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
    'chartCoral': AppPalette.chartCoral,
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