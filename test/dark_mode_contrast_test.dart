import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv/widgets/cctv_viewport.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// WattVision ink contrast, measured on the single dark ramp.
///
/// WattVision is dark-only: both ThemeMode resolve to the same flat dark values.
/// Page #121212, cards #1E1E1E. This file asserts ink tokens clear AA on those
/// surfaces and that applying ThemeMode.light still yields dark tokens.
double _contrast(Color a, Color b) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  final x = lum(a), y = lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  const ramps = <String, Brightness>{
    'dark': Brightness.dark,
    'light': Brightness.light,
  };

  tearDown(() => AppTheme.apply(Brightness.dark));

  for (final entry in ramps.entries) {
    group('the ${entry.key} ramp', () {
      setUp(() => AppTheme.apply(entry.value));

      test('page ink clears AA on the flat page value', () {
        // `AppSurfaces.page` is not a stop of `AppGlass.pageGradient` and the
        // two disagree in this ramp by design — the flat value is the
        // overscroll fallback and the AI chat screen's own background. It is
        // also the *fill* of the energy report's period button and of the
        // settings screen's `SecondaryButton`, which is why the ink there has to
        // follow the page rather than the card.
        //
        // The failure this guards is specific and it is the one that shipped:
        // `AppSurfaces.onSurface` measured 1.22:1 here, so the button read as a
        // black rectangle with no label.
        for (final ink in <Color>[
          AppGlass.pageInkStrong,
          AppGlass.pageInk,
          AppGlass.pageInkSoft,
        ]) {
          final ratio = _contrast(ink, AppSurfaces.page);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: page ink is ${ratio.toStringAsFixed(2)}:1 '
                'on AppSurfaces.page',
          );
        }
      });

      test('card ink clears AA on the muted surface', () {
        // `surfaceMuted` is deliberately absent from `captionSurfaces()` — it is
        // a chart bar's empty column and the inline-code chip, not a caption
        // surface — so neither caption-contrast test looks at it. A markdown code
        // block and an inline code span are drawn on it, and both now say
        // `AppSurfaces.onSurface` explicitly.
        //
        // **`onSurfaceVariant` is not in that list on purpose.** It does not
        // clear AA on this fill, which is why the inline chip stopped inheriting
        // it from `bodyMedium` rather than the muted value being quietly widened
        // to fit.
        final ratio = _contrast(AppSurfaces.onSurface, AppSurfaces.surfaceMuted);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: card ink is ${ratio.toStringAsFixed(2)}:1 on '
              'AppSurfaces.surfaceMuted',
        );
      });

      test('the CCTV overlay ink clears AA on the overlay scrim', () {
        // The scrim is a very dark neutral and never changes, because it covers
        // camera pixels. Card ink answers the app's own surfaces and not this
        // one, so the failure message and the two controls need ink that does not
        // follow the palette — otherwise this is a near-black-on-near-black bug.
        //
        // `cctvOverlayScrim` is imported rather than written down here.
        for (final ink in <Color>[AppGlass.ink, AppGlass.inkStrong]) {
          final ratio = _contrast(ink, cctvOverlayScrim);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: overlay ink is ${ratio.toStringAsFixed(2)}:1 '
                'on the CCTV scrim',
          );
        }
      });

      test('the accent clears 3:1 as a graphic on the page', () {
        // The chart section header's live/polling dot and its "Live" word are
        // the one place in the app where a *saturated hue* is asked to be ink
        // on the page, which is a different ground from a card.
        //
        // 3:1 rather than 4.5:1 because the dot is a graphic and WCAG 1.4.11
        // asks 3:1 of graphics; the word beside it is measured by the page-ink
        // assertion above, which is the claim that actually carries the state.
        final accentInk = AppGlass.accentOnPage;
        for (final page in <Color>[
          AppSurfaces.page,
          ...AppGlass.pageGradient,
        ]) {
          final ratio = _contrast(accentInk, page);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key}: the page accent ink is '
                '${ratio.toStringAsFixed(2)}:1 on a page value',
          );
        }
      });
    });
  }

  /// **The bottom bar is a surface, and its glyphs are ink on it.**
  ///
  /// This is the pair the nav bar shipped wrong twice: first a white 68% wash
  /// (a pale bar docked on a dark app), then `surfaceAlt` (a slab lighter than
  /// the cards above it). Neither is a contrast failure — both were *legible* —
  /// which is exactly why only a token-level assertion pins the surface a docked
  /// bar is allowed to use. The selected glyph sits on the accent bubble and is
  /// measured separately below.
  test('nav bar glyphs clear AA on the bar surface', () {
    for (final bar in <Color>[AppSurfaces.surface, AppSurfaces.surfaceAlt]) {
      final inactive = _contrast(AppSurfaces.onSurfaceVariant, bar);
      expect(
        inactive,
        greaterThanOrEqualTo(4.5),
        reason: 'inactive nav glyph is ${inactive.toStringAsFixed(2)}:1 on a '
            'bar surface',
      );
    }
    // The selected glyph is `onHue` on the accent bubble, not on the bar.
    final selected = _contrast(AppPalette.onHue, AppPalette.error);
    expect(
      selected,
      greaterThanOrEqualTo(4.5),
      reason: 'selected nav glyph is ${selected.toStringAsFixed(2)}:1 on the '
          'accent bubble',
    );
  });

  test('theme application is dark-only', () {
    AppTheme.apply(Brightness.dark);
    final darkCard = AppSurfaces.surface;
    final darkPageInk = AppGlass.pageInkStrong;
    AppTheme.apply(Brightness.light);
    final lightCard = AppSurfaces.surface;
    final lightPageInk = AppGlass.pageInkStrong;

    expect(AppTheme.brightness, Brightness.dark);
    expect(
      AppSurfacesPalette.dark.onSurface,
      AppSurfacesPalette.light.onSurface,
    );
    expect(darkCard, lightCard);
    expect(darkPageInk, lightPageInk);
    expect(_contrast(darkPageInk, darkCard), greaterThanOrEqualTo(4.5));
  });
}
