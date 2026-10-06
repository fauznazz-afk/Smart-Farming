import 'dart:async';
// `PlatformDispatcher` is the object `WidgetsBinding.platformDispatcher` is an
// instance of. Named explicitly because the app only needs the one symbol, and
// an unqualified `dart:ui` import would put `TextStyle`-adjacent names such as
// `Color` and `Offset` into this file's namespace where a `Color` typo becomes
// an ambiguity rather than an error.
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/thingsboard_api.dart';
import 'utils/app_log.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme_controller.dart';
import 'widgets/brand_logo.dart';
import 'screens/dashboard/utils/color_helpers.dart';
import 'widgets/liquid_glass.dart';
import 'screens/dashboard/utils/design_tokens.dart';
import 'services/alarm_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PltsMonitoringApp());
  unawaited(_initializeAlarmServices());
}

/// The accent a control paints with, in a form that has been measured.
///
/// For the two themes that follow the user's seed this is unchanged:
/// `themeColor` at the lightness that mode has always used. Dracula cannot go
/// through it. `themeColor` is an HSL lightness step and HSL lightness is not
/// perceptual across hues — at the dark theme's 0.68 the app's green measures
/// 8.98:1 on Dracula's page while Dracula's own purple measures 4.35:1, a
/// factor of two apart at the same number. So a preset that carries its own
/// accent has to ask for it by name, and [metricColor] already holds the
/// per-theme lightness that was solved for it (0.78, measured, with the margin
/// written out in `color_helpers.dart`).
///
/// A second reason not to reach for `themeColor` with Dracula's purple: it
/// would be a *third* place choosing a lightness for the preset, next to the two
/// that are already measured and tested.
Color _controlAccent(
  Color seed,
  AppTheme theme, {
  required double darkLightness,
  required double lightLightness,
}) =>
    theme.usesPresetAccent
        ? metricColor(seedColor: seed, index: 0, theme: theme)
        : themeColor(
            seedColor: seed,
            lightness: theme.isDark ? darkLightness : lightLightness,
          );

/// Styling for every `SegmentedButton` in the app.
///
/// Material fills the selected segment with the colour scheme's
/// `secondaryContainer`, which `ColorScheme.fromSeed` derives by desaturating the
/// seed until it reads as a neutral. With the default green that is invisible;
/// with "Solar amber" it produced a muddy olive block on a near-black card,
/// which is the one place in the app where the chosen accent looked broken.
///
/// The accent is applied directly instead, at a low alpha over the card, so the
/// selected segment reads as the user's colour at a weight that does not compete
/// with the numbers in the card below it. Three separate call sites use
/// `SegmentedButton`, so this lives in the theme rather than in each of them.
///
/// [seed] is passed in rather than read from the context because a
/// `ThemeData` is built before there is one to read from. Hard-coding the amber
/// here instead would have fixed the screenshot and broken the other three
/// palette entries, which is the mistake the rest of this app keeps making.
///
/// [theme] is the appearance rather than a [Brightness], because the selected
/// segment's fill is derived from the accent and Dracula's accent needs a
/// different lightness — see [_controlAccent].
SegmentedButtonThemeData _segmentedTheme(Color seed, AppTheme theme) {
  final isDark = theme.isDark;
  final accent = _controlAccent(
    seed,
    theme,
    darkLightness: 0.68,
    lightLightness: 0.34,
  );
  return SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: isDark ? 0.22 : 0.16)
            : Colors.transparent,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent
            // `faintColor`, not `Colors.white70` / `Colors.black54`. That pair
            // is the one `color_helpers.dart` replaced because it measures
            // about 3.4:1, and an unselected segment's label is 14sp — under
            // the 18.66px large-text floor, so 4.5:1 is the requirement.
            : faintColor(isDark),
      ),
      side: WidgetStatePropertyAll(
        BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
    ),
  );
}

/// The app's buttons, which until now had no theme at all.
///
/// `filledButtonTheme` was simply absent, so every `FilledButton` in the app --
/// "Sign in", "Save settings", "Play camera" -- was a raw Material
/// `colorScheme.primary` block with a default elevation and the
/// framework's own corner radius. Two things were wrong with that on a device,
/// and only one of them was cosmetic:
///
/// The shape was flat. A flat saturated block sitting on an opaque page is the
/// exact opposite of a soft-UI surface, and it was the loudest thing in every
/// screenshot.
///
/// The text failed contrast. `ColorScheme.fromSeed` maps a green seed to a
/// *light* green in dark mode, and it paired that with a light `onPrimary`, so
/// the label came out white on light green -- about 1.5:1. That is a hard fail,
/// not a taste question, and it is why this cannot be fixed by styling the
/// shape alone.
///
/// So the fill and the label are derived here rather than inherited, from the
/// user's own seed at a lightness chosen per mode: dark green with white text
/// in light mode, mid green with near-black text in dark. `themeColor` is the
/// same function the segmented control uses, so the two agree, and the accent
/// stays the colour the user picked.
FilledButtonThemeData _buttonTheme(Color seed, AppTheme theme) =>
    FilledButtonThemeData(
      style: _buttonStyle(seed, theme),
    );

