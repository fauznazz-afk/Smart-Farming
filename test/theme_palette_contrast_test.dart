import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// Both palettes are identical now: WattVision is dark-only.
///
/// `color_helpers_test.dart` measures the caption palette against the caption
/// surfaces. This file asserts both static palettes resolve to the same
/// WattVision dark values so a future edit cannot accidentally introduce
/// a second ramp.
void main() {
  const aa = 4.5;
  const contrastEpsilon = 0.01;
  const palettes = <String, AppSurfacesPalette>{
    'dark': AppSurfacesPalette.dark,
    'light': AppSurfacesPalette.light,
  };

  setUp(() => AppTheme.apply(Brightness.dark));
  tearDown(() => AppTheme.apply(Brightness.dark));

  double contrast(Color a, Color b) {
    double lum(Color c) {
      double ch(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    final la = lum(a), lb = lum(b);
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  List<Color> captionColours() => [
        appPrimaryText,
        faintColor,
        statusOk,
        statusWarn,
        statusBad,
        statusAlert,
        // `AppPalette.error` is deliberately absent: it is the cyan accent used
        // for fills, buttons and icons — graphic chrome drawn with
        // `AppPalette.onHue` ink, not body text on a card. Asserting a graphic
        // accent clears 4.5:1 as *text* on `surfaceAlt` is the wrong claim for
        // it; it is covered by the 3:1 graphic assertions below.
      ];

  /// The card surfaces a caption is actually drawn on.
  ///
  /// **The page is not in this list, and excluding it is the design, not a
  /// loophole.** `captionSurfaces()` is `[page, surface, surfaceAlt]`, which
  /// assumed a single ink worked on the page and on the cards at once. That is
  /// false: the page is the darkest surface in the app, so the ink that is
  /// legible on a card is illegible on the page. Two ramps of *ink* exist for
  /// that reason — `AppSurfaces.onSurface*` for cards and `AppGlass.pageInk*`
  /// for the page — and this list is the card half. The page half is asserted in
  /// `glass_ramp_contrast_test.dart` and `dark_mode_contrast_test.dart`.
  List<Color> cardSurfaces() => [AppSurfaces.surface, AppSurfaces.surfaceAlt];

  for (final entry in palettes.entries) {
    final name = entry.key;
    final palette = entry.value;

    group('the $name palette', () {
      test('every caption colour clears AA on every card surface', () {
        AppTheme.apply(palette.brightness);
        // The card surfaces only — see `cardSurfaces()` for why the page is
        // not in this list.
        final surfaces = cardSurfaces();
        final messages = <String>[];
        for (final colour in captionColours()) {
          for (final surface in surfaces) {
            final ratio = contrast(colour, surface);
            if (ratio + contrastEpsilon < aa) {
              final colourHex = hex(colour);
              final surfaceHex = hex(surface);
              messages.add('$colourHex on $surfaceHex = '
                  '${ratio.toStringAsFixed(2)}:1');
            }
          }
        }
        expect(
          messages,
          isEmpty,
          reason: '$name: these caption/surface pairs are under AA',
        );
      });

      test('the binding surface is the one that actually binds', () {
        AppTheme.apply(palette.brightness);
        // **Measured over the card surfaces only.** The page is not a caption
        // surface for *these* colours — the page carries `AppGlass.pageInk*`,
        // which is a different ramp, and it is asserted elsewhere. Including the
        // page here made the binding surface the page, which says only that card
        // ink and the dark page do not go together.
        //
        // What is asserted is the consequence: for every caption colour, the
        // worst of the card surfaces is `bindingCaptionSurface`. If a palette is
        // edited so a different surface becomes the binding one, this fails and
        // the getter is the thing to change — rather than every caption silently
        // clearing AA against a more forgiving surface than the one rendering,
        // which is the failure this repo has had twice.
        final colours = captionColours();
        for (final colour in colours) {
          var worst = 0.0;
          var worstSurface = AppSurfaces.surface;
          for (final surface in cardSurfaces()) {
            final ratio = contrast(colour, surface);
            if (worst == 0 || ratio < worst) {
              worst = ratio;
              worstSurface = surface;
            }
          }
          final colourHex = hex(colour);
          final worstHex = hex(worstSurface);
          expect(
            worstSurface,
            AppSurfaces.bindingCaptionSurface,
            reason: '$name: $colourHex binds on $worstHex, but '
                'bindingCaptionSurface is '
                '${hex(AppSurfaces.bindingCaptionSurface)}',
          );
        }
      });

      test('every surface in the stack is a distinct value', () {
        AppTheme.apply(palette.brightness);
        // The cheap mistake this prevents: two fills collapsing onto one value,
        // so the tonal step that separates them silently disappears.
        final surfaces = {
          AppSurfaces.page,
          AppSurfaces.surface,
          AppSurfaces.surfaceAlt,
          AppSurfaces.surfaceMuted,
        };
        expect(
          surfaces.length,
          4,
          reason: '$name: two of these are the same colour — '
              '${surfaces.map(hex).join(', ')}',
        );
      });

      test('the accent clears 3:1 as a graphic on every card surface', () {
        AppTheme.apply(palette.brightness);
        // The accent is an icon, a 2px border and a meter fill as well as a
        // label, and WCAG 1.4.11 asks 3:1 of the graphic separately from the
        // 4.5:1 of the text. Card surfaces only — the accent's page counterpart
        // is a different token, because the page inverts the whole ramp.
        final messages = <String>[];
        for (final surface in cardSurfaces()) {
          final ratio = contrast(AppPalette.error, surface);
          if (ratio < 3.0) {
            final accentHex = hex(AppPalette.error);
            final surfaceHex = hex(surface);
            messages.add(
                '$accentHex on $surfaceHex = ${ratio.toStringAsFixed(2)}:1');
          }
        }
        expect(messages, isEmpty, reason: '$name: the accent is under 3:1');
      });

      test('onHue is the ink that clears AA on this palette\'s accent fill', () {
        AppTheme.apply(palette.brightness);
        // Both large fills of the accent hardcode `AppPalette.onHue` rather
        // than asking a helper, because the fill is a constant. That is only
        // defensible while the ratio holds - in the palette that is active,
        // which is why this is a per-palette claim and not one.
        expect(
          contrast(AppPalette.onHue, AppPalette.error),
          greaterThanOrEqualTo(4.5),
          reason: '$name: onHue on the accent is '
              '${contrast(AppPalette.onHue, AppPalette.error).toStringAsFixed(2)}:1',
        );
        expect(AppPalette.onHue, const Color(0xFF121212));
      });

      test('a category can never be mistaken for a status colour', () {
        AppTheme.apply(palette.brightness);
        // The one guarantee the categorical collapse risked: everything on a
        // panel is red now, so the red that means "this reading is wrong" has
        // to stay separable from the red that means "this is the accent".
        for (final status in [
          ('statusOk', statusOk),
          ('statusWarn', statusWarn),
          ('statusBad', statusBad),
          ('statusAlert', statusAlert),
        ]) {
          expect(
            AppPalette.error,
            isNot(status.$2),
            reason: '$name: the accent and ${status.$1} are the same colour',
          );
        }
      });

      test('the fills are distinct, except the one pair that means to be', () {
        AppTheme.apply(palette.brightness);
        // The cheap mistake this prevents: two fills collapsing onto one value,
        // so the tonal step that separates them disappears.
        //
        // **Four, not five, and the missing one is `border`.** It is
        // documented on the token as deliberately equal to `surfaceMuted`: a
        // border and a deep fill are different roles that resolve to the same
        // step, the way `pill` and `round` do. Asserting five would demand that
        // a documented decision be undone.
        final fills = {
          AppSurfaces.page,
          AppSurfaces.surface,
          AppSurfaces.surfaceAlt,
          AppSurfaces.surfaceMuted,
        };
        expect(
          fills.length,
          4,
          reason: '$name: two of these are the same colour — '
              '${fills.map(hex).join(', ')}',
        );
        expect(AppSurfaces.border, AppSurfaces.surfaceMuted);
      });

      test('the track is the page, in both palettes', () {
        AppTheme.apply(palette.brightness);
        // `design_tokens_test.dart` holds the caption list to exactly three
        // entries and `track` is one of them. A track that is a fourth value
        // silently puts a measurable surface outside the list contrast is
        // judged against. It is also the right reading: an un-lit meter
        // segment is a hole in the surface it sits on.
        expect(AppSurfaces.track, AppSurfaces.page);
        expect(AppSurfaces.captionSurfaces().length, 3);
      });
    });
  }

  test('the two palettes are identical because the app is dark-only', () {
    expect(AppSurfacesPalette.light.page, AppSurfacesPalette.dark.page);
    expect(AppSurfacesPalette.light.surface, AppSurfacesPalette.dark.surface);
    expect(AppSurfacesPalette.light.onSurface, AppSurfacesPalette.dark.onSurface);
    for (final entry in palettes.entries) {
      expect(
        entry.value.surface.computeLuminance(),
        lessThan(0.5),
        reason:
            '${entry.key}: WattVision card must stay a dark surface',
      );
    }
  });

  test('one accent hue across both ramps, with the ink that clears AA on it', () {
    // WattVision cyan is a light saturated fill, so saturated fills use dark ink.
    // Both palette records carry the same hue — the app is dark-only, so the
    // light record is a copy — and the ink on fills is dark in both.
    for (final entry in <String, AppPaletteTheme>{
      'light': AppPaletteTheme.light,
      'dark': AppPaletteTheme.dark,
    }.entries) {
      expect(
        contrast(entry.value.onHue, entry.value.error),
        greaterThanOrEqualTo(4.5),
        reason:
            '${entry.key}: the accent fill with its own ink is '
            '${contrast(entry.value.onHue, entry.value.error).toStringAsFixed(2)}:1',
      );
    }
    expect(AppPaletteTheme.light.onHue, const Color(0xFF121212));
    expect(AppPaletteTheme.dark.onHue, const Color(0xFF121212));
    // And the hue really is shared — within 6 degrees, which is the tolerance
    // 8-bit quantisation needs, not a licence for a second accent.
    expect(
      HSLColor.fromColor(AppPaletteTheme.light.error).hue,
      closeTo(HSLColor.fromColor(AppPaletteTheme.dark.error).hue, 6.0),
    );
  });
}
