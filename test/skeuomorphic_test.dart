import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Every surface a skeuomorphic fill is laid on, read out of the tokens
  // rather than written down: `AGENTS.md` records two silent drifts from a
  // hand-copied surface list in `color_helpers_test.dart`.
  final surfaces = <AppTheme, List<Color>>{
    for (final theme in AppTheme.values)
      theme: [
        AppSurfaces.page(theme),
        AppSurfaces.card(theme),
        AppSurfaces.chrome(theme),
        AppSurfaces.input(theme),
      ],
  };

  group('a skeuomorphic fill only ever moves away from its text', () {
    // The whole layer rests on this. If a fill stop could move *toward* the
    // text, the token would stop being the worst case and every contrast proof
    // in `color_helpers_test.dart` would be measuring the wrong surface.
    for (final theme in AppTheme.values) {
      // The text colours actually drawn on these surfaces.
      final texts = <String, Color>{
        'faintColor': faintColor(theme.isDark),
        'statusBad': statusBad(theme.isDark),
        'statusAlert': statusAlert(theme.isDark),
        'body': AppSkeuo.textSide(theme),
      };
      for (final base in surfaces[theme]!) {
        for (final text in texts.entries) {
          test('${theme.name} ${text.key} on #${base.toARGB32().toRadixString(16)}',
              () {
            final atToken = contrast(base, text.value);
            for (final stop in AppSkeuo.fill(
              base,
              foreground: text.value,
              travel: AppSkeuo.controlTravel,
            )) {
              expect(
                contrast(stop, text.value),
                greaterThanOrEqualTo(atToken - 1e-9),
                reason: 'a gradient stop is closer to the text than the token '
                    'is, so the token is no longer the worst case',
              );
            }
          });
        }
      }
    }
  });

  test('one stop of every fill is exactly the token', () {
    // Which is what lets the existing contrast tests stand unchanged: they
    // measure the token, and the token is still on screen.
    for (final theme in AppTheme.values) {
      for (final base in surfaces[theme]!) {
        final stops = AppSkeuo.fill(base, foreground: AppSkeuo.textSide(theme));
        expect(stops, contains(base));
      }
    }
  });

  test('no gloss behind light text', () {
    // A gloss lightens. Behind light text that lowers the ratio, so on every
    // dark surface the bevel carries the highlight instead.
    for (final theme in AppTheme.values.where((t) => t.isDark)) {
      for (final base in surfaces[theme]!) {
        expect(AppSkeuo.gloss(base, foreground: AppSkeuo.textSide(theme)),
            isNull);
      }
    }
    expect(
      AppSkeuo.gloss(
        AppSurfaces.card(AppTheme.light),
        foreground: AppSkeuo.textSide(AppTheme.light),
      ),
      isNotNull,
    );
  });

  test('the badge wash never exceeds the alpha it was measured at', () {
    // `AppBadge` records 0.08 at 4.63:1 and 0.12 at 4.39:1; the gradient that
    // was reverted had a top stop at alpha + 0.04.
    for (final theme in AppTheme.values) {
      final alpha = theme.isDark ? 0.18 : 0.08;
      for (final stop in AppSkeuo.badgeWash(
        const Color(0xFFD97706),
        alpha: alpha,
        theme: theme,
      )) {
        expect(stop.a, lessThanOrEqualTo(alpha + 1e-9));
      }
    }
  });

  test('the rim is lit from the top left, and adds no hue', () {    // The highlight is lighter than the surface and the shade darker, in that
    // order, and a well swaps them. Both are mixes of the surface with neutral
    // light, so neither can carry a hue the surface did not already have: the
    // hairline note records a tinted edge putting a green rim on every card.
    for (final theme in AppTheme.values) {
      for (final base in surfaces[theme]!) {
        final raised = AppSkeuo.rim(base, theme).colors;
        final l = base.computeLuminance();
        expect(raised.first.computeLuminance(), greaterThan(l));
        expect(raised.last.computeLuminance(), lessThan(l));
        final well = AppSkeuo.rim(base, theme, inverted: true).colors;
        expect(well, raised.reversed.toList());
      }
    }
  });
}
