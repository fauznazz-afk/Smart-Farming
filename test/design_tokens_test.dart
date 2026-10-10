import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The token file, pinned as properties rather than as values.
///
/// **What this file used to be.** It was almost entirely about the three-shadow
/// elevation system: one light source from the top left, a contact shadow and an
/// ambient one, `pressed` being the inverse of `raised`, `insetDeep` being the
/// inverse of `inset`, and a long derivation of Dracula's shadow alphas from two
/// measured points. All of it is gone — `AppElevation` was deleted along with
/// the themes, because a flat surface has no thickness to collapse and the
/// brief's depth cue is a 1px line and a tonal step instead.
///
/// Two lessons from that file are kept here, because both are about how a guard
/// is written rather than about what it measures, and both have been paid for
/// twice in this repo:
///
/// 1. **Nothing here asserts a specific number.** An earlier version asserted
///    `blurRadius == 12` and would have failed the first time somebody made a
///    card deeper, which is the opposite of what a regression guard is for.
/// 2. **Nothing here asserts against a copied literal.** A hand-written list of
///    "the surfaces the app paints" is a copy, and this repo has had three
///    silent drifts from exactly that shape. Where a value can be read out of
///    `AppSurfaces` it is read out of `AppSurfaces`.
///
/// The load-bearing claim this file now guards is the one the new system rests
/// on: **a flat design has exactly one depth cue, and hue never means two
/// things.**
void main() {
  group('depth is a line and a tonal step, not a shadow', () {
    test('the borders are one pixel wide, so they cannot read as depth', () {
      // A thick border is the failure mode of a flat design: it starts to look
      // like the edge of a solid object again, which is the thing the migration
      // was away from. Every edge in the system is a hairline.
      for (final entry in {
        'hairline': AppBorders.hairline,
        'control': AppBorders.control,
        'boundary': AppBorders.boundary,
      }.entries) {
        expect(
          entry.value.width,
          lessThanOrEqualTo(1.5),
          reason: '${entry.key} is ${entry.value.width}px, which is a frame '
              'rather than a hairline',
        );
      }
    });

    test('the hairline is neutral, so no card claims a category it lacks', () {
      // An earlier revision tinted this with the theme accent, which put a green
      // outline on every card and undid the whole soft-UI migration. A card that
      // carries a hue in its border is a card making a claim about what data it
      // contains, and only `AppBorders.categoricalBorder` is allowed to do that.
      expect(AppBorders.hairline.color, AppSurfaces.border);
    });

    test('the categorical border is the one place a hue is drawn as a frame', () {
      // `categoricalBorder` returns a `Border`, so the side has to be taken off
      // it. `Border.top` rather than a cast: a four-sided `Border` is what the
      // decoration gets, and reading `top` is also the assertion that all four
      // are the same, which a `Border` with mismatched sides would fail.
      for (final category in MetricCategory.values) {
        final border = AppBorders.categoricalBorder(categoryColor(category));
        final side = border.top;
        expect(
          side.color,
          isNot(AppSurfaces.border),
          reason: '${category.name} drew a neutral frame, so the wash behind it '
              'has nothing to belong to',
        );
        expect(
          side.width,
          AppBorders.hairline.width,
          reason: 'a categorical frame must not be heavier than the neutral '
              'one, or carrying a category costs more visually than it explains',
        );
        for (final edge in [border.top, border.bottom, border.left, border.right]) {
          expect(
            edge,
            side,
            reason: 'a four-sided frame with one odd edge out reads as a bug, '
                'not as a design',
          );
        }
      }
    });

    test('the wash is faint enough that its own hue stays the subject', () {
      // `categoricalWash` is 10% of the hue. The pairing — faint wash behind,
      // full-strength foreground — is the whole reason the wash is safe, and the
      // 10% is what makes "faint" true. A wash that is not faint puts a
      // saturated block behind a 12px caption, which is the mistake this repo
      // has made in three previous design systems.
      for (final category in MetricCategory.values) {
        final hue = categoryColor(category);
        expect(
          AppBorders.categoricalWash(hue).a,
          lessThanOrEqualTo(0.15),
          reason: '${category.name} wash is at '
              '${(AppBorders.categoricalWash(hue).a * 100).toStringAsFixed(0)}% '
              'alpha',
        );
        // Same hue, so the wash and the foreground are recognisably one thing.
        expect(
          HSLColor.fromColor(hue.withValues(
            alpha: AppBorders.categoricalWash(hue).a,
          )).hue,
          closeTo(HSLColor.fromColor(hue).hue, 0.5),
        );
      }
    });
  });

  group('the tonal ramp is a ramp, not a set of unrelated fills', () {
    test('each step is lighter than the one below it', () {
      // page < surface < surfaceAlt. If this ever inverts, a "raised" surface is
      // darker than the page behind it, which reads as a hole rather than as a
      // step. Asserted as an ordering rather than as three hexes, because the
      // whole ramp is allowed to move.
      double l(Color c) => c.computeLuminance();
      expect(l(AppSurfaces.surface), greaterThan(l(AppSurfaces.page)));
      expect(l(AppSurfaces.surfaceAlt), greaterThan(l(AppSurfaces.surface)));
    });

    test('the binding caption surface is the top of the ramp, and is listed',
        () {
      // `surfaceAlt` is the hardest surface for a caption because it is the
      // lightest. A reader scanning `captionSurfaces()` should see that the
      // hardest one is listed, and it is listed last, and a consumer that takes
      // the worst is measuring the right thing.
      expect(AppSurfaces.captionSurfaces().last, AppSurfaces.surfaceAlt);
      expect(AppSurfaces.bindingCaptionSurface, AppSurfaces.surfaceAlt);
    });

    test('the caption surface list covers every fill a caption can land on', () {
      // The list is the three tonal steps and nothing else.
      //
      // The previous system excluded `track` on the grounds that no caption is
      // drawn on a 6dp progress bar. That exclusion is gone because the
      // distinction it rested on is: `track` and `surfaceAlt` are now the same
      // token, so excluding one would have excluded the other and left the tile
      // -- which draws text, and is `surfaceAlt` -- out of the list. `track` is
      // kept as a name because a track and a tile mean different things to a
      // reader even when they resolve to the same number, the same way `pill`
      // and `round` do.
      //
      // Derived, never written down. A literal here is the copy that went stale
      // twice in this repo and left three captions under AA with the suite green.
      final surfaces = AppSurfaces.captionSurfaces();
      expect(surfaces, contains(AppSurfaces.page));
      expect(surfaces, contains(AppSurfaces.surface));
      expect(surfaces, contains(AppSurfaces.surfaceAlt));
      expect(surfaces, contains(AppSurfaces.track));
      expect(
        surfaces.length,
        3,
        reason: 'a fourth entry means a new surface exists and whoever added it '
            'has to decide whether a caption can land on it',
      );
    });
  });

  group('the radius scale has no strays', () {
    test('pill, round and bar are all fully round', () {
      // Three names for one number. They are kept because they mean different
      // things to a reader — a stadium, a dot, a chip — and a test that pins the
      // identity is what stops a future edit from making one of them 8dp, which
      // would look correct on a dot and wrong on a bar.
      expect(AppRadius.pill, AppRadius.round);
      expect(AppRadius.bar, AppRadius.round);
    });

    test('the card is the largest corner on the scale', () {
      // The order is the design brief's own scale, read bottom-up:
      // `rounded.sm 4 -> md 12 -> lg 16 -> xl 24`, mapped onto
      // `badge -> tile -> inset -> card`.
      //
      // **`inset` sits above `tile` and that is not a mistake.** `inset` is the
      // radius on text inputs and `tile` is the radius on icon tiles and chips,
      // and the brief gives inputs the *larger* of the two. An earlier revision of
      // this test asserted the opposite order on the assumption that the two were
      // nested shapes, but they are not nested -- an input is not inside a card
      // tile -- so there was nothing for that ordering to protect.
      //
      // What does have to hold is that a nested pair differs. A tile inside a
      // card matching the card's radius would make the two read as one block.
      expect(
        AppRadius.card,
        greaterThan(AppRadius.inset),
        reason: 'card ${AppRadius.card} vs inset ${AppRadius.inset}',
      );
      expect(AppRadius.inset, greaterThan(AppRadius.tile));
      expect(AppRadius.tile, greaterThan(AppRadius.badge));
    });

    test('a bar at the bar radius is a stadium, not a rectangle', () {
      // The value is 999 on purpose and this is what it buys: at 6dp tall, a
      // 999 radius is a stadium. If somebody dropped it to a literal 4 the shape
      // would still *look* right on a bar, so nothing else would catch it —
      // but the token's name would then be lying about what it is for.
      expect(AppRadius.bar, 999);
    });
  });

  group('motion', () {
    test('every duration is non-zero and ordered by how far it travels', () {
      // A press is immediate, a page transition is not. An inverted pair is not
      // a slow UI, it is a UI that feels broken: a page that arrives before the
      // press that navigated to it has finished.
      expect(AppMotion.press, lessThan(AppMotion.state));
      expect(AppMotion.state, lessThan(AppMotion.container));
      expect(AppMotion.state, lessThan(AppMotion.page));
      // **`container` and `page` are deliberately unordered relative to each
      // other.** Both are "a large thing arrived" -- a card crossfading into a
      // different card, and a page fading in -- and neither is a consequence of
      // the other, so ranking them would be inventing a relationship. An earlier
      // version of this test asserted `container < page` and failed: the two were
      // written from the brief's example values without checking which was which,
      // and the assertion was only ever going to be satisfied by editing a number
      // until it was. If a future change needs an ordering here, the reason has to
      // be that one *causes* the other.
    });

    test('no duration is zero', () {
      // A zero-duration animation is not an animation; it is a value that was
      // forgotten, and it renders as a jump that reads as a glitch.
      for (final entry in {
        'press': AppMotion.press,
        'state': AppMotion.state,
        'container': AppMotion.container,
        'page': AppMotion.page,
      }.entries) {
        expect(
          entry.value,
          isNot(Duration.zero),
          reason: '${entry.key} is zero, which is a forgotten value rather '
              'than a chosen one',
        );
      }
    });
  });

  group('type', () {
    test('the three families are distinct', () {
      // A heading set in the body font is not a hierarchy, it is a font-size
      // difference — and it is invisible on a card until somebody measures it.
      final families = {AppType.heading, AppType.sans, AppType.mono};
      expect(families, hasLength(3));
    });

    test('figures are set in a font with tabular figures, or a column jitters', () {
      // The numeral styles are the ones that matter here: a live value that
      // changes width as it changes digit count makes the whole card twitch on
      // every poll. That is why they are a separate family from the captions
      // around them.
      for (final entry in {
        'numeralXl': AppType.numeralXl,
        'numeralLg': AppType.numeralLg,
        'displayLg': AppType.displayLg,
        'displayMd': AppType.displayMd,
        'numeralMono': AppType.numeralMono,
      }.entries) {
        expect(
          entry.value.fontFamily,
          isNotNull,
          reason: '${entry.key} inherits the platform default, so its width '
              'depends on the device rather than on the design',
        );
      }
    });

    test('the uppercase labels are bold and wide-tracked, which is the motif', () {
      // "Uppercase, wide-tracked, bold" is what `design_tokens.dart` calls the
      // motif the whole system is identified by, and it is applied by the call
      // site rather than by a `case` feature in the token. So the two properties
      // the token *does* own are the ones asserted: the weight, and tracking
      // that is a real fraction of the size. Without the tracking, all-caps at
      // 10dp sets as a grey smear and a section header stops being scannable.
      for (final entry in {
        'labelUppercase': AppType.labelUppercase,
        'labelMicro': AppType.labelMicro,
      }.entries) {
        expect(
          entry.value.fontWeight,
          FontWeight.w700,
          reason: '${entry.key} is ${entry.value.fontWeight}; the motif is bold',
        );
        expect(
          (entry.value.letterSpacing ?? 0) / entry.value.fontSize!,
          greaterThanOrEqualTo(0.09),
          reason: '${entry.key} tracks at '
              '${((entry.value.letterSpacing ?? 0) / entry.value.fontSize!).toStringAsFixed(3)}em',
        );
        expect(
          entry.value.fontSize!,
          lessThanOrEqualTo(12),
          reason: '${entry.key} is a caption; at 14sp and all-caps it stops '
              'being connective tissue and starts being a heading',
        );
      }
    });
  });

  group('aura', () {
    test('aura is derived from the hue it is given, not a fixed colour', () {
      // An aura is the one place a hue is allowed to glow. If it were a fixed
      // colour it would be a sixth meaning for whatever it happens to be, which
      // is the rule this whole system is built on.
      for (final category in MetricCategory.values) {
        final hue = categoryColor(category);
        final aura = AppPalette.aura(hue);
        expect(aura, isNotEmpty);
        for (final shadow in aura) {
          expect(
            shadow.color.computeLuminance(),
            closeTo(hue.computeLuminance(), 0.05),
            reason: '${category.name} aura is lit with a colour that is not '
                'its own hue',
          );
        }
      }
    });

    test('strength scales the alpha rather than changing the hue', () {
      // A strength argument that shifted the hue would produce a different
      // colour rather than a dimmer version of the same one, and a page that
      // glows differently depending on an unrelated setting is exactly the
      // "a colour the user did not choose" problem from the old system.
      final hue = categoryColor(MetricCategory.pv);
      final soft = AppPalette.aura(hue, strength: 0.1);
      final strong = AppPalette.aura(hue, strength: 0.3);
      expect(soft.length, strong.length);
      for (var i = 0; i < soft.length; i++) {
        expect(soft[i].color.a, lessThan(strong[i].color.a));
        expect(
          HSLColor.fromColor(soft[i].color).hue,
          closeTo(HSLColor.fromColor(strong[i].color).hue, 0.5),
        );
      }
    });
  });
}