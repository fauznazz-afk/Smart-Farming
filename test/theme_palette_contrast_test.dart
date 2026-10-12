import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// Both palettes, measured, not one of them.
///
/// `color_helpers_test.dart` measures the caption palette against the caption
/// surfaces and it has caught two real drifts in this repo. It only ever
/// measured **one** appearance, because there was only one. There are two now.
///
/// So this file is the second half of that guard, and it exists because the
/// failure it prevents is the quiet kind: the light values are read by every
/// call site that was written against the dark ones, and nothing about a
/// `static`-valued palette flips loudly when half of them stop being legible.
///
/// **Each test applies a palette and restores dark in `tearDown`.** The palette
/// is a static, so a test that leaves light applied would poison every test
/// after it in the same isolate — including in `color_helpers_test.dart`, which
/// would then measure its dark assertions against light surfaces and fail for a
/// reason that has nothing to do with what it is testing.
void main() {
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
        AppPalette.error,
      ];

  for (final entry in palettes.entries) {
    final name = entry.key;
    final palette = entry.value;

    group('the $name palette', () {
      test('every caption colour clears AA on every caption surface', () {
        AppTheme.apply(palette.brightness);
        final surfaces = AppSurfaces.captionSurfaces();
        final messages = <String>[];
        for (final colour in captionColours()) {
          for (final surface in surfaces) {
            final ratio = contrast(colour, surface);
            if (ratio < 4.5) {
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
        // **The design claim, and it is not the same shape in both ramps.**
        //
        // In dark, `surfaceAlt` is the *lightest* fill a caption lands on, so
        // it is the end that binds. In light the ramp is not a ladder at all —
        // `surface` is a white card lifted *off* the paper, and `surfaceAlt` is
        // an inset tile *below* it — so the end that binds is the page, the
        // darkest of the three. A hand-written "which end is it" rule would get
        // this wrong in one direction, which is why `bindingCaptionSurface` is a
        // getter that names the palette's own end.
        //
        // What is asserted here is the consequence: for every caption colour,
        // the worst of the three surfaces is `bindingCaptionSurface`. If a
        // palette is edited so that a different surface becomes the binding
        // one, this fails and the getter is the thing to change — rather than
        // every caption silently clearing AA against a more forgiving surface
        // than the one rendering, which is the failure this repo has had twice.
        final colours = captionColours();
        for (final colour in colours) {
          var worst = 0.0;
          var worstSurface = AppSurfaces.page;
          for (final surface in AppSurfaces.captionSurfaces()) {
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
        // The cheap mistake this prevents: a light palette copied from the dark
        // one with a couple of edits, where two fills collapse onto one value
        // and the tonal step that separates them silently disappears.
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

      test('the accent clears 3:1 as a graphic on every caption surface', () {
        AppTheme.apply(palette.brightness);
        // The accent is an icon, a 2px border and a meter fill as well as a
        // label, and WCAG 1.4.11 asks 3:1 of the graphic separately from the
        // 4.5:1 of the text.
        final messages = <String>[];
        for (final surface in AppSurfaces.captionSurfaces()) {
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
        // than calling `onPrimaryInk`, because the fill is a constant. That is
        // only defensible while the ratio holds — in the palette that is
        // active, which is why this is a per-palette claim and not one.
        expect(
          contrast(AppPalette.onHue, AppPalette.error),
          greaterThanOrEqualTo(4.5),
          reason: '$name: onHue on the accent is '
              '${contrast(AppPalette.onHue, AppPalette.error).toStringAsFixed(2)}:1',
        );
        // And the other ink does not, so the hardcoded token stays the only
        // right answer rather than one of two that happen to work here.
        final other = AppPalette.onHue == Colors.black
            ? Colors.white
            : Colors.black;
        expect(
          contrast(other, AppPalette.error),
          lessThan(4.5),
          reason: '$name: the other ink now clears AA too, so the hardcoded '
              'AppPalette.onHue should be re-checked rather than trusted',
        );
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
        // The cheap mistake this prevents: a light palette copied from the dark
        // one with a couple of edits, where two fills collapse onto one value
        // and the tonal step that separates them disappears.
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

  test('the two palettes are actually different', () {
    // A guard against the cheapest possible mistake: adding a light palette by
    // copying the dark one. That compiles, measures identically, and renders a
    // near-black app for a user who asked for light.
    expect(AppSurfacesPalette.light.page, isNot(AppSurfacesPalette.dark.page));
    expect(
      AppSurfacesPalette.light.onSurface,
      isNot(AppSurfacesPalette.dark.onSurface),
    );
    expect(
      AppSurfacesPalette.light.onSurface.computeLuminance(),
      lessThan(0.5),
      reason: 'the light ramp must draw dark ink',
    );
    expect(
      AppSurfacesPalette.dark.onSurface.computeLuminance(),
      greaterThan(0.5),
      reason: 'the dark ramp must draw light ink',
    );
  });

  test('the accent is genuinely different between the two ramps', () {
    // The finding of the whole light theme, pinned: one red cannot serve both.
    // On the dark ramp the accent is pinned bright by the AA floor against
    // `surfaceMuted`; against a light page that same red measures 2.49:1, which
    // is under the 3:1 a graphic needs. So the hues became per-palette rather
    // than staying one value and failing quietly.
    expect(AppPaletteTheme.light.error, isNot(AppPaletteTheme.dark.error));
    // And the ink inverts with them, because the fills invert.
    expect(AppPaletteTheme.light.onHue, Colors.white);
    expect(AppPaletteTheme.dark.onHue, Colors.black);
  });
}