ButtonStyle _buttonStyle(Color seed, AppTheme theme) {
  final isDark = theme.isDark;
  final fill = _controlAccent(
    seed,
    theme,
    // In dark mode 0.68 is too light to carry white text, which is what the
    // framework default was doing. 0.52 keeps the hue and puts the fill in a
    // band where a near-black label is comfortably legible.
    darkLightness: 0.52,
    lightLightness: 0.34,
  );
  // 0x14 in light mode is the faintest accent that still clears 3:1 on the
  // page, which is the WCAG 1.4.11 bar for a control boundary.
  final outline = fill;
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(fill),
    foregroundColor: WidgetStatePropertyAll(
      isDark ? const Color(0xFF10201A) : Colors.white,
    ),
    elevation: const WidgetStatePropertyAll(0),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: BorderSide(color: outline.withValues(alpha: isDark ? 0.9 : 1)),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

/// The app's input fields.
///
/// The fill is *lighter* than the page in light mode and a step up in dark mode,
/// which is the opposite of the conventional inset treatment. That is
/// deliberate. The old light `fillColor` was `0xFFEBEFEA`, and it was the
/// binding surface for all five colour assertions in
/// `test/color_helpers_test.dart` — every pinned colour cleared 4.5:1 by less
/// than 0.43. Darkening it, which is what an inset field normally does, would
/// have dropped `faintColor` and four status colours below AA at the same time.
/// The deboss now comes from the border being an accent-tinted line rather than
/// a grey one, which is the same information carried by the hairline everywhere
/// else in the app.
InputDecorationTheme _inputTheme(AppTheme theme) {
  return InputDecorationTheme(
    filled: true,
    fillColor: AppSurfaces.input(theme),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.inset),
      borderSide: BorderSide(color: appDivider(theme: theme, opacity: 0.22)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.inset),
      borderSide: BorderSide(color: appDivider(theme: theme, opacity: 0.22)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.inset),
      borderSide: const BorderSide(color: Colors.white, width: 1.6),
    ),
  );
}

/// The Dracula `ColorScheme`.
///
/// **`ColorScheme.fromSeed` is deliberately not used, and the reason is a
/// measurement rather than a preference.** Material's tonal mapping takes a seed
/// and derives a colour chosen to stay legible on a *light* surface, so feeding
/// it Dracula's own purple `#BD93F9` lands `primary` on `#6B538C`: far too dark
/// for a `#282A36` page, and visibly not Dracula's purple either. The seed value
/// itself is correct — it measures 5.90:1 on the page and 4.89:1 on the chrome
/// step, which is the binding surface — so it is the *derivation* that has to be
/// replaced, not the colour.
///
/// So the accent roles come from the two functions in `color_helpers.dart` that
/// already hold the measured per-theme lightnesses for this preset:
/// [metricColor] (lightness 0.78, 5.45:1 on chrome) and [strongMetricColor]
/// (0.82, 5.89:1). Re-deriving a purple here would be a third place choosing a
/// lightness for the preset, next to the two that carry the measurements.
///
/// The surface roles come from [AppSurfaces], for the same reason the
/// `scaffoldBackgroundColor` does — `test/color_helpers_test.dart` measures
/// against those values, and a hand-written hex in a `ColorScheme` is a copy
/// that would drift the moment a surface moved.
ColorScheme _draculaScheme(Color accent) {
  // The dark ink on an accent fill. The same value `_buttonStyle` already uses
  // for a dark-mode button label, so the filled button and the Material
  // `primary` role agree on what ink sits on the accent.
  const onAccent = Color(0xFF10201A);
  final primary = metricColor(
    seedColor: accent,
    index: 0,
    theme: AppTheme.dracula,
  );
  final strong = strongMetricColor(
    seedColor: accent,
    index: 0,
    theme: AppTheme.dracula,
  );
  return ColorScheme.dark(
    primary: primary,
    onPrimary: onAccent,
    primaryContainer: strong,
    onPrimaryContainer: onAccent,
    // The secondary and tertiary roles are the same accent at the same two
    // measured lightnesses rather than two more hues. The app's own rule is
    // that it never invents a colour, and a preset that grew its own second
    // hue would be a second rule living in one theme.
    secondary: primary,
    onSecondary: onAccent,
    secondaryContainer: strong,
    onSecondaryContainer: onAccent,
    tertiary: strong,
    onTertiary: onAccent,
    surface: AppSurfaces.page(AppTheme.dracula),
    onSurface: appPrimaryText(AppTheme.dracula.isDark),
  );
}

