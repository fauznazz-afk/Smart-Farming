import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The WattVision contrast claims, measured.
///
/// WattVision is dark-only: both ramps resolve to the same flat dark values.
/// Page #121212, cards #1E1E1E, glass ink measured against the single dark page.
double _contrast(Color a, Color b) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  final x = lum(a), y = lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  const ramps = <String, Brightness>{
    'dark': Brightness.dark,
    'light': Brightness.light,
  };

  setUp(() {});
  tearDown(() => AppTheme.apply(Brightness.dark));

  for (final entry in ramps.entries) {
    group('the ${entry.key} ramp', () {
      setUp(() => AppTheme.apply(entry.value));

      test('the accent ink clears AA on the accent fill', () {
        // The filled button, the selected date chip and the nav bubble all draw
        // `onHue` on the accent, so this is the app's largest text colour.
        final ratio = _contrast(AppPalette.onHue, AppPalette.accent);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: onHue on the accent is '
              '${ratio.toStringAsFixed(2)}:1',
        );
      });

      test('the accent clears AA as a caption on the card surfaces', () {
        // The accent draws panel headings and the selected chip's label, so it
        // is text on a white card and not only a graphic.
        for (final surface in <Color>[
          AppSurfaces.surface,
          AppSurfaces.surfaceAlt,
        ]) {
          final ratio = _contrast(AppPalette.accent, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: the accent on the card is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('page ink clears AA on the page it is drawn on', () {
        // The bug this file exists for: page ink is the nav bar's inactive
        // glyph, the hour pills and the page-level headings, all of which sit on
        // the gradient rather than inside a card.
        for (final ink in <Color>[
          AppGlass.pageInkStrong,
          AppGlass.pageInk,
          AppGlass.pageInkSoft,
        ]) {
          for (final page in AppGlass.pageGradient) {
            final ratio = _contrast(ink, page);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: '${entry.key}: page ink is '
                  '${ratio.toStringAsFixed(2)}:1 on a page stop',
            );
          }
        }
      });

      test('glass ink clears AA on its own glass fill over every page stop', () {
        // **Glass carries DARK ink, and this is the rule that makes the wash
        // safe.** The wash is always white, so the pill is a light chip whatever
        // page is behind it — which means its label must be dark. An earlier
        // version inverted the wash to black "to match the ink", which drags the
        // pill toward the ink on it and loses the contrast the wash was there to
        // buy.
        for (final fill in <Color>[AppGlass.fillSoft, AppGlass.fillStrong]) {
          for (final page in AppGlass.pageGradient) {
            final washed = Color.alphaBlend(fill, page);
            for (final ink in <Color>[
              AppGlass.pageGlassInk,
              AppGlass.pageGlassInkSoft,
            ]) {
              final ratio = _contrast(ink, washed);
              expect(
                ratio,
                greaterThanOrEqualTo(4.5),
                reason: '${entry.key}: glass ink is '
                    '${ratio.toStringAsFixed(2)}:1 on a glass wash over a page stop',
              );
            }
          }
        }
      });

      test('the glass wash is white in both ramps', () {
        // Pinned because inverting it is the tempting fix and it is the wrong
        // one: a black wash under dark ink loses the lift the wash exists for.
        // The lever is the ink, not the wash.
        expect(
          AppGlass.fillSoft.computeLuminance(),
          greaterThan(0.9),
          reason: '${entry.key}: the glass wash is not white in this ramp',
        );
      });

      test('the hero ink clears AA on every stop of the hero gradient', () {
        // The hero is a deep gradient and its ink is white at three strengths.
        // This pins that claim rather than assuming it.
        for (final stop in AppGlass.heroGradient) {
          for (final ink in <Color>[
            AppGlass.inkStrong,
            AppGlass.ink,
            AppGlass.inkSoft,
          ]) {
            final ratio = _contrast(ink, stop);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: '${entry.key}: hero ink is '
                  '${ratio.toStringAsFixed(2)}:1 on a hero stop',
            );
          }
        }
      });

      test('the sheet ink clears AA on the sheet', () {
        // The sheet is an opaque card, so its ink is measured against it.
        for (final pair in <List<Color>>[
          <Color>[AppGlass.sheetTitleInk, AppGlass.sheet],
          <Color>[AppGlass.sheetRowInk, AppGlass.sheetRow],
          <Color>[AppGlass.sheetRowInkMuted, AppGlass.sheetRow],
        ]) {
          final ratio = _contrast(pair[0], pair[1]);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: sheet ink is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('a breach stays red and stays distinguishable from the accent', () {
        // The accent is cyan, so red means exactly one thing. If the two ever
        // collide, "this reading is wrong" and "this is the app's colour" become
        // the same pixel.
        expect(
          AppPalette.statusBad,
          isNot(AppPalette.accent),
          reason: '${entry.key}: the accent and the breach are the same colour',
        );
      });
    });
  }

  test('each ramp carries its own accent and its own fill ink', () {
    // The ramps are no longer copies: the dark accent is a bright green that
    // takes dark ink, the light one a deep green that takes white.
    expect(AppPaletteTheme.light.accent, isNot(AppPaletteTheme.dark.accent));
    expect(AppPaletteTheme.light.onHue, const Color(0xFFFFFFFF));
    expect(AppPaletteTheme.dark.onHue, const Color(0xFF121212));
  });

  test('the page is a flat fill in both ramps, and each stays flat', () {
    // Both page lists are single-value sweeps: three identical stops, so the
    // gradient renders flat. What differs is the value, not the shape.
    for (final page in [
      AppGlass.pageGradientDark,
      AppGlass.pageGradientLight,
    ]) {
      expect(page.toSet().length, 1, reason: 'the page sweep is not flat');
    }
    expect(
      AppGlass.pageGradientLight.last.computeLuminance(),
      greaterThan(AppGlass.pageGradientDark.last.computeLuminance()),
      reason: 'the light page must be the lighter ground',
    );
  });
}
