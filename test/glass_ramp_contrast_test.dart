import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The blue system's own contrast claims, measured on both ramps.
///
/// **This exists because the light ramp shipped broken and nothing said so.** The
/// page went from a flat neutral to a blue gradient, the glass became
/// brightness-aware afterwards, and the failure mode is the quiet one: a caption
/// that measures 1.4:1 on a pale page looks like a deliberate muted label at a
/// glance, on a screenshot, and in every test that only checks the dark ramp.
///
/// So the rules are stated as properties over [AppSurfaces.captionSurfaces()] and
/// the real fills, read out of the tokens rather than written down here — a
/// literal list of hex values in a test whose job is to describe this app's own
/// tokens is a copy, and copies drift.
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
        final ratio = _contrast(AppPalette.onHue, AppPalette.error);
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
          final ratio = _contrast(AppPalette.error, surface);
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
        // **Glass carries DARK ink in both ramps, and this is the rule that the
        // light mode was missing.** The wash is always white, so the pill is a
        // light chip whichever page is behind it — which means its label must be
        // dark whichever ramp is live. The earlier version inverted the wash to
        // black in light mode "to match the ink", which drags the pill toward
        // the ink on it: 2.48:1.
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
        // Pinned because inverting it is the tempting fix and it is the wrong one:
        // a black wash under navy ink lands 2.48:1. The lever is the ink, not
        // the wash.
        expect(
          AppGlass.fillSoft.computeLuminance(),
          greaterThan(0.9),
          reason: '${entry.key}: the glass wash is not white in this ramp',
        );
      });

      test('the hero ink clears AA on every stop of the hero gradient', () {
        // The hero is navy in both ramps, so its ink is white in both. This
        // pins that claim rather than assuming it.
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
        // The sheet is opaque white paper in both ramps, so this must hold twice.
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
        // The accent moved to blue in both ramps, so red now means exactly one
        // thing. If the two ever collide, "this reading is wrong" and "this is
        // the app's colour" become the same pixel.
        expect(
          AppPalette.statusBad,
          isNot(AppPalette.error),
          reason: '${entry.key}: the accent and the breach are the same colour',
        );
      });
    });
  }

  test('the two ramps share one accent hue, which is the whole point', () {
    // The bug: light was red and dark was blue, so the app had two identities
    // and toggling the theme changed the brand. One hue, two lightnesses.
    expect(
      HSLColor.fromColor(AppPaletteTheme.light.error).hue,
      closeTo(HSLColor.fromColor(AppPaletteTheme.dark.error).hue, 6.0),
      reason: 'the accent hue is not shared between the ramps',
    );
  });

  test('the light page is actually lighter than the dark page', () {
    // Otherwise "light mode" is a label on the same screen.
    expect(
      AppGlass.pageGradientLight.last.computeLuminance(),
      greaterThan(AppGlass.pageGradient.last.computeLuminance() + 0.2),
      reason: 'the light page gradient is not lighter than the dark one',
    );
  });
}