/// One `ThemeData`, for one appearance.
///
/// [accent] is passed in rather than read from the controller so that the light
/// and dark slots are built from *one* resolution of the user's choice. If each
/// resolved the accent itself, a `system` option could put a dark-derived accent
/// on the light theme — the one way the derived-accent design can introduce a
/// bug rather than remove one.
ThemeData _appThemeData(AppTheme theme, Color accent) => ThemeData(
      useMaterial3: true,
      brightness: theme.brightness,
      colorScheme: theme.usesPresetAccent
          ? _draculaScheme(accent)
          : ColorScheme.fromSeed(
              seedColor: accent,
              brightness: theme.brightness,
            ),
      // This is the value the widget layer detects the preset by. `AppCard` and
      // the other surface widgets resolve their [AppTheme] from the `ThemeData`
      // `MaterialApp` publishes, and the way they tell Dracula from the app's own
      // dark mode is by comparing this against `AppSurfaces.pageDracula` — the
      // token, not a literal. A Material `Brightness` cannot carry it, because
      // Dracula maps to `ThemeMode.dark` and both dark presets report the same
      // brightness. If this line ever published the dark page, Dracula would
      // render as the app's dark mode everywhere in the tree.
      scaffoldBackgroundColor: AppSurfaces.page(theme),
// Cards are the page colour, so a Material `Card` on this surface is
      // invisible without a shadow, and `elevation` is what supplies one.
      //
      // **It was `0`, sitting directly under a comment saying it supplies the
      // shadow.** So the four energy-report cards -- totals, chart, note and
      // empty-state -- rendered as page-coloured rectangles with a hairline and no
      // shadow pair, which is a different surface language from every `AppCard`
      // on the dashboard. The comment stated the intent and the value contradicted
      // it, which is the most durable kind of bug: it reads as done.
      //
      // `elevation` is Material's own mechanism and `CardTheme` cannot express
      // the app's three-shadow neumorphic pair, so the two surfaces still differ
      // in shape. What matches now is that both have depth and both sit on the
      // page colour, which is what the eye reads as the same language. Converting
      // them to `AppCard` is the real fix and is a bigger change than a token.
      cardTheme: CardThemeData(
        color: AppSurfaces.page(theme),
        // 3, not 0. Material's shadow at this elevation is a single soft drop,
        // which is not the app's three-shadow pair, but "no depth at all" is a
        // worse mismatch than "a different depth".
        elevation: 3,
        // Without this, Material tints its shadow by `ThemeData.shadowColor`,
        // which defaults to a scrim of `colorScheme.shadow`. On a near-black page
        // that washes the drop out to nothing, which is the failure this whole
        // value exists to avoid.
        shadowColor: Colors.black.withValues(alpha: theme.isDark ? 0.45 : 0.20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: AppElevation.hairline(accent: accent, theme: theme),
          ),
        ),
      ),
      filledButtonTheme: _buttonTheme(accent, theme),
      segmentedButtonTheme: _segmentedTheme(accent, theme),
      inputDecorationTheme: _inputTheme(theme),
    );

Future<void> _initializeAlarmServices() async {
  try {
    await AlarmNotificationService.initialize();
    // Hands the current rules and credentials to the native alarm module, which
    // is what actually schedules the background check. Doing this after runApp
    // keeps a slow secure-storage read off the first frame.
    await AlarmNotificationService.sync();
  } catch (error) {
    appLog(() => 'Alarm notification initialization failed: $error');
  }
}

class PltsMonitoringApp extends StatefulWidget {
  const PltsMonitoringApp({super.key});

  @override
  State<PltsMonitoringApp> createState() => _PltsMonitoringAppState();
}

