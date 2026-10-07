// Does `main.dart` actually publish the Dracula theme?
//
// **This file exists because the Dracula branch used to be unreachable, and
// nothing in the repo could see that.** The surface widgets resolve their
// [AppTheme] from the `ThemeData` that `MaterialApp` publishes, and the way they
// tell Dracula from the app's own dark mode is by comparing
// `Theme.of(context).scaffoldBackgroundColor` against `AppSurfaces.pageDracula`.
// `ThemeOption.dracula` maps to `ThemeMode.dark`, so `brightness` reads the same
// for both dark presets and cannot carry the answer — which means the *only*
// thing that makes Dracula render at all is the published scaffold colour.
//
// So this asserts the published value rather than the value `main.dart` writes
// into it, and it compares against the token rather than a hex. A literal here
// would be the same class of copy that went stale silently twice in this repo's
// own `color_helpers_test.dart`, and it would go stale again the moment a
// surface moved — while this file still went on asserting that the app paints
// a colour it no longer paints.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/main.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// WCAG 2.x contrast ratio, via Flutter's own relative luminance.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance() + 0.05;
    final lb = b.computeLuminance() + 0.05;
    return (la > lb ? la : lb) / (la < lb ? la : lb);
  }

  /// Pumps the real app widget with a stored theme option.
  ///
  /// [PltsMonitoringApp] rather than a hand-built `MaterialApp`, because the
  /// thing under test *is* the wiring between the controller and the published
  /// theme. A test that constructed its own `MaterialApp` would pass with the
  /// app's own `darkTheme` left at the dark page, which is precisely the bug.
  Future<void> pumpApp(
    WidgetTester tester, {
    required String storedOption,
    Brightness platformBrightness = Brightness.light,
  }) async {
    SharedPreferences.setMockInitialValues({'theme_mode': storedOption});
    tester.platformDispatcher.platformBrightnessTestValue =
        platformBrightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const PltsMonitoringApp());
    // Not `pumpAndSettle`: the splash shows a `CircularProgressIndicator` and
    // the login form's `TextField` blinks a cursor, both of which animate
    // forever, so settling never happens. What has to complete instead is the
    // controller's `load()` — a real async `SharedPreferences` read — plus the
    // `AnimatedBuilder` rebuild it triggers, and both need more than one frame
    // because the preference read resolves in a later microtask.
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The theme the tree is actually being painted with.
  ThemeData publishedTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first));

  group('the Dracula branch is reachable', () {
    testWidgets('publishes Dracula\'s own page, not the app\'s dark page', (
      tester,
    ) async {
      await pumpApp(tester, storedOption: 'dracula');

      // Read out of `AppSurfaces` rather than written as `#282A36`.
      expect(
        publishedTheme(tester).scaffoldBackgroundColor,
        AppSurfaces.page(AppTheme.dracula),
      );

      // The negative, which is the assertion that carries the weight. Without it
      // this would still pass if `page(AppTheme.dracula)` and `pageDark` ever
      // converged, and it states *which wrong value* the preset must not
      // publish: the app's own dark page.
      expect(
        publishedTheme(tester).scaffoldBackgroundColor,
        isNot(AppSurfaces.pageDark),
        reason: 'a Dracula page with the app\'s dark fill is not Dracula; this is '
            'the failure the widget layer cannot detect on its own, because it '
            'falls back to AppTheme.dark when no page colour matches',
      );
    });

    testWidgets('a widget with no explicit theme resolves to Dracula', (
      tester,
    ) async {
      await pumpApp(tester, storedOption: 'dracula');

      // The end of the chain: `AppBackground` is required to take an `AppTheme`,
      // but `AppCard`'s is optional and falls back to reading the published
      // theme — so this is the one place in the app where the scaffold colour
      // alone has to carry the preset. A card painted in Dracula's page colour
      // with Dracula's shadow pair is the observable end of main.dart's wiring.
      await tester.pumpWidget(
        MaterialApp(
          theme: publishedTheme(tester),
          home: const Scaffold(body: AppCard(child: Text('probe'))),
        ),
      );

      final decorated = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = decorated.decoration! as BoxDecoration;

      // **Read through the skeuomorphic layer, which is the only change here.**
      // This used to assert `decoration.color`; the card is now a chamfered
      // rim with the fill inset inside it (`AppSkeuo.rim`), so there is no flat
      // colour to read. The claim is unchanged: the rim is mixed from Dracula's
      // card token, which a card resolved to the app's dark preset would not be.
      expect(
        (decoration.gradient! as LinearGradient).colors,
        AppSkeuo.rim(AppSurfaces.card(AppTheme.dracula), AppTheme.dracula)
            .colors,
        reason: 'the card must be painted from Dracula\'s surface token',
      );
      // Dracula's raised pair is three shadows with its own alphas, and its
      // geometry is shared with the dark set - so the alphas are what a reader
      // can check, and they are not the dark set's. The skeuomorphic layer adds
      // one wider depth shadow *after* the pair, so the pair is the prefix.
      final raised = AppElevation.raised(AppTheme.dracula);
      expect(
        decoration.boxShadow!.take(raised.length).toList(),
        raised,
        reason: 'the card must be on Dracula\'s elevation ramp, not the app\'s '
            'dark one - the page is 1.7x lighter and the alphas were solved for '
            'it separately',
      );
    });
  });

  group('the Dracula accent is not re-derived', () {
    testWidgets('primary is the measured accent, not ColorScheme.fromSeed', (
      tester,
    ) async {
      await pumpApp(tester, storedOption: 'dracula');

      final primary = publishedTheme(tester).colorScheme.primary;

      // What `color_helpers.dart` measured: Dracula's purple at the preset's own
      // lightness, 5.45:1 on the chrome step.
      expect(
        primary,
        metricColor(
          seedColor: draculaAccent,
          index: 0,
          theme: AppTheme.dracula,
        ),
      );

      // And the failure this guards, stated as a number. `fromSeed` maps the same
      // seed to `#6B538C`, which is both far too dark for a dark page and
      // visibly not Dracula's purple — the reason the seed is used verbatim and
      // the *derivation* is what `main.dart` replaces.
      final derived = ColorScheme.fromSeed(
        seedColor: draculaAccent,
        brightness: Brightness.dark,
      );
      expect(
        primary,
        isNot(derived.primary),
        reason: 'ColorScheme.fromSeed darkens a seed to keep it legible on a '
            'light surface, which is the wrong direction here; it yields '
            '$derived.primary against Dracula\'s own $draculaAccent',
      );
    });

    testWidgets('the published scheme clears AA on the binding surface', (
      tester,
    ) async {
      await pumpApp(tester, storedOption: 'dracula');
      final scheme = publishedTheme(tester).colorScheme;

      // The chrome step is the binding surface: it is the lightest in the ramp
      // (relative luminance 0.0390 against the page's 0.0237), so anything that
      // clears it clears the other three. This is the check that `fromSeed` would
      // fail — its `#6B538C` primary measures about 1.5:1 on the page — and the
      // reason `main.dart` derives these roles rather than mapping a seed.
      for (final surface in <Color>[
        AppSurfaces.page(AppTheme.dracula),
        AppSurfaces.chrome(AppTheme.dracula),
        AppSurfaces.input(AppTheme.dracula),
      ]) {
        expect(
          contrast(scheme.primary, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'primary ${scheme.primary} on ${surface.toARGB32().toRadixString(16)}',
        );
        expect(
          contrast(scheme.onSurface, surface),
          greaterThanOrEqualTo(4.5),
        );
        // The label on the accent fill, which is a button's whole job.
        expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets('the accent comes from the preset, not the stored seed', (
      tester,
    ) async {
      // A stored seed that is nothing like purple, so a theme built from it
      // cannot be mistaken for the preset's. Read out of the controller rather
      // than written here — the value under test is "whatever seed the user last
      // picked", and the default is as good a witness as any, but a literal
      // would be a fifth place that knows what green the app ships with.
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dracula',
        'theme_seed': AppThemeController.defaultSeed.toARGB32(),
      });
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(const PltsMonitoringApp());
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // A green primary under Dracula would be the app's dark theme wearing a
      // purple page, which is the state `AppThemeController.accent` was
      // introduced to make unrepresentable.
      final primary = publishedTheme(tester).colorScheme.primary;
      final seedHue = HSLColor.fromColor(AppThemeController.defaultSeed).hue;
      expect(
        (HSLColor.fromColor(primary).hue - seedHue).abs(),
        greaterThan(20),
        reason: 'the accent must come from presetAccent(AppTheme.dracula), not '
            'from the seed the user last picked',
      );
      expect(
        primary,
        metricColor(
          seedColor: draculaAccent,
          index: 0,
          theme: AppTheme.dracula,
        ),
      );
    });
  });

  group('the existing two modes are unchanged', () {
    testWidgets('light publishes the light page and the stored seed', (
      tester,
    ) async {
      await pumpApp(tester, storedOption: 'light');

      expect(
        publishedTheme(tester).scaffoldBackgroundColor,
        AppSurfaces.page(AppTheme.light),
      );
      // `ColorScheme.fromSeed` is still correct for the two modes that follow the
      // user's seed — the tonal mapping exists to make a picked accent legible,
      // which is what it is for there.
      expect(
        publishedTheme(tester).colorScheme.primary,
        ColorScheme.fromSeed(
          // Read out of the controller, not written here: a literal would be
          // another copy of "the green the app ships with", and the copy would
          // outlive the value.
          seedColor: AppThemeController.defaultSeed,
          brightness: Brightness.light,
        ).primary,
      );
    });

    testWidgets('dark publishes the dark page', (tester) async {
      await pumpApp(tester, storedOption: 'dark');

      expect(
        publishedTheme(tester).scaffoldBackgroundColor,
        AppSurfaces.page(AppTheme.dark),
      );
    });
  });

  group('the system option resolves its brightness', () {
    testWidgets('a light system publishes the light theme', (tester) async {
      await pumpApp(
        tester,
        storedOption: 'system',
        platformBrightness: Brightness.light,
      );

      // `ThemeMode.system` is resolved by `MaterialApp` from the platform
      // brightness, and `main.dart` builds the light slot for it. This pins the
      // observable half of the contract in
      // `PltsMonitoringApp.didChangePlatformBrightness`.
      //
      // **What this cannot currently catch, stated plainly:** it passes even if
      // the controller's cached `resolvedBrightness` were never updated, because
      // the `theme` slot is always the light theme and the `darkTheme` slot is
      // always `AppTheme.dark` unless a preset is active — and `presetAccent`
      // returns `null` for both light and dark, so `accent` is the stored seed
      // either way. Breaking `resolve()` therefore changes nothing a test can
      // see today; this is here so the contract is asserted before a second
      // brightness-dependent preset makes it load-bearing, rather than after.
      expect(
        publishedTheme(tester).scaffoldBackgroundColor,
        AppSurfaces.page(AppTheme.light),
      );
    });

    testWidgets('a dark system publishes the dark theme', (tester) async {
      await pumpApp(
        tester,
        storedOption: 'system',
        platformBrightness: Brightness.dark,
      );

      expect(
        publishedTheme(tester).scaffoldBackgroundColor,
        AppSurfaces.page(AppTheme.dark),
      );
    });

    testWidgets('the accent follows the resolved brightness, not a guess', (
      tester,
    ) async {
      await pumpApp(
        tester,
        storedOption: 'system',
        platformBrightness: Brightness.light,
      );
      final lightPrimary = publishedTheme(tester).colorScheme.primary;

      await pumpApp(
        tester,
        storedOption: 'system',
        platformBrightness: Brightness.dark,
      );
      final darkPrimary = publishedTheme(tester).colorScheme.primary;

      // One seed, two brightnesses: `ColorScheme.fromSeed` derives a different
      // primary for each, so both themes really are built from their own
      // brightness and neither is the other's colour scheme reused.
      expect(
        lightPrimary,
        isNot(darkPrimary),
        reason: 'a `system` option that derived one accent and shared it across '
            'both slots would make these equal',
      );
      expect(
        lightPrimary,
        ColorScheme.fromSeed(
          seedColor: AppThemeController.defaultSeed,
          brightness: Brightness.light,
        ).primary,
      );
      expect(
        darkPrimary,
        ColorScheme.fromSeed(
          seedColor: AppThemeController.defaultSeed,
          brightness: Brightness.dark,
        ).primary,
      );
    });
  });

}
