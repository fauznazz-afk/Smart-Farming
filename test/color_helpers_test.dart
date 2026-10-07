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
///
/// **It is read out of `AppSurfaces.captionSurfaces` now rather than assembled
/// here, and that is the third drift avoided.** Even derived, the list was four
/// hand-picked constants long, which meant adding a surface to a theme was a
/// change in *this* file that nothing would remind you to make — and adding a
/// whole theme, which is what Dracula is, would have left the new theme
/// untested by default. Reading the whole list means a new theme is covered the
/// moment it has a page colour, which is what the `AppTheme.values` loop below
/// now does.
final List<Color> _lightSurfaces = AppSurfaces.captionSurfaces(AppTheme.light);

final List<Color> _darkSurfaces = AppSurfaces.captionSurfaces(AppTheme.dark);

/// Dracula's four caption surfaces, read out the same way.
///
/// The one that decides every measurement here is the chrome step `#343746`: it
/// is the lightest surface in the ramp at relative luminance 0.0390, against the
/// page's 0.0237, so it is what a caption actually sits on when the worst case
/// is asked for. See `design_tokens.dart` for why the list is derived.
final List<Color> _draculaSurfaces =
    AppSurfaces.captionSurfaces(AppTheme.dracula);

/// The five colours every caption and status reading in the app is drawn in.
///
/// Grouped because they are the palette whose reuse across the two dark themes
/// is the load-bearing claim of this file: `faintColor` and the four status
/// colours take a `bool isDark`, and Dracula passes `AppTheme.dracula.isDark`,
/// which is `true`. This list is what makes that identity assertionable rather
/// than a comment.
List<Color> _captionPalette(bool isDark) => [
  faintColor(isDark),
  statusOk(isDark),
  statusWarn(isDark),
  statusBad(isDark),
  statusAlert(isDark),
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
///
/// **Two layers since the skeuomorphic pass, and both are returned.** The tile
/// is a chamfered rim (`AppSkeuo.rim`) with the fill inset inside it, so the
/// first `Container` is the rim — which carries the inset shadow — and the
/// second is the fill the text is actually drawn on.
Future<({BoxDecoration rim, BoxDecoration fill})> _tileDecoration(
  WidgetTester tester,
  bool isDark,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppTile(
        theme: isDark ? AppTheme.dark : AppTheme.light,
        child: const SizedBox.shrink(),
      ),
    ),
  );
  final layers = tester
      .widgetList<Container>(find.byType(Container))
      .take(2)
      .map((c) => c.decoration! as BoxDecoration)
      .toList();
  return (rim: layers[0], fill: layers[1]);
}

/// Every colour a tile's text can land on: each stop of the fill gradient.
///
/// Measuring every stop is *stricter* than the single flat fill this used to
/// read. `AppSkeuo.fill` promises the token is the worst stop, and this is the
/// check that the promise holds on the surface actually rendered.
List<Color> _tileFillStops(BoxDecoration fill) =>
    (fill.gradient! as LinearGradient).colors;

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
        for (final theme in AppTheme.values) {
          expect(
            hueOf(metricColor(seedColor: seed, index: index, theme: theme)),
            closeTo(base, 0.5),
            reason: '${theme.name} index $index must not rotate the hue',
          );
        }
      }
    });

    test('index is accepted but ignored, not a silent source of variation', () {
      for (final theme in AppTheme.values) {
        expect(
          metricColor(seedColor: seed, index: 0, theme: theme),
          metricColor(seedColor: seed, index: 5, theme: theme),
        );
      }
    });

    test('the swatch the user tapped is the colour the app renders', () {
      // The rotation moved "Ocean cyan" far enough that the rendered accent no
      // longer resembled the chosen swatch. Hue equality is the loose check;
      // this is the one that would actually have caught the complaint.
      for (final theme in AppTheme.values) {
        expect(
          hueOf(metricColor(seedColor: seed, index: 0, theme: theme)),
          closeTo(hueOf(seed), 0.5),
          reason: theme.name,
        );
      }
    });

    test('both dark themes are lighter than the light theme', () {
      // Dracula belongs with the dark themes on brightness, and this is the
      // check that keeps it there. It is not free: Dracula's metric lightness
      // is 0.78 against the dark theme's 0.68, so if somebody "fixed" the
      // purple contrast problem by dropping it back to 0.68 this fails, which is
      // exactly the change that would put it at 4.35:1.
      final light = HSLColor.fromColor(
        metricColor(seedColor: seed, index: 0, theme: AppTheme.light),
      ).lightness;
      for (final theme in [AppTheme.dark, AppTheme.dracula]) {
        expect(
          HSLColor.fromColor(
            metricColor(seedColor: seed, index: 0, theme: theme),
          ).lightness,
          greaterThan(light),
          reason: theme.name,
        );
      }
    });
  });

  group('strongMetricColor', () {
    test('is the same hue as metricColor, only heavier', () {
      for (final theme in AppTheme.values) {
        for (var index = 0; index < 4; index++) {
          final plain = HSLColor.fromColor(
            metricColor(seedColor: seed, index: index, theme: theme),
          );
          final strong = HSLColor.fromColor(
            strongMetricColor(seedColor: seed, index: index, theme: theme),
          );
          expect(strong.hue, closeTo(plain.hue, 0.5), reason: theme.name);
          expect(strong.saturation, greaterThan(plain.saturation),
              reason: theme.name);
        }
      }
    });
  });

  group('the Dracula accent', () {
    // Every number in this group was measured against the real Dracula ramp, and
    // the assertion is the measured ratio rather than a hex literal. A hex would
    // pass or fail on rounding and say nothing about *why* the value is the one
    // it is; the ratio fails the moment the derivation stops clearing AA, which
    // is the thing that would actually reach a user as an unreadable number.
    const aa = 4.5;

    /// The four surfaces an accent is ever drawn on.
    ///
    /// `AppSurfaces.captionSurfaces` rather than the text list, because the
    /// accent is not only a caption: it is a progress bar fill, a chart line and
    /// a nav label, and the chrome step is where it is least legible. The track
    /// is not included and the reason is on `AppSurfaces.captionSurfaces`: a
    /// track carries no accent either — the bars are neutral by design, because
    /// an accent-coloured bar is a second accent competing with the value it
    /// measures.
    final surfaces = <Color>[
      AppSurfaces.pageDracula,
      AppSurfaces.chromeDracula,
      AppSurfaces.inputDracula,
      AppSurfaces.tooltipDracula,
    ];

    /// Worst case over [surfaces], which is always the chrome step.
    double worst(Color accent) => surfaces
        .map((s) => _contrast(accent, s))
        .reduce(math.min);

    test('the seed is Dracula\'s own purple, and it already clears AA', () {
      // The finding that makes the preset affordable at all: no derivation, no
      // re-tuning, no second palette. 5.90:1 on the page, 4.89:1 on chrome.
      expect(
        worst(draculaAccent),
        greaterThanOrEqualTo(aa),
        reason: 'Dracula\'s purple at ${worst(draculaAccent).toStringAsFixed(2)}:1 '
            'worst; if this fails the seed was changed, and the seed is supposed '
            'to be the palette value verbatim',
      );
    });

    test('metricColor clears AA on every Dracula surface', () {
      // The rejected value, for the record: routing Dracula's purple through
      // the dark theme's own lightness of 0.68 gives `#A479E2`, which is 4.35:1
      // on the page and 3.60:1 on chrome — under AA on both, and the reason the
      // accent needs a per-theme lightness at all.
      final accent = metricColor(
        seedColor: draculaAccent,
        index: 0,
        theme: AppTheme.dracula,
      );
      expect(
        worst(accent),
        greaterThanOrEqualTo(aa),
        reason: 'metricColor came out ${worst(accent).toStringAsFixed(2)}:1 '
            'worst. The derivation is a per-theme HSL lightness, not a hue '
            'rotation -- if the hue is still 264.7 then the lightness is wrong.',
      );
    });

    test('strongMetricColor clears AA, and beats metricColor on contrast', () {
      // The second half of that assertion is the one that is easy to lose. In
      // the dark theme `strongMetricColor` is *darker* than `metricColor`, on the
      // reasoning that more saturation at lower lightness reads heavier. Purple
      // cannot do that and stay compliant: the strongest purple that clears AA on
      // chrome at the metric's saturation is 5.16:1, which is quieter than the
      // metric colour's 5.45. So in Dracula the strong variant has to go up in
      // lightness, and the property that has to hold is contrast, not the
      // lightness relationship the other two themes share.
      final plain = metricColor(
        seedColor: draculaAccent,
        index: 0,
        theme: AppTheme.dracula,
      );
      final strong = strongMetricColor(
        seedColor: draculaAccent,
        index: 0,
        theme: AppTheme.dracula,
      );

      expect(
        worst(strong),
        greaterThanOrEqualTo(aa),
        reason: 'strongMetricColor came out ${worst(strong).toStringAsFixed(2)}:1 '
            'worst',
      );
      expect(
        worst(strong),
        greaterThan(worst(plain)),
        reason: 'a hero value that is quieter than an ordinary one is not '
            'strong; strong is ${worst(strong).toStringAsFixed(2)}:1 against '
            'plain ${worst(plain).toStringAsFixed(2)}:1',
      );
    });

    test('the accent is still the palette colour, not a rotation of it', () {
      // One colour the user did not choose is a colour they cannot predict --
      // the same rule that reverted the 40-degree per-index rotation. Asserted
      // on Dracula's own seed so that a future "Dracula but warmer" tweak fails
      // here rather than shipping.
      for (final theme in AppTheme.values) {
        expect(
          hueOf(metricColor(seedColor: draculaAccent, index: 0, theme: theme)),
          closeTo(hueOf(draculaAccent), 0.5),
          reason: theme.name,
        );
      }
    });

    test('HSL lightness is not perceptual, which is why 0.78 and not 0.68', () {
      // The measurement behind the per-theme constant. The same HSL lightness
      // that is comfortably compliant for the app's green lands under AA for
      // Dracula's purple, because green carries far more luminance than purple
      // does at equal lightness. Any single lightness that satisfies one hue
      // breaks another, so the constant has to be per theme.
      final green = metricColor(
        seedColor: const Color(0xFF35A968),
        index: 0,
        theme: AppTheme.dark,
      );
      final purple = metricColor(
        seedColor: draculaAccent,
        index: 0,
        theme: AppTheme.dracula,
      );
      expect(
        _contrast(purple, AppSurfaces.pageDracula),
        lessThan(_contrast(green, AppSurfaces.pageDracula)),
        reason: 'purple ${_contrast(purple, AppSurfaces.pageDracula).toStringAsFixed(2)}:1 '
            'against green ${_contrast(green, AppSurfaces.pageDracula).toStringAsFixed(2)}:1. '
            'The dark theme\'s 0.68 would put the purple at 4.35:1, under AA.',
      );
    });

    test('presetAccent is Dracula\'s colour and null for the other two', () {
      expect(presetAccent(AppTheme.dracula), draculaAccent);
      expect(presetAccent(AppTheme.dark), isNull,
          reason: 'a null is what makes `presetAccent(theme) ?? seedColor` unable '
              'to disagree with itself');
      expect(presetAccent(AppTheme.light), isNull);
      expect(AppTheme.dracula.usesPresetAccent, isTrue);
      expect(AppTheme.dark.usesPresetAccent, isFalse);
      expect(AppTheme.light.usesPresetAccent, isFalse);
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
      expectClearsAa('faintColor dracula', faintColor(true), _draculaSurfaces);
    });

    test('status colours, used for out-of-range readings', () {
      expectClearsAa('statusOk dark', statusOk(true), _darkSurfaces);
      expectClearsAa('statusOk light', statusOk(false), _lightSurfaces);
      expectClearsAa('statusOk dracula', statusOk(true), _draculaSurfaces);
      expectClearsAa('statusWarn dark', statusWarn(true), _darkSurfaces);
      expectClearsAa('statusWarn light', statusWarn(false), _lightSurfaces);
      expectClearsAa('statusWarn dracula', statusWarn(true), _draculaSurfaces);
      expectClearsAa('statusBad dark', statusBad(true), _darkSurfaces);
      expectClearsAa('statusBad light', statusBad(false), _lightSurfaces);
      expectClearsAa('statusBad dracula', statusBad(true), _draculaSurfaces);
      expectClearsAa('statusAlert dark', statusAlert(true), _darkSurfaces);
      expectClearsAa('statusAlert light', statusAlert(false), _lightSurfaces);
      expectClearsAa('statusAlert dracula', statusAlert(true), _draculaSurfaces);
    });

    test('every caption colour clears AA on every theme\'s own surfaces', () {
      // The enum loop. The five individual assertions above are the ones that
      // print a readable name on failure, and this is the one that cannot be
      // forgotten when a theme is added — a hardcoded list of themes is exactly
      // the `[true, false]` mistake `design_tokens_test.dart` had to be
      // unpicked from, and it is the reason the surface list was ever a copy.
      for (final theme in AppTheme.values) {
        final surfaces = AppSurfaces.captionSurfaces(theme);
        final names = [
          'faintColor',
          'statusOk',
          'statusWarn',
          'statusBad',
          'statusAlert',
        ];
        for (var i = 0; i < _captionPalette(theme.isDark).length; i++) {
          expectClearsAa(
            '${names[i]} on ${theme.name}',
            _captionPalette(theme.isDark)[i],
            surfaces,
          );
        }
      }
    });

    test('Dracula reuses the dark palette rather than adding one', () {
      // The guard against a later reader "fixing" Dracula by giving it its own
      // text colours. It is the identity, not an approximation: `faintColor` and
      // the four status colours still take a `bool isDark`, and a Dracula call
      // site passes `AppTheme.dracula.isDark`, which is `true`. So the six
      // Dracula-facing lines resolve to the same five constants as the dark
      // theme's, and a duplicated palette would be protecting nothing -- it
      // would be five more values to keep in step with the surfaces.
      expect(AppTheme.dracula.isDark, isTrue,
          reason: 'the whole reason there is no Dracula text palette');
      for (final color in _captionPalette(true)) {
        expect(_captionPalette(AppTheme.dracula.isDark), contains(color));
      }
      expect(_captionPalette(true), _captionPalette(AppTheme.dracula.isDark));
      expect(_captionPalette(false), isNot(_captionPalette(true)),
          reason: 'and the light palette must stay a separate set of constants');
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
        final fill = _tileFillStops(decoration.fill);

        expectClearsAa('faintColor on the tile fill, isDark=$isDark',
            faintColor(isDark), fill);
        expectClearsAa('statusOk on the tile fill, isDark=$isDark',
            statusOk(isDark), fill);
        expectClearsAa('statusWarn on the tile fill, isDark=$isDark',
            statusWarn(isDark), fill);
        expectClearsAa('statusBad on the tile fill, isDark=$isDark',
            statusBad(isDark), fill);
        expectClearsAa('statusAlert on the tile fill, isDark=$isDark',
            statusAlert(isDark), fill);
      }
    });

    testWidgets('the tile fill is not the progress-bar track', (tester) async {
      // Stated separately because the two lists above *do* still exclude the
      // track, and this is the assertion that keeps that exclusion honest: it is
      // scoped to the bars, not to the token.
      final tile = await _tileDecoration(tester, false);
      final light = tile.rim;
      expect(
        _tileFillStops(tile.fill),
        isNot(contains(AppSurfaces.trackLight)),
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