class _PltsMonitoringAppState extends State<PltsMonitoringApp>
    with WidgetsBindingObserver {
  final _themeController = AppThemeController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seed the controller with the platform brightness before the first build,
    // so a `system` option resolves against the real answer rather than the
    // dark default it starts on.
    _themeController.resolve(PlatformDispatcher.instance.platformBrightness);
    _themeController.load();
  }

  /// Tells the controller what the platform brightness is, which is the one
  /// input `ThemeOption.system` needs and cannot get on its own.
  ///
  /// **This is currently redundant, and it is here anyway — which is worth
  /// stating rather than leaving a reader to assume it is load-bearing.**
  /// `AppThemeController.accent` is the only consumer of
  /// [AppThemeController.resolvedBrightness], and `presetAccent` returns `null`
  /// for both `AppTheme.light` and `AppTheme.dark` — so the accent is the stored
  /// seed either way and cannot be wrong. The *theme* is resolved from
  /// `Theme.of(context).brightness` below, which `MaterialApp` has already
  /// derived from the same platform value, so it is correct without this.
  ///
  /// It stays because the moment a second preset carries a brightness-dependent
  /// accent, `accent` becomes reachable from a stale cached brightness and this
  /// is the line that keeps it honest — and because `test/dracula_theme_wiring_test.dart`
  /// pins the observable half of it (a `system` option on a light platform
  /// publishes the light theme) so the contract is asserted even though no test
  /// can currently fail on this line alone.
  @override
  void didChangePlatformBrightness() {
    setState(
      () => _themeController.resolve(
        PlatformDispatcher.instance.platformBrightness,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        // **The one place the appearance is resolved.**
        //
        // `AppThemeController.appTheme` is `resolveAppTheme(option, brightness)`:
        // Dracula answers itself, `light` and `dark` answer themselves, and only
        // `system` consults the brightness — which is the platform one, pushed in
        // by `didChangePlatformBrightness` above. Reading it here rather than
        // from `Theme.of(context)` is deliberate: this runs *before* `MaterialApp`
        // exists, so there is no context to read a brightness from, and the value
        // is already in the controller because the widget layer put it there.
        //
        // The accent comes from the same resolution, and both `ThemeData`s are
        // built from it. Splitting those — resolving the theme one way and the
        // accent another — is how a light theme ends up wearing a dark accent.
        final brightness = _themeController.resolvedBrightness;
        final appTheme = _themeController.appTheme(brightness);
        final accent = _themeController.accent;

        // `MaterialApp` has two slots and three appearances, so the `darkTheme`
        // slot carries whichever dark preset is in force. `ThemeOption.dracula`
        // maps to `ThemeMode.dark` — Material has no third brightness and Dracula
        // *is* a dark theme — which is why the distinction has to live in the
        // published `ThemeData` rather than in `themeMode`.
        final darkPreset =
            appTheme.usesPresetAccent ? AppTheme.dracula : AppTheme.dark;

        return MaterialApp(
          title: 'EnerGrow',
          debugShowCheckedModeBanner: false,
          themeMode: _themeController.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          // Both slots are built from the *same* resolved accent. The light slot
          // exists even while Dracula is active, and it is built from the same
          // `accent` rather than from the raw seed so that a `system` option
          // cannot put two different accents in one app.
          theme: _appThemeData(AppTheme.light, accent),
          darkTheme: _appThemeData(darkPreset, accent),
          builder: (context, child) {
            // The widget layer's own view of the theme, resolved from what
            // `MaterialApp` published. This is the same comparison `_appThemeOf`
            // in `liquid_glass.dart` makes, and for the same reason: a
            // `Brightness` cannot distinguish the two dark presets.
            final resolved = resolveAppTheme(
              _themeController.option,
              Theme.of(context).brightness,
            );
            // The system navigation bar is opaque, and it sits over the app's
            // bottom edge. It has to match the page or there is a visible seam
            // where the two meet.
            final navColor = AppSurfaces.page(resolved);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: resolved.isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: navColor,
                systemNavigationBarIconBrightness: resolved.isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarDividerColor: navColor,
                systemNavigationBarContrastEnforced: false,
              ),
              child: child!,
            );
          },
          home: _SplashRouter(themeController: _themeController),
        );
      },
    );
  }
}

/// Cek dulu apakah ada token tersimpan sebelum nentuin ke Login atau Dashboard
class _SplashRouter extends StatefulWidget {
  final AppThemeController themeController;

  const _SplashRouter({required this.themeController});

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  final _api = ThingsBoardApi();
  bool _checking = true;
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final has = await _api.loadSavedToken();
    if (!mounted) return;
    setState(() {
      _hasToken = has;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: const BrandLogo(size: 92),
              ),
              const SizedBox(height: 10),
              const Text(
                'EnerGrow',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _hasToken
        ? DashboardScreen(api: _api, themeController: widget.themeController)
        : LoginScreen(themeController: widget.themeController);
  }
}
