import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

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
/// **It then held a second, newer set of wrong values, and that set is the one
/// that mattered.** The list was `0xFFF1F4F2` / `0xFFFAFBFA` / `0xFF161B19` /
/// `0xFF1E2422` / `0xFF1B211F` / `0xFF222A27`, hand-copied to describe the
/// opaque fills that had just replaced the glass. The soft-UI work then made a
/// third change to those fills — the light page went to `0xFFE1E7E4`, because
/// near-white left the light half of every shadow pair nowhere to be lighter
/// *to* — and this file was not updated with it. Every entry was stale.
///
/// The test kept passing, because the stale light values were *lighter* than the
/// real ones, so it was measuring against a more forgiving surface than the one
/// rendering. On the page that actually paints, `faintColor` was 4.47:1,
/// `statusBad` 4.48:1 and `statusAlert` 4.47:1 against a 4.5 requirement — all
/// three under AA, with the test green. Its own comment claimed "every hex
/// below is a fill that really exists", which was false for two commits.
///
/// So the list is read out of [AppSurfaces] rather than written here. A literal
/// in a test that is supposed to describe the app's own tokens is a copy that
/// can drift, and this one drifted twice, silently, in opposite directions.
final List<Color> _lightSurfaces = [
  AppSurfaces.pageLight, // page + card, which are the same colour
  AppSurfaces.chromeLight, // nav pill, app bar scrim
  AppSurfaces.inputLight, // input fields
  AppSurfaces.tooltipLight, // chart tooltip
  const Color(0xFFFFFFFF), // Material surfaces, e.g. a dialog
];

final List<Color> _darkSurfaces = [
  AppSurfaces.pageDark,
  AppSurfaces.chromeDark,
  AppSurfaces.inputDark,
  AppSurfaces.tooltipDark,
];

/// The fill `AppTile` actually paints, read out of the widget rather than
/// written down here.
///
/// **Why this needed its own accessor at all.** The tile and the progress bar
/// share one token, `AppSurfaces.track`, and they need opposite answers. The
/// exclusion below is correct for the bar and was silently wrong for the tile:
/// a bar is a 6–8dp strip with nothing drawn on it, while `AppTile` is a ~190dp
/// box carrying a caption and a delta. On the light track `#CFD6D2` those five
/// colours measured 3.85–3.87:1, five AA failures at 10–11dp, and this file was
/// green throughout because the track was excluded.
///
/// A single surface list cannot say "this consumer is text, that one is not",
/// so the distinction moved out of the list and into the widget: `AppTile` now
/// paints `AppSurfaces.input` and carries `AppElevation.inset` for the depth it
/// previously took from a darker fill. Dark mode is unchanged by that.
///
/// Reading the colour off the built widget rather than off `AppSurfaces` is the
/// third drift avoided. The two lists above were wrong three times because they
/// were copies; this one is the real `BoxDecoration`, so pointing `AppTile` back
/// at `track` fails here without anyone touching this file.
/// Renders an `AppTile` and returns the `BoxDecoration` it built.
///
/// A widget test rather than a constant, deliberately: `AppTile` builds a plain
/// `Container` with no key, so the only honest way to read the fill is to render
/// one and inspect the tree. `find.byType(Container)` would also match containers
/// the tile does not own, so this takes the *first*, which is the tile itself
/// because nothing inside it can precede it — and the optional accent
/// `ClipRRect`/`ColoredBox` wrap the tile rather than being wrapped by it.
Future<BoxDecoration> _tileDecoration(WidgetTester tester, bool isDark) async {
  await tester.pumpWidget(
    MaterialApp(home: AppTile(isDark: isDark, child: const SizedBox.shrink())),
  );
  final container = tester.widget<Container>(find.byType(Container).first);
  return container.decoration! as BoxDecoration;
}

/// The progress tracks (`AppSurfaces.trackLight` / `trackDark`) are deliberately
/// in neither list. A track is a 6 to 8dp bar and no text is ever drawn on one,
/// so including it measures a requirement that does not apply. It was in the
/// list while this was being written, and it failed all five colours at between
/// 4.31:1 and 4.39:1, because the light track is the darkest light-mode surface
/// in the app. Darkening every colour until it cleared the track was the other
/// option and it is the wrong one: it moves `faintColor` and four status colours
/// to satisfy a measurement of text on a bar that has none. If a caption ever
/// does get drawn over a track, add the track back here and reopen that call.
///
/// **This exclusion is now scoped to the bars alone, and it is no longer a
/// statement about the token.** It used to read as "nothing anywhere draws on
/// `AppSurfaces.track`", and `AppTile` drew on it at 190dp. The tile's fill moved
/// off `track` to `input`; the bars did not, because they still have no text on
/// them and still should not be darkened to satisfy a caption that is not there.
///
/// It is worth being explicit that the tracks are *not* exempt from the depth
/// work: they got a second, inset shadow pair rather than a lighter fill, for
/// the same reason the input fill is lighter than the page. Nothing about this
/// decision is about depth.

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

    void expectClearsAa(String name, Color color, List<Color> surfaces) {
      final ratios = surfaces.map((s) => _contrast(color, s)).toList();
      final worst = ratios.reduce(math.min);
      final worstSurface = surfaces[ratios.indexOf(worst)];
      expect(
        worst,
        greaterThanOrEqualTo(aa),
        reason: '$name measures ${worst.toStringAsFixed(2)}:1 on its worst '
            'surface #${worstSurface.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()} '
            '(${surfaces.map((s) => _contrast(color, s).toStringAsFixed(2)).join('/')})',
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

    testWidgets('AppTile draws text, so its own fill is a text surface', (
      tester,
    ) async {
      // The regression this guards: the tile fill used to be
      // `AppSurfaces.trackLight` `#CFD6D2`, the same token as the 6–8dp progress
      // bars, and the track was excluded from the surface lists above because
      // nothing draws on a bar. That exclusion was written for one consumer and
      // applied to two. Measured on `#CFD6D2` those five colours were 3.85,
      // 3.85, 3.87, 3.86 and 3.86 — every one of them under AA.
      for (final isDark in [false, true]) {
        final decoration = await _tileDecoration(tester, isDark);
        final fill = decoration.color!;

        expectClearsAa('faintColor on the tile fill, isDark=$isDark',
            faintColor(isDark), [fill]);
        expectClearsAa('statusOk on the tile fill, isDark=$isDark',
            statusOk(isDark), [fill]);
        expectClearsAa('statusWarn on the tile fill, isDark=$isDark',
            statusWarn(isDark), [fill]);
        expectClearsAa('statusBad on the tile fill, isDark=$isDark',
            statusBad(isDark), [fill]);
        expectClearsAa('statusAlert on the tile fill, isDark=$isDark',
            statusAlert(isDark), [fill]);
      }
    });

    testWidgets('the tile fill is not the progress-bar track', (tester) async {
      // Stated separately because the two lists above *do* still exclude the
      // track, and this is the assertion that keeps that exclusion honest: it is
      // scoped to the bars, not to the token.
      final light = await _tileDecoration(tester, false);
      expect(
        light.color,
        isNot(AppSurfaces.trackLight),
        reason: 'the light track is the darkest light surface in the app and '
            'fails AA with text on it; the tile needs input, the bars keep track',
      );
      expect(
        light.boxShadow,
        isNotNull,
        reason: 'a lighter fill cannot carry the inset read on its own — a '
            'BoxShadow paints outside the rect, so the depth has to be explicit',
      );
    });

    test('the surfaces this file measures against are the ones the app paints', () {
      // The guard against the second drift, which is the one that actually bit.
      //
      // It cannot be written as a comparison against a literal — a literal here
      // is the same copy that went stale twice — so what is asserted is the
      // *property* that made the old list wrong: the binding light surface is
      // the page, because it is the darkest light fill in the app, and the light
      // page is a mid-tone rather than anything near white.
      //
      // The near-white half matters for the shadows rather than for this test,
      // but it is the reason the page is mid-tone at all, so it is pinned here
      // rather than only in a comment.
      expect(
        AppSurfaces.pageLight,
        isNot(const Color(0xFFF1F4F2)),
        reason: 'the pre-restyle page colour, which this file measured against '
            'for two commits while the app painted something else',
      );
      expect(
        AppSurfaces.pageLight.computeLuminance(),
        lessThan(0.80),
        reason: 'a near-white page leaves the light half of every shadow pair '
            'nowhere to be lighter to, so cards read as flat Material',
      );
      expect(
        AppSurfaces.pageLight.computeLuminance(),
        greaterThan(0.60),
        reason: 'and a very dark page stops being the light theme',
      );
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
