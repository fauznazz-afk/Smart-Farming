import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The shadow pairs, pinned as properties rather than as values.
///
/// Nothing here asserts a specific blur radius. An earlier version of this idea
/// asserted `blurRadius == 12` and would have failed the first time someone made
/// a card deeper, which is the opposite of what a regression guard is for. What
/// is asserted is the *geometry* — which way each shadow points, how many
/// distinct distances there are, and that one light source is in force — because
/// those are the things that make soft UI read as soft UI, and each of them has
/// been gotten wrong in this repo already.
///
/// **Every group iterates [AppTheme.values] rather than a `[true, false]`.**
/// That list was the reason the Dracula set could have been added with no test
/// running against it: a hardcoded pair of booleans covers two themes for ever,
/// and the moment a third exists the loop is silently one short. The
/// `AppTheme` enum is now the vocabulary, and the loop follows it.
void main() {
  /// Every shadow's offset, as a unit-ish comparison.
  ///
  /// Both signs matter and neither is enough alone. A shadow at (5, 5) is
  /// down-right; at (-5, -5) it is up-left. Magnitude alone would pass a pair
  /// that had been accidentally mirrored onto the wrong side, which is the one
  /// error that makes a whole screen look broken rather than merely flat.
  bool isDownRight(BoxShadow s) => s.offset.dx > 0 && s.offset.dy > 0;
  bool isUpLeft(BoxShadow s) => s.offset.dx < 0 && s.offset.dy < 0;

  /// Diagonal, not one axis. An offset of (5, 0) is a shadow cast to the side,
  /// and with the light from the top left that reads as two light sources.
  bool isDiagonal(BoxShadow s) =>
      s.offset.dx != 0 && s.offset.dy != 0 && s.offset.dx.abs() == s.offset.dy.abs();

  /// The dark half of a pair, identified by colour rather than by position.
  ///
  /// `Color.computeLuminance` reads the RGB channels and ignores alpha, so every
  /// black shadow in the file is exactly 0 and every white one exactly 1,
  /// whatever their alpha. That is what makes this a reliable classifier across
  /// all three themes; the earlier version compared against a *page* luminance
  /// and so only worked for the two themes whose light half happened to be
  /// white.
  bool isDarkHalf(BoxShadow s) => s.color.computeLuminance() < 0.5;

  /// The signed change in page luminance a shadow makes at its own alpha.
  ///
  /// This is the measure the Dracula alphas were solved against; see the note on
  /// [AppElevation.raised]. The dark half takes a negative step, the light half
  /// a positive one, so the sign is what distinguishes them at this level.
  double luminanceStep(Color page, BoxShadow s) {
    final over = s.color.computeLuminance() < 0.5
        ? const Color(0xFF000000)
        : Colors.white;
    return (Color.lerp(page, over, s.color.a)!.computeLuminance() -
            page.computeLuminance());
  }

  group('one light source, from the top left', () {
    for (final theme in AppTheme.values) {
      test('${theme.name} raised', () {
        final shadows = AppElevation.raised(theme);

        for (final s in shadows) {
          expect(
            isDiagonal(s),
            isTrue,
            reason: 'offset ${s.offset} is not diagonal; a single-axis shadow '
                'reads as a second light source',
          );
        }

        expect(
          shadows.where(isDownRight).isNotEmpty,
          isTrue,
          reason: 'a raised surface must cast away from the light',
        );
        expect(
          shadows.where(isUpLeft).isNotEmpty,
          isTrue,
          reason: 'a raised surface must catch light on the other side, or it '
              'is a card with a drop shadow and not a soft-UI surface',
        );
      });

      test('${theme.name} inset and insetDeep point the same way', () {
        // This is the pairing that is easy to get wrong and that reads as a
        // bug rather than as a mistake: a well that is pressed *deeper* and a
        // block that is pressed *flatter* are different animations, and the
        // mistake is to give both of them one pair.
        for (final pair in {
          'inset': AppElevation.inset(theme),
          'insetDeep': AppElevation.insetDeep(theme),
        }.entries) {
          for (final s in pair.value) {
            expect(
              isDiagonal(s),
              isTrue,
              reason: '${pair.key} offset ${s.offset}',
            );
          }
          expect(
            pair.value.where(isDownRight).isNotEmpty,
            isTrue,
            reason: '${pair.key} must be a well, lit from inside',
          );
        }
      });
    }
  });

  group('a raised surface has two distances, which is what makes it deep', () {
    for (final theme in AppTheme.values) {
      test('${theme.name} raised has a contact and an ambient', () {
        final dark =
            AppElevation.raised(theme).where(isDarkHalf).toList();

        // Two distinct blur radii among the shadows on the same side. A single
        // radius is the float look: one soft halo, no measurable thickness.
        final blurs = dark.map((s) => s.blurRadius).toSet();
        expect(
          blurs.length,
          greaterThanOrEqualTo(2),
          reason: 'the dark half has ${blurs.length} distinct blur radius; one '
              'means the card floats instead of standing on the page',
        );

        // And the tight one has to be genuinely tight, or the pair is one blur
        // and a slightly less blurry one.
        final tightest = dark.map((s) => s.blurRadius).reduce(math.min);
        expect(
          tightest,
          lessThanOrEqualTo(8),
          reason: 'the contact shadow is at blur $tightest, which is not a lip',
        );
      });
    }
  });

  group('depth must not be bought with the fill', () {
    // The rule this file exists to protect, and it is a measured one.
    //
    // A `BoxShadow` paints outside the decoration rect, so it cannot darken a
    // card's own interior and cannot touch a caption drawn on it. A *gradient
    // across the fill* can, and at 4% the light-mode worst case is already
    // 4.15:1 against an AA requirement of 4.5. So depth belongs in the shadow
    // and the fill has to stay flat, and this is why.
    test('the card fill is still exactly the page colour', () {
      for (final theme in AppTheme.values) {
        expect(AppSurfaces.card(theme), AppSurfaces.page(theme));
      }
    });

    test('the raised pair contains no shadow that could sit under text', () {
      // Not a contrast assertion -- a geometry one. Every offset in the raised
      // pair points away from the light, which is the direction that puts it
      // outside the card. A single shadow pointing *into* the card would be an
      // inner shadow, and that is the only way a shadow could ever reach the
      // text, so its absence is what the claim rests on.
      for (final theme in AppTheme.values) {
        for (final s in AppElevation.raised(theme)) {
          expect(
            isUpLeft(s) || isDownRight(s),
            isTrue,
            reason: '${theme.name} offset ${s.offset} is not outward-diagonal',
          );
        }
      }
    });
  });

  group('the press pairs are the inverse of the resting ones', () {
    for (final theme in AppTheme.values) {
      test('${theme.name} pressed is tighter than raised', () {
        // A press collapses the shadow toward the surface. If it grew instead,
        // the control would look like it was lifting off the page as it is
        // pushed into it.
        final resting = AppElevation.raised(theme)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        final held = AppElevation.pressed(theme)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        expect(
          held,
          lessThan(resting),
          reason: 'pressed max offset $held vs raised $resting; a press that '
              'pushes the shadow outward reads as the control rising',
        );
      });

      test('${theme.name} insetDeep is deeper than inset', () {
        // The counterpart, and the one that was gotten wrong first: a well
        // being pushed goes further in, while a block being pushed comes up.
        final resting = AppElevation.inset(theme)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        final held = AppElevation.insetDeep(theme)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        expect(
          held,
          greaterThan(resting),
          reason: 'insetDeep $held vs inset $resting; a well being pressed must '
              'go deeper, and the two are different animations',
        );
      });
    }
  });

  group('Dracula is a third theme, so it is held to the same properties', () {
    test('its surfaces are not the app\'s dark surfaces renamed', () {
      // The tempting implementation is to map `AppTheme.dracula` onto the dark
      // constants and call it a third mode. That would leave the preset
      // indistinguishable from dark mode apart from an accent, which is the
      // thing this exists to avoid.
      expect(AppSurfaces.page(AppTheme.dracula), isNot(AppSurfaces.pageDark));
      expect(AppSurfaces.chrome(AppTheme.dracula), isNot(AppSurfaces.chromeDark));
      expect(AppSurfaces.input(AppTheme.dracula), isNot(AppSurfaces.inputDark));
      expect(AppSurfaces.track(AppTheme.dracula), isNot(AppSurfaces.trackDark));
    });

    test('its page is lighter than the app\'s dark page, which is the premise', () {
      // This is the measurement the whole Dracula shadow set rests on. If a
      // future edit darkened `pageDracula` towards the app's dark page, the
      // derived alphas would be wrong and every one of the guards below would
      // still pass, because they are relative to the theme's own page. So the
      // premise itself is pinned.
      expect(
        AppSurfaces.pageDracula.computeLuminance(),
        greaterThan(AppSurfaces.pageDark.computeLuminance() * 1.5),
        reason: 'Dracula is 0.0237 against the app\'s 0.0141. If these two ever '
            'converge, the Dracula alphas were solved for a page that no longer '
            'exists and have to be re-derived.',
      );
    });

    test('its chrome is the lightest surface, so it is the binding one', () {
      // The reason every AA measurement in the repo takes the worst of a list
      // rather than the page: `#343746` is 0.0390 against the page's 0.0237.
      final surfaces = AppSurfaces.captionSurfaces(AppTheme.dracula);
      final lightest = surfaces
          .reduce((a, b) => a.computeLuminance() >= b.computeLuminance() ? a : b);
      expect(lightest, AppSurfaces.chromeDracula);
    });

    test('the shadow geometry is identical to dark, so the light cannot move',
        () {
      // A Dracula card that caught its light from somewhere else would be
      // invisible to every other guard in this file, all of which check
      // direction and magnitude but not *which* direction. Pinning the geometry
      // to the dark theme's is what makes "one light source, app-wide" a claim
      // about three themes instead of three claims.
      for (final pair in const {
        'raised': AppElevation.raised,
        'inset': AppElevation.inset,
        'insetDeep': AppElevation.insetDeep,
        'pressed': AppElevation.pressed,
      }.entries) {
        final dracula = pair.value(AppTheme.dracula);
        final dark = pair.value(AppTheme.dark);
        expect(dracula.length, dark.length, reason: pair.key);
        for (var i = 0; i < dracula.length; i++) {
          expect(
            dracula[i].offset,
            dark[i].offset,
            reason: '${pair.key}[$i]: a different offset in Dracula is a second '
                'light source',
          );
          expect(
            dracula[i].blurRadius,
            dark[i].blurRadius,
            reason: '${pair.key}[$i]: only the alpha is per-theme; the distances '
                'are what make the pair read as a thickness',
          );
        }
      }
    });
  });

  group('the Dracula alphas were solved, not guessed', () {
    // The rule, asserted so that it cannot be quietly abandoned:
    //
    //   every shadow's *absolute* luminance step on #282A36 matches the step the
    //   same shadow makes on #1A211F, to within the 8-bit quantisation of the
    //   alpha byte.
    //
    // The intuitive measure is the wrong one and it is worth saying why in a
    // test. At a fixed alpha, black over Dracula drops *proportionally* more
    // than over the app's dark page (83.4% against 79.7%), which makes the dark
    // alphas look about right. But the absolute step is 1.8x larger — 0.0198
    // against 0.0112 — and the absolute step is what the eye sees. A backdrop
    // that is already almost black flatters a shadow.

    /// Pairs the same shadow in the Dracula set and the dark set by position.
    /// Valid because the geometry guard above pins the lists to the same length
    /// and the same offsets.
    const pairs = <String, (List<BoxShadow> Function(AppTheme), List<BoxShadow> Function(AppTheme))>{
      'raised': (AppElevation.raised, AppElevation.raised),
      'inset': (AppElevation.inset, AppElevation.inset),
      'insetDeep': (AppElevation.insetDeep, AppElevation.insetDeep),
      'pressed': (AppElevation.pressed, AppElevation.pressed),
    };

    /// The measured spread across all fourteen shadow/alpha combinations is
    /// 0.0007, on the bounce of the raised pair, where 8-bit quantisation of the
    /// alpha byte is 0.002 of alpha. The tolerance is 0.002 of luminance, which
    /// is roughly 0.6 of an alpha step — tight enough that a single-digit change
    /// to any alpha byte fails it, and loose enough that it is not asserting the
    /// solver's own precision.
    const tolerance = 0.002;

    for (final entry in pairs.entries) {
      test('${entry.key}: each shadow makes the same step on both dark pages', () {
        final dracula = entry.value.$1(AppTheme.dracula);
        final dark = entry.value.$2(AppTheme.dark);
        for (var i = 0; i < dracula.length; i++) {
          final a = luminanceStep(AppSurfaces.page(AppTheme.dracula), dracula[i]);
          final b = luminanceStep(AppSurfaces.pageDark, dark[i]);
          expect(
            (a - b).abs(),
            lessThanOrEqualTo(tolerance),
            reason: '${entry.key}[$i] alpha '
                '${dracula[i].color.a.toStringAsFixed(3)}: step '
                '${a.toStringAsFixed(5)} on Dracula against '
                '${b.toStringAsFixed(5)} on the app\'s dark page',
          );
        }
      });
    }

    test('every Dracula dark-half alpha is lower than the dark theme\'s', () {
      // The direction of the fix, pinned separately from the magnitude so that
      // "both sets are right" cannot be satisfied by copying one over the other.
      for (final name in ['raised', 'inset', 'insetDeep', 'pressed']) {
        final list = switch (name) {
          'raised' => AppElevation.raised,
          'inset' => AppElevation.inset,
          'insetDeep' => AppElevation.insetDeep,
          _ => AppElevation.pressed,
        };
        for (var i = 0; i < list(AppTheme.dracula).length; i++) {
          expect(
            list(AppTheme.dracula)[i].color.a,
            lessThan(list(AppTheme.dark)[i].color.a),
            reason: '$name[$i]: Dracula\'s page is lighter, so every alpha has '
                'to come down or the shadow becomes a halo',
          );
        }
      }
    });

    test('the light-to-dark ratio is preserved, which is the documented failure',
        () {
      // A flat ratio is the light-mode artefact this file spends its length
      // warning about: the light half does nearly all the work and the card
      // reads as *lit* rather than as standing off the surface. Dark measures
      // 3.80; uniform scaling of the alphas was tried and lands this at about
      // 1.9, so the ratio is the specific thing the per-shadow solve protects.
      double ratioFor(AppTheme theme) {
        final page = AppSurfaces.page(theme);
        final shadows = AppElevation.raised(theme);
        final light = shadows
            .where((s) => !isDarkHalf(s))
            .map((s) => luminanceStep(page, s))
            .reduce(math.max);
        final dark = shadows
            .where(isDarkHalf)
            .map((s) => luminanceStep(page, s))
            .reduce(math.min);
        return light / -dark;
      }

      final dark = ratioFor(AppTheme.dark);
      final dracula = ratioFor(AppTheme.dracula);
      expect(
        dracula,
        closeTo(dark, dark * 0.10),
        reason: 'dark $dark vs dracula $dracula; a ratio that collapses means '
            'the light half is doing all the work and the card reads as lit',
      );
    });
  });
}
