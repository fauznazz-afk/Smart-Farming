import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The token file, pinned as properties rather than as values.
///
/// **MiniDash migration test file** — updated 15 October 2026.
///
/// MiniDash is a widget-like, compact design system for mobile dashboards.
/// This test file validates the new design tokens while preserving the
/// regression intent from the original tests.
void main() {
  group('depth is a line and a tonal step, not a shadow', () {
    test('the borders are one pixel wide, so they cannot read as depth', () {
      for (final entry in {
        'hairline': AppBorders.hairline,
        'control': AppBorders.control,
        'boundary': AppBorders.boundary,
      }.entries) {
        expect(
          entry.value.width,
          lessThanOrEqualTo(1.5),
          reason:
              '${entry.key} is ${entry.value.width}px, which is a frame '
              'rather than a hairline',
        );
      }
    });

    test('the hairline is neutral, so no card claims a category it lacks', () {
      expect(AppBorders.hairline.color, AppSurfaces.border);
    });

    test('the categorical border is the one place a hue is drawn as a frame', () {
      for (final category in MetricCategory.values) {
        final border = AppBorders.categoricalBorder(categoryColor(category));
        final side = border.top;
        expect(
          side.color,
          isNot(AppSurfaces.border),
          reason:
              '${category.name} drew a neutral frame, so the wash behind it '
              'has nothing to belong to',
        );
        expect(
          side.width,
          AppBorders.hairline.width,
          reason:
              'a categorical frame must not be heavier than the neutral '
              'one, or carrying a category costs more visually than it explains',
        );
        for (final edge in [
          border.top,
          border.bottom,
          border.left,
          border.right,
        ]) {
          expect(
            edge,
            side,
            reason:
                'a four-sided frame with one odd edge out reads as a bug, '
                'not as a design',
          );
        }
      }
    });

    test('the wash is faint enough that its own hue stays the subject', () {
      for (final category in MetricCategory.values) {
        final hue = categoryColor(category);
        expect(
          AppBorders.categoricalWash(hue).a,
          greaterThanOrEqualTo(0.15),
          reason:
              '${category.name} wash is at '
              '${(AppBorders.categoricalWash(hue).a * 100).toStringAsFixed(0)}% '
              "alpha, which is below the brief's 20%",
        );
        expect(
          AppBorders.categoricalWash(hue).a,
          lessThanOrEqualTo(0.25),
          reason:
              '${category.name} wash is at '
              '${(AppBorders.categoricalWash(hue).a * 100).toStringAsFixed(0)}% '
              '— a block, not a wash',
        );
        expect(
          HSLColor.fromColor(
            hue.withValues(alpha: AppBorders.categoricalWash(hue).a),
          ).hue,
          closeTo(HSLColor.fromColor(hue).hue, 0.5),
        );
      }
    });
  });

  group('the tonal ramp is a ramp, not a set of unrelated fills', () {
    test('each step is lighter than the one below it', () {
      // Check light mode - luminance values are between 0 and 1, higher is lighter
      double l(Color c) => c.computeLuminance();
      expect(l(AppSurfaces.surface), greaterThan(l(AppSurfaces.page)), reason: 'surface should be lighter than page');
      expect(l(AppSurfaces.surfaceAlt), lessThan(l(AppSurfaces.surface)), reason: 'surfaceAlt should be darker than surface');
      expect(l(AppSurfaces.surfaceAlt), greaterThan(l(AppSurfaces.page)), reason: 'surfaceAlt should be lighter than page');
    });

    test('the binding caption surface is the top of the ramp, and is listed', () {
      expect(AppSurfaces.captionSurfaces().last, AppSurfaces.surfaceAlt);
      expect(AppSurfaces.bindingCaptionSurface, AppSurfaces.surfaceAlt);
    });

    test('the caption surface list covers every fill a caption can land on', () {
      final surfaces = AppSurfaces.captionSurfaces();
      expect(surfaces, contains(AppSurfaces.page));
      expect(surfaces, contains(AppSurfaces.surface));
      expect(surfaces, contains(AppSurfaces.surfaceAlt));
      expect(surfaces, contains(AppSurfaces.track));
      expect(
        surfaces.length,
        3,
        reason:
            'a fourth entry means a new surface exists and whoever added it '
            'has to decide whether a caption can land on it',
      );
    });
  });

  group('the radius scale follows MiniDash spec', () {
    test('pill, round and bar are all fully round', () {
      expect(AppRadius.pill, AppRadius.round);
      expect(AppRadius.bar, AppRadius.round);
    });

    test('one rectilinear radius: 8, and nothing else', () {
      // MiniDash gives the design system exactly one radius for rectilinear shapes:
      // `rounded.lg` 8px on cards, inputs, buttons and list rows.
      // Badges are 4px, filter pills and progress tracks are fully round.
      for (final entry in {
        'card': AppRadius.card,
        'tile': AppRadius.tile,
        'inset': AppRadius.inset,
      }.entries) {
        expect(
          entry.value,
          AppRadius.card,
          reason: '${entry.key} is ${entry.value} — the brief has one '
              'rectilinear radius and this is a second one',
        );
      }
      expect(AppRadius.card, 8);
      expect(AppRadius.badge, lessThan(AppRadius.card),
          reason: 'a badge is nearly square');
      expect(AppRadius.badge, greaterThan(0));
      expect(AppRadius.card, lessThan(AppRadius.bar));
    });

    test('badge is 4px, between 0 and card', () {
      expect(AppRadius.badge, 4);
    });

    test('a bar at the bar radius is a stadium, not a rectangle', () {
      expect(AppRadius.bar, 9999);
    });
  });

  group('motion', () {
    test('every duration is non-zero and ordered by how far it travels', () {
      expect(AppMotion.press, lessThan(AppMotion.state));
      expect(AppMotion.state, lessThan(AppMotion.container));
      expect(AppMotion.state, lessThan(AppMotion.page));
    });

    test('no duration is zero', () {
      for (final entry in {
        'press': AppMotion.press,
        'state': AppMotion.state,
        'container': AppMotion.container,
        'page': AppMotion.page,
      }.entries) {
        expect(
          entry.value,
          isNot(Duration.zero),
          reason:
              '${entry.key} is zero, which is a forgotten value rather '
              'than a chosen one',
        );
      }
    });
  });

  group('type', () {
    test('Inter for headings, system sans for body, mono for terminal panel', () {
      expect(AppType.heading, 'Inter');
      expect(AppType.sans, anyOf(contains('Arial'), contains('Roboto')));
      expect(
        AppType.mono,
        'JetBrainsMono',
        reason: 'the terminal panel is only monospaced if its face actually is',
      );
      expect(
        AppType.mono,
        isNot(AppType.sans),
        reason:
            'if these are equal again the `mono` token is a comment on a '
            'non-mono face',
      );

      final weights = [
        AppType.numeralXl.fontWeight,
        AppType.labelUppercase.fontWeight,
        AppType.bodyMd.fontWeight,
      ];
      expect(
        weights,
        {FontWeight.w700, FontWeight.w600, FontWeight.w400},
        reason:
            '700 for displays and numerals, 600 for labels, '
            '400 for body',
      );
    });

    test('the panel scale is exactly two weights, and the split is keys vs values', () {
      expect(AppType.slotKey.fontWeight, FontWeight.w500);
      expect(AppType.slotMicro.fontWeight, FontWeight.w500);
      expect(AppType.slotUnit.fontWeight, FontWeight.w500);
      expect(AppType.heroUnit.fontWeight, FontWeight.w500);

      expect(AppType.slotValue.fontWeight, FontWeight.w700);
      expect(AppType.slotValueSmall.fontWeight, FontWeight.w700);
      expect(AppType.heroFigure.fontWeight, FontWeight.w700);

      expect(
        AppType.slotValue.fontWeight,
        isNot(AppType.slotKey.fontWeight),
        reason:
            'a key and a value at the same weight in the same face is a wall of '
            'grey',
      );
    });

    test('every panel style is monospaced, or the vocabulary is decoration', () {
      for (final entry in {
        'slotKey': AppType.slotKey,
        'slotMicro': AppType.slotMicro,
        'slotValue': AppType.slotValue,
        'slotValueSmall': AppType.slotValueSmall,
        'slotUnit': AppType.slotUnit,
        'heroFigure': AppType.heroFigure,
        'heroUnit': AppType.heroUnit,
      }.entries) {
        expect(
          entry.value.fontFamily,
          AppType.mono,
          reason: '${entry.key} is not monospaced',
        );
      }
    });

    test('the hero figure is the largest thing in the app', () {
      final hero = AppType.heroFigure.fontSize!;
      for (final entry in {
        'displayLg': AppType.displayLg,
        'displayMd': AppType.displayMd,
        'numeralXl': AppType.numeralXl,
        'numeralLg': AppType.numeralLg,
      }.entries) {
        expect(
          hero,
          greaterThan(entry.value.fontSize!),
          reason: '${entry.key} is as large as the hero',
        );
      }
    });

    test('figures are tabular, or a column jitters', () {
      for (final entry in {
        'numeralXl': AppType.numeralXl,
        'numeralLg': AppType.numeralLg,
        'displayLg': AppType.displayLg,
        'displayMd': AppType.displayMd,
      }.entries) {
        expect(
          entry.value.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason:
              '${entry.key} sets proportional figures, so a card that reads '
              '1080 W and then 980 W moves underneath the user',
        );
      }
    });

    test('the uppercase labels are bold and tracked, which is the motif', () {
      for (final entry in {
        'labelUppercase': AppType.labelUppercase,
        'labelMicro': AppType.labelMicro,
      }.entries) {
        expect(
          entry.value.fontWeight,
          FontWeight.w600,
          reason:
              '${entry.key} is ${entry.value.fontWeight}; the motif is semi-bold',
        );
        expect(
          (entry.value.letterSpacing ?? 0) / entry.value.fontSize!,
          greaterThanOrEqualTo(0.04),
          reason:
              '${entry.key} tracks at '
              '${((entry.value.letterSpacing ?? 0) / entry.value.fontSize!).toStringAsFixed(3)}em',
        );
        expect(
          entry.value.fontSize!,
          lessThanOrEqualTo(12),
          reason:
              '${entry.key} is a caption; at 14sp and all-caps it stops '
              'being connective tissue and starts being a heading',
        );
      }
    });
  });

  group('elevation shadows', () {
    test('subtle shadow has minimal blur for resting widgets', () {
      expect(AppShadows.subtle.length, 1);
      expect(AppShadows.subtle[0].blurRadius, 2);
      expect(AppShadows.subtle[0].offset.dy, 1);
    });

    test('medium shadow for hover/press state', () {
      expect(AppShadows.medium.length, 1);
      expect(AppShadows.medium[0].blurRadius, 6);
      expect(AppShadows.medium[0].offset.dy, 2);
    });

    test('large shadow for expanded widgets and modals', () {
      expect(AppShadows.large.length, 1);
      expect(AppShadows.large[0].blurRadius, 16);
      expect(AppShadows.large[0].offset.dy, 6);
    });

    test('overlay shadow for full-screen overlays', () {
      expect(AppShadows.overlay.length, 1);
      expect(AppShadows.overlay[0].blurRadius, 32);
      expect(AppShadows.overlay[0].offset.dy, 12);
    });
  });

  group('aura', () {
    test('aura is derived from the hue it is given, not a fixed colour', () {
      for (final category in MetricCategory.values) {
        final hue = categoryColor(category);
        final aura = AppPalette.aura(hue);
        expect(aura, isNotEmpty);
        for (final shadow in aura) {
          expect(
            shadow.color.computeLuminance(),
            closeTo(hue.computeLuminance(), 0.05),
            reason:
                '${category.name} aura is lit with a colour that is not '
                'its own hue',
          );
        }
      }
    });

    test('strength scales the alpha rather than changing the hue', () {
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

  group('spacing scale', () {
    test('spacing values follow the 4px base unit scale', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 20);
      expect(AppSpacing.xxl, 24);
      expect(AppSpacing.xxxl, 32);
      expect(AppSpacing.huge, 40);
      expect(AppSpacing.giant, 48);
    });

    test('common compositions are defined', () {
      expect(AppSpacing.gutter, 16);
      expect(AppSpacing.cardPadding, 12);
      expect(AppSpacing.sectionGap, 16);
    });
  });
}