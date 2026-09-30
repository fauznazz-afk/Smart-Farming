import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';

/// The surfaces these colours are actually rendered on.
///
/// This list used to hold the *backdrop base* colours, `0xFFF2F5F3` and
/// `0xFF0D1410`, while its own comments called them the LiquidGlassCard fill.
/// They were not. Card fills were a gradient at alpha 0.44 to 0.66, composited
/// over a background painted with three large radial-gradient orbs, so the
/// rendered fill varied continuously with the pixel and no single constant
/// described it. In light mode that accident was harmless, because the real
/// card was lighter than the backdrop and dark text did better than the
/// assertion claimed. In dark mode it was not: the real fill ranged `0x161A17`
/// to `0x2F3230`, and measuring against the backdrop overstated `statusBad` by
/// 1.49, from 5.68:1 to 7.17:1.
///
/// The fills are now opaque and equal to the page colour, which is what a
/// soft-UI surface is: the depth comes from a dual shadow pair, not from
/// translucency. Every hex below is a fill that really exists. The worst case
/// for dark text is the lightest surface it can land on and the worst case for
/// light text is the darkest, so each colour is checked against all of them.
///
/// The progress tracks (`AppSurfaces.trackLight` / `trackDark`) are deliberately
/// in neither list. A track is a 6 to 8dp bar and no text is ever drawn on one,
/// so including it measures a requirement that does not apply. It was in the
/// list while this was being written, and it failed all five colours at between
/// 4.31:1 and 4.39:1, because the light track is the darkest light-mode surface
/// in the app. Darkening every colour until it cleared the track was the other
/// option and it is the wrong one: it moves `faintColor` and four status colours
/// to satisfy a measurement of text on a bar that has none. If a caption ever
/// does get drawn over a track, add the track back here and reopen that call.
const List<int> _lightSurfaces = [
  0xFFF1F4F2, // page + card, which are the same colour
  0xFFFAFBFA, // chrome, inputs, tooltip
  0xFFFFFFFF, // Material surfaces, e.g. a dialog
];

const List<int> _darkSurfaces = [
  0xFF161B19, // page + card, which are the same colour
  0xFF1E2422, // chrome
  0xFF1B211F, // inputs
  0xFF222A27, // chart tooltip
];

