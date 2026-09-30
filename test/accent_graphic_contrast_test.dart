/// The accessibility defects found by auditing the accent system, pinned.
///
/// Three claims were checked while building the Dracula theme and each produced a
/// different answer than expected, which is why this file exists rather than a
/// line in a commit message.
///
/// **Measured, not assumed:**
///   * `metricColor` as a *graphic* on the light page is 2.28 / 2.88 / 2.16 / 2.21
///     for the four accents the user can pick — three of four fail WCAG 1.4.11's
///     3:1 for a graphical object. `metricGraphic` exists because of that.
///   * White on Dracula's `#C1A3EB` is 2.16:1, which is why the CCTV play button
///     stopped hardcoding `Colors.white`.
///   * `AppElevation.boundaryEdge` was reported as under 3:1 and is **not** — it
///     measures 7.41:1 on the light page. The report was wrong and the assertion
///     below exists so nobody re-raises it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _contrast(Color a, Color b) {
  double l(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
  final x = l(a), y = l(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

/// The four accents in `kAccentPalette`, and the ones that matter here.
const Map<String, Color> accents = {
  'EnerGrow green': Color(0xFF35A968),
  'Solar amber': Color(0xFFE0A020),
  'Ocean cyan': Color(0xFF2AA7A1),
  'Forest teal': Color(0xFF2F8F7A),
};

void main() {
  group('metricGraphic clears 1.4.11 where metricColor does not', () {
    test('every accent, every theme, on the card it is drawn on', () {
      for (final theme in AppTheme.values) {
        for (final a in accents.entries) {
          for (final surface in {
            'card': AppSurfaces.card(theme),
            'chrome': AppSurfaces.chrome(theme),
            'input': AppSurfaces.input(theme),
          }.entries) {
            final g = metricGraphic(
              seedColor: a.value,
              index: 0,
              theme: theme,
            );
            expect(
              _contrast(g, surface.value),
              greaterThanOrEqualTo(3.0),
              reason: '$theme ${a.key} graphic #${_hex(g)} is '
                  '${_contrast(g, surface.value).toStringAsFixed(2)}:1 on '
                  '${surface.key}; 1.4.11 wants 3:1 for a graphical object and '
                  '`metricColor` alone measures 2.16-2.88 on the light page',
            );
          }
        }
      }
    });

    test('and the claim it exists for is still true of metricColor', () {
      // If `metricColor` ever reaches 3:1 on the light page for every accent,
      // `metricGraphic` is redundant and this file should argue for deleting it
      // rather than keeping a second derivation alive.
      //
      // Asserting the *defect* rather than the fix means this test fails when
      // the underlying problem is solved -- which is the point. It should not be
      // made to pass by loosening it.
      final belowThree = accents.entries.where((a) {
        final m = metricColor(
          seedColor: a.value,
          index: 0,
          theme: AppTheme.light,
        );
        return _contrast(m, AppSurfaces.card(AppTheme.light)) < 3.0;
      }).length;
      expect(
        belowThree,
        greaterThanOrEqualTo(3),
        reason: 'metricColor now clears 3:1 as a graphic on the light page for '
            'every accent, so metricGraphic is redundant and should be removed '
            'rather than kept as a second derivation',
      );
    });

    test('it stays in the user\'s hue', () {
      // The extra contrast must not be bought with a different colour. This is
      // the rule AGENTS.md states about not inventing hues.
      for (final theme in AppTheme.values) {
        for (final a in accents.entries) {
          final seedHue = HSLColor.fromColor(a.value).hue;
          final g = metricGraphic(
            seedColor: a.value,
            index: 0,
            theme: theme,
          );
          expect(
            (HSLColor.fromColor(g).hue - seedHue).abs(),
            lessThan(6.0),
            reason: '$theme ${a.key} graphic #${_hex(g)} drifted from its seed',
          );
        }
      }
    });

    test('it does not change text, which has its own requirement', () {
      // The whole reason `metricGraphic` is separate is that darkening
      // `metricColor` would restyle every metric *value* in the app. If
      // `metricGraphic` were folded back into it, that would have happened.
      final before = metricColor(
        seedColor: accents['Ocean cyan']!,
        index: 0,
        theme: AppTheme.light,
      );
      final after = metricGraphic(
        seedColor: accents['Ocean cyan']!,
        index: 0,
        theme: AppTheme.light,
      );
      expect(
        after,
        isNot(before),
        reason: 'metricGraphic and metricColor are now the same colour, so the '
            'light accent is either 2.16:1 as a graphic or the text values '
            'changed too. One of those two is the defect this avoids.',
      );
    });
  });

  group('onPrimaryInk', () {
    test('puts a legible ink on every accent fill the app can produce', () {
      final fills = <String, Color>{
        // `filledButtonTheme` in main.dart derives its fill per mode.
        'EnerGrow light fill': const Color(0xFF35A968),
        'EnerGrow dark fill': const Color(0xFF79E2A7),
        'Solar amber fill': const Color(0xFFE2BF79),
        'Ocean cyan dark fill': const Color(0xFF79E2DD),
        // And the Dracula preset, which is the one that broke it.
        'Dracula primary': metricColor(
          seedColor: draculaAccent,
          index: 0,
          theme: AppTheme.dracula,
        ),
        'Dracula primaryContainer': strongMetricColor(
          seedColor: draculaAccent,
          index: 0,
          theme: AppTheme.dracula,
        ),
      };

      for (final f in fills.entries) {
        final ink = onPrimaryInk(f.value);
        expect(
          _contrast(ink, f.value),
          greaterThanOrEqualTo(4.5),
          reason: '${f.key} #${_hex(f.value)} with ink #${_hex(ink)} is '
              '${_contrast(ink, f.value).toStringAsFixed(2)}:1. White on '
              "Dracula's primary is 2.16:1, which is what this exists for.",
        );
      }
    });

    test('white really does fail, so the function is not decorative', () {
      final draculaPrimary = metricColor(
        seedColor: draculaAccent,
        index: 0,
        theme: AppTheme.dracula,
      );
      expect(
        _contrast(Colors.white, draculaPrimary),
        lessThan(3.0),
        reason: 'white now clears 3:1 on Dracula\'s primary, so the '
            'cctv_viewport override it replaced can go back to a constant',
      );
    });
  });

  group('boundaryEdge', () {
    test('does clear 3:1, contrary to a report that said it did not', () {
      // An agent reviewing the CCTV work reported this as under 3:1. It is not:
      // 7.41:1 on the light page and 11.79-16.39:1 on the dark presets. The
      // assertion is here because a claim like that gets repeated, and the
      // cheapest thing in this repo is a number that settles it.
      for (final theme in AppTheme.values) {
        final edge = AppElevation.boundaryEdge(theme: theme);
        for (final s in {
          'page': AppSurfaces.page(theme),
          'chrome': AppSurfaces.chrome(theme),
        }.entries) {
          expect(
            _contrast(edge, s.value),
            greaterThanOrEqualTo(3.0),
            reason: '$theme boundaryEdge #${_hex(edge)} on ${s.key}',
          );
        }
      }
    });
  });
}