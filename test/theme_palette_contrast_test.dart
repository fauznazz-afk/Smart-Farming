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
        // `AppPalette.error` is deliberately absent: on the dark ramp it is the
        // blue accent used for fills, buttons and icons — graphic chrome drawn
        // with `AppPalette.onHue` ink, not body text on a white card. Asserting
        // a graphic accent clears 4:5 as *text* on `surfaceAlt` (white) is wrong
        // for both palettes; it is covered by the 3:1 graphic assertions below.
      ];

  /// The card surfaces a caption is actually drawn on.
  ///
  /// **The page is not in this list, and excluding it is the design, not a
  /// loophole.** `captionSurfaces()` is `[page, surface, surfaceAlt]`, which
  /// assumed a single ink worked on the page and on the cards at once. In the
  /// blue system that is false: the page is dark in one ramp and near-white in
  /// the other, so the ink that is legible on a card is illegible on the dark
  /// page and vice versa. Two ramps of *ink* exist for that reason —
  /// `AppSurfaces.onSurface*` for cards and `AppGlass.pageInk*` for the page —
  /// and this list is the card half. The page half is asserted in
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
        // **Measured over the card surfaces only.** The page is not a caption
        // surface for *these* colours — the page carries `AppGlass.pageInk*`,
        // which is a different ramp, and it is asserted elsewhere. Including the
        // page here made the binding surface the page in both ramps, which says
        // only that card ink and a dark page do not go together.
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
    //
    // **The discriminator is the page gradient, not the ink.** It used to be
    // `onSurface` luminance, on the reasoning that a dark ramp draws light ink
    // everywhere. That stopped being true when the cards became near-white in
    // *both* ramps — which is the whole point of the blue system, since the page
    // is what carries the darkness and the cards are paper on top of it. Both
    // ramps now draw navy on their cards, so ink cannot tell them apart and
    // asking it to is asking a question with no answer.
    expect(AppSurfacesPalette.light.page, isNot(AppSurfacesPalette.dark.page));
    expect(
      AppGlass.pageGradientLight.first.computeLuminance(),
      greaterThan(AppGlass.pageGradientDark.first.computeLuminance() + 0.1),
      reason: 'the light page gradient is not lighter than the dark one',
    );
    expect(
      AppSurfacesPalette.light.onSurface.computeLuminance(),
      lessThan(0.5),
      reason: 'the light ramp must draw dark ink on its white cards',
    );
    // **Both ramps draw dark ink on a near-white card.** This is the invariant
    // the whole surface stack rests on, and it is asserted here because the
    // alternative — a dark card with light ink in one ramp — is the defect the
    // blue system was built to remove, and nothing else would notice it coming
    // back.
    for (final entry in palettes.entries) {
      expect(
        entry.value.surface.computeLuminance(),
        greaterThan(0.5),
        reason:
            '${entry.key}: the card is not a light surface, so every caption '
            'drawn on it is being measured against the wrong ramp',
      );
    }
  });

  test('one accent hue across both ramps, with the ink that clears AA on it', () {
    // **The hue is shared and the ink is not — which is the inverse of what this
    // test used to assert, and the inversion is the design.**
    //
    // The old rule was "one red cannot serve both": the accent was dark on a
    // light page and light on a dark one, so the app had two identities and
    // toggling the theme changed the brand. The blue system keeps one hue
    // (`#1D4ED8`) so the accent reads as the same colour everywhere.
    //
    // What did have to become per-ramp is the **ink on that fill**, because a
    // filled button's label is body text and the ratio is measured, not chosen.
    // Both ramps happen to land on white here; the assertion below is on the
    // measured ratio rather than on the literal, so a future ramp that needs the
    // other ink fails on the number instead of silently shipping a 4.06:1 label.
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
    // And the hue really is shared — within 6 degrees, which is the tolerance
    // 8-bit quantisation needs, not a licence for a second accent.
    expect(
      HSLColor.fromColor(AppPaletteTheme.light.error).hue,
      closeTo(HSLColor.fromColor(AppPaletteTheme.dark.error).hue, 6.0),
    );
  });
}