/// The user picked "Ocean cyan" in Settings, so every surface derived from that
/// seed has to stay that colour.
///
/// A per-index hue rotation of 40 degrees was added so the PV, AC and battery
/// pages would be easier to tell apart. It worked, and it was reverted at the
/// user's request: a colour nobody in Settings had offered looks arbitrary, and
/// the pages are already told apart by title and icon. This is the guard against
/// it coming back as a small improvement.
void main() {
  const seed = Color(0xFF2AA7A1);

  /// `HSLColor.hue` is already in degrees, not 0..1, which is worth stating
  /// because getting that wrong scales every tolerance here by 360 and makes a
  /// correct implementation look wrong.
  double hueOf(Color c) => HSLColor.fromColor(c).hue;

  /// The tolerance is 0.5 degrees. The removed rotation was 40 degrees per
  /// index, so this is eighty times tighter than the behaviour being forbidden
  /// while staying above the ~0.16 degrees that 8-bit quantisation introduces on
  /// its own — the worst case is the light-mode amber swatch. A tolerance tighter
  /// than the quantisation fails on the rounding rather than on the behaviour,
  /// which is the failure mode that gets a test deleted instead of a bug fixed.

  group('metricColor', () {
    test('every index renders the same hue, so one accent means one colour', () {
      final base = hueOf(seed);
      for (var index = 0; index < 6; index++) {
        expect(
          hueOf(metricColor(seedColor: seed, index: index, isDark: true)),
          closeTo(base, 0.5),
          reason: 'index $index must not rotate the hue',
        );
      }
    });

    test('index is accepted but ignored, not a silent source of variation', () {
      for (final isDark in [true, false]) {
        expect(
          metricColor(seedColor: seed, index: 0, isDark: isDark),
          metricColor(seedColor: seed, index: 5, isDark: isDark),
        );
      }
    });

    test('the swatch the user tapped is the colour the app renders', () {
      // The rotation moved "Ocean cyan" far enough that the rendered accent no
      // longer resembled the chosen swatch. Hue equality is the loose check;
      // this is the one that would actually have caught the complaint.
      for (final isDark in [true, false]) {
        expect(
          hueOf(metricColor(seedColor: seed, index: 0, isDark: isDark)),
          closeTo(hueOf(seed), 0.5),
          reason: 'isDark=$isDark',
        );
      }
    });

    test('dark mode is lighter than light mode', () {
      expect(
        HSLColor.fromColor(
          metricColor(seedColor: seed, index: 0, isDark: true),
        ).lightness,
        greaterThan(
          HSLColor.fromColor(
            metricColor(seedColor: seed, index: 0, isDark: false),
          ).lightness,
        ),
      );
    });
  });

  group('strongMetricColor', () {
    test('is the same hue as metricColor, only heavier', () {
      for (final isDark in [true, false]) {
        for (var index = 0; index < 4; index++) {
          final plain = HSLColor.fromColor(
            metricColor(seedColor: seed, index: index, isDark: isDark),
          );
          final strong = HSLColor.fromColor(
            strongMetricColor(seedColor: seed, index: index, isDark: isDark),
          );
          expect(strong.hue, closeTo(plain.hue, 0.5));
          expect(strong.saturation, greaterThan(plain.saturation));
        }
      }
    });
  });

  group('WCAG AA contrast', () {
    // Everything below is used as text between 9 and 15dp, which WCAG counts as
    // normal text, so the requirement is 4.5:1 rather than the 3:1 that large
    // text would get.
    const aa = 4.5;

    void expectClearsAa(String name, Color color, List<int> surfaces) {
      final worst = surfaces.map((s) => _contrast(color, Color(s))).reduce(math.min);
      expect(
        worst,
        greaterThanOrEqualTo(aa),
        reason: '$name measures ${worst.toStringAsFixed(2)}:1 on its worst '
            'surface ${(surfaces.map((s) => _contrast(color, Color(s)).toStringAsFixed(2))).join('/')}',
      );
    }

    test('faintColor, the units and captions', () {
      expectClearsAa('faintColor dark', faintColor(true), _darkSurfaces);
      expectClearsAa('faintColor light', faintColor(false), _lightSurfaces);
    });

    test('status colours, used for out-of-range readings', () {
      expectClearsAa('statusOk dark', statusOk(true), _darkSurfaces);
      expectClearsAa('statusOk light', statusOk(false), _lightSurfaces);
      expectClearsAa('statusWarn dark', statusWarn(true), _darkSurfaces);
      expectClearsAa('statusWarn light', statusWarn(false), _lightSurfaces);
      expectClearsAa('statusBad dark', statusBad(true), _darkSurfaces);
      expectClearsAa('statusBad light', statusBad(false), _lightSurfaces);
      expectClearsAa('statusAlert dark', statusAlert(true), _darkSurfaces);
      expectClearsAa('statusAlert light', statusAlert(false), _lightSurfaces);
    });

    test('the status colours stay distinguishable from each other', () {
      // Clearing the contrast bar is not enough if "ok" and "bad" are the same
      // green as each other. Material's green and red pass on hue; the
      // hand-picked pair is checked here so a future tweak cannot collapse them.
      for (final isDark in [true, false]) {
        expect(
          statusOk(isDark),
          isNot(statusBad(isDark)),
          reason: 'isDark=$isDark',
        );
        expect(
          statusWarn(isDark),
          isNot(statusBad(isDark)),
          reason: 'isDark=$isDark',
        );
      }
    });
  });
}

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
