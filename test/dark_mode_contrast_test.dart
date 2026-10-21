import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv/widgets/cctv_viewport.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The dark-ramp ink fixes, measured on the ground each ink is actually drawn on.
///
/// **The blue-glass conversion inverted one thing and the tests did not follow.**
/// Two moves happened together: the page became a ramped gradient whose ink
/// has to invert with the brightness (`AppGlass.pageInk*`), and the cards became
/// near-white in *both* ramps whose ink therefore does not (`AppSurfaces.onSurface*`,
/// navy twice). Every widget that sits directly on the page was therefore left
/// holding card ink — invisible on the dark ramp's own blue — and a few widgets
/// inside cards were left holding page or near-black ink, which is invisible on a
/// near-white fill.
///
/// `test/glass_ramp_contrast_test.dart` already pins page ink against the
/// gradient *stops*, glass ink against a white wash, and the accent and the
/// sheet in both ramps. None of that is re-asserted here. What is new, and what
/// this file owns, is the other two grounds the ink actually lands on:
///
///  * **`AppSurfaces.page`** — the flat page value, not a stop of the sweep. The
///    AI chat screen's background and the fill of three secondary buttons are
///    this colour, and nothing measured ink against it.
///  * **`AppSurfaces.surfaceMuted`** — not in `AppSurfaces.captionSurfaces()`,
///    so `theme_palette_contrast_test.dart` and `color_helpers_test.dart` both
///    skip it, and a markdown code block is drawn on it.
///  * **`cctvOverlayScrim`** — exported from the widget rather than copied here,
///    because a literal in a test whose job is to describe this app's own values
///    is a copy, and copies drift.
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
        // `AppSurfaces.onSurface` measured 1.22:1 here in dark mode, so the
        // button read as a black rectangle with no label.
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
        // **`onSurfaceVariant` is not in that list on purpose.** Measured against
        // `surfaceMuted` it is 4.63:1 in the dark ramp and **4.15:1** in the
        // light one, so it does not clear AA on this fill in both ramps. That is
        // why the inline chip stopped inheriting it from `bodyMedium` rather than
        // the muted value being quietly widened to fit.
        final ratio = _contrast(AppSurfaces.onSurface, AppSurfaces.surfaceMuted);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: card ink is ${ratio.toStringAsFixed(2)}:1 on '
              'AppSurfaces.surfaceMuted',
        );
      });

      test('the CCTV overlay ink clears AA on the overlay scrim', () {
        // The scrim is a very dark neutral in *both* ramps and never inverts,
        // because it covers camera pixels. Card ink is navy in both ramps too,
        // so the failure message and the two controls measured 1.25:1 in dark
        // *and* light mode — this one is not a ramp bug at all, it is a
        // near-black-on-near-black bug that both ramps share.
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
        // on the page. `AppPalette.error` is `#1D4ED8` in both ramps, and in
        // this one it lands at 1.09:1 on the ramp's own blue.
        //
        // 3:1 rather than 4.5:1 because the dot is a graphic and WCAG 1.4.11
        // asks 3:1 of graphics; the word beside it is measured by the page-ink
        // assertion above, which is the claim that actually carries the state.
        final accentInk = AppGlass.isDark ? AppPalette.onHue : AppPalette.error;
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

  test('the two ramps put card ink on a card and page ink on the page', () {
    // The inversion every fix above rests on, stated as the pair it is rather
    // than as four independent numbers. `AppSurfaces.surface` is near-white in
    // both ramps, so card ink is navy twice and does not move with the theme;
    // the page changes lightness between the ramps, so its ink has to.
    //
    // The last two assertions are the sharp edge of it. In the dark ramp, page
    // ink is *the wrong ink for a card* — that is not a subtle difference, it
    // is 1.05:1 — and that is exactly why the login screen's wordmark had to
    // come off `AppGlass.pageInkStrong` even though it looks correct in the
    // light ramp. A guard that only checked the light ramp would have called
    // that wordmark fine.
    AppTheme.apply(Brightness.dark);
    final darkCard = AppSurfaces.surface;
    final darkPageInk = AppGlass.pageInkStrong;
    AppTheme.apply(Brightness.light);
    final lightCard = AppSurfaces.surface;
    final lightPageInk = AppGlass.pageInkStrong;

    expect(
      AppSurfacesPalette.dark.onSurface,
      AppSurfacesPalette.light.onSurface,
      reason: 'card ink differs between the ramps, so "card ink" is not one '
          'thing and a widget on a card cannot be fixed by picking a ramp value',
    );
    expect(
      darkPageInk,
      isNot(lightPageInk),
      reason: 'page ink does not differ between the ramps, so the page and the '
          'card cannot share an ink',
    );
    expect(
      _contrast(darkPageInk, darkCard),
      lessThan(4.5),
      reason: 'page ink clears AA on a card in the dark ramp too, so the two '
          'families have converged and the distinction above is not '
          'load-bearing — check whether the cards really are near-white in both',
    );
    expect(
      _contrast(lightPageInk, lightCard),
      greaterThanOrEqualTo(4.5),
      reason: 'page ink is illegible on a card in the light ramp as well, which '
          'would mean the two families stopped being about the ramp at all',
    );
  });
}
