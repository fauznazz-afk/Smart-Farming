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

  group('one light source, from the top left', () {
    for (final isDark in [true, false]) {
      final mode = isDark ? 'dark' : 'light';

      test('$mode raised', () {
        final shadows = AppElevation.raised(isDark);

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

      test('$mode inset and insetDeep point the same way', () {
        // This is the pairing that is easy to get wrong and that reads as a
        // bug rather than as a mistake: a well that is pressed *deeper* and a
        // block that is pressed *flatter* are different animations, and the
        // mistake is to give both of them one pair.
        for (final pair in {
          'inset': AppElevation.inset(isDark),
          'insetDeep': AppElevation.insetDeep(isDark),
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
    for (final isDark in [true, false]) {
      test('${isDark ? 'dark' : 'light'} raised has a contact and an ambient', () {
        final dark = AppElevation.raised(isDark)
            .where((s) => s.color.computeLuminance() <
                (isDark ? 0.5 : AppSurfaces.pageLight.computeLuminance()))
            .toList();

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
      expect(AppSurfaces.card(true), AppSurfaces.pageDark);
      expect(AppSurfaces.card(false), AppSurfaces.pageLight);
    });

    test('the raised pair contains no shadow that could sit under text', () {
      // Not a contrast assertion -- a geometry one. Every offset in the raised
      // pair points away from the light, which is the direction that puts it
      // outside the card. A single shadow pointing *into* the card would be an
      // inner shadow, and that is the only way a shadow could ever reach the
      // text, so its absence is what the claim rests on.
      for (final isDark in [true, false]) {
        for (final s in AppElevation.raised(isDark)) {
          expect(
            isUpLeft(s) || isDownRight(s),
            isTrue,
            reason: 'isDark=$isDark offset ${s.offset} is not outward-diagonal',
          );
        }
      }
    });
  });

  group('the press pairs are the inverse of the resting ones', () {
    for (final isDark in [true, false]) {
      test('${isDark ? 'dark' : 'light'} pressed is tighter than raised', () {
        // A press collapses the shadow toward the surface. If it grew instead,
        // the control would look like it was lifting off the page as it is
        // pushed into it.
        final resting = AppElevation.raised(isDark)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        final held = AppElevation.pressed(isDark)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        expect(
          held,
          lessThan(resting),
          reason: 'pressed max offset $held vs raised $resting; a press that '
              'pushes the shadow outward reads as the control rising',
        );
      });

      test('${isDark ? 'dark' : 'light'} insetDeep is deeper than inset', () {
        // The counterpart, and the one that was gotten wrong first: a well
        // being pushed goes further in, while a block being pushed comes up.
        final resting = AppElevation.inset(isDark)
            .map((s) => s.offset.distance)
            .reduce(math.max);
        final held = AppElevation.insetDeep(isDark)
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
}
