import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/thingsboard_api.dart';
import 'utils/app_log.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/brand_logo.dart';
import 'screens/dashboard/utils/design_tokens.dart';
import 'services/alarm_notification_service.dart';
import 'services/secure_window.dart';
import 'services/theme_mode.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PltsMonitoringApp());
  unawaited(_initializeAlarmServices());
}

/// The app's one `ColorScheme`.
///
/// **`ColorScheme.fromSeed` is deliberately not used, and the reason is the same
/// measurement that used to justify a hand-built Dracula scheme.** Material's
/// tonal mapping takes a seed and derives a colour chosen to stay legible on a
/// *light* surface, so on a `#0F0F11` page it darkens every role to move toward
/// white and lands the focal colour in a band that has nothing to do with the
/// brief's palette. The brief's hues are hand-specified and measured, and the
/// only thing that survives here is the reason it did before: a derived role is
/// a copy that drifts the moment a surface moves.
///
/// **Every accent-bearing role resolves to [AppPalette.error], and that is the
/// root of the black-and-red panel.** Material derives an enormous amount of
/// chrome from this one object — `FilledButton`'s fill and ink, the selected
/// `Chip`, the `SegmentedButton` selection, a `Switch`'s active track, a
/// `Checkbox`, the focus ring, text selection handles, the progress indicator —
/// and none of it was listed anywhere except here. A lime scheme therefore
/// survived every per-widget conversion, because the widget was reading the
/// scheme and the scheme still said lime. `primary`/`secondary`/`tertiary` and
/// their containers are now all the one accent, so there is no role left that
/// can reintroduce a second hue.
///
/// `secondaryContainer` is not optional here: it is what a selected `ChoiceChip`
/// paints, and leaving it at Material's derived value would put a desaturated
/// near-invisible fill behind the alarm-history filter chips.
///
/// `onHue` on every role it can sit on is not decoration. On the accent
/// `#1D4ED8` white ink measures **6.70:1** and black **3.13:1**, so black
/// fails AA for body text and white clears it by a wide margin.
ColorScheme _appColorScheme() => ColorScheme(
  brightness: AppTheme.brightness,
  primary: AppPalette.error,
  onPrimary: AppPalette.onHue,
  primaryContainer: AppPalette.error,
  onPrimaryContainer: AppPalette.onHue,
  secondary: AppPalette.error,
  onSecondary: AppPalette.onHue,
  secondaryContainer: AppPalette.error,
  onSecondaryContainer: AppPalette.onHue,
  tertiary: AppPalette.error,
  onTertiary: AppPalette.onHue,
  surface: AppSurfaces.surface,
  onSurface: AppSurfaces.onSurface,
  onSurfaceVariant: AppSurfaces.onSurfaceVariant,
  error: AppPalette.error,
  onError: AppPalette.onHue,
  outline: AppSurfaces.border,
  outlineVariant: AppSurfaces.border,
);

/// The type scale, on [AppType].
///
/// **Every style is derived from a token rather than written out**, because the
/// tokens are the scale: a literal here is a second place choosing a size, and
/// `test/design_tokens_test.dart` asserts on [AppType] — the weights, the
/// tracking, the tabular figures — not on this function. Only the colour is
/// added here, because [AppType] is about shape and colour belongs to the
/// surface it lands on.
///
/// **No family is chosen here either.** Every slot is an `AppType` style, and
/// `AppType` owns the app's two bundled families, so a face named in this
/// function would be a second place choosing one — which is how `AppType.sans`
/// stayed a dead CSS string through a green suite.
TextTheme _appTextTheme() {
  TextStyle ink(TextStyle style) =>
      style.copyWith(color: AppSurfaces.onSurface);
  TextStyle muted(TextStyle style) =>
      style.copyWith(color: AppSurfaces.onSurfaceVariant);

  return TextTheme(
    displayLarge: ink(AppType.displayLg),
    displayMedium: ink(AppType.displayMd),
    displaySmall: ink(AppType.numeralLg),
    headlineLarge: ink(AppType.numeralLg),
    headlineMedium: ink(AppType.headlineMd),
    headlineSmall: ink(AppType.headlineMd),
    titleLarge: ink(AppType.headlineMd),
    titleMedium: ink(AppType.headlineMd),
    titleSmall: muted(AppType.labelUppercase),
    bodyLarge: ink(AppType.bodyMd),
    bodyMedium: muted(AppType.bodyMd),
    bodySmall: muted(AppType.bodySm),
    labelLarge: ink(AppType.labelUppercase),
    labelMedium: ink(AppType.labelUppercase),
    labelSmall: muted(AppType.labelMicro),
  );
}

/// The app's buttons: a solid accent pill with dark ink.
///
/// `filledButtonTheme` was simply absent for most of this app's life, so every
/// `FilledButton` — "Sign in", "Save settings", "Play camera" — was a raw
/// Material block with a default elevation and the framework's own corner radius.
/// Two things were wrong with that on a device and only one was cosmetic: the
/// shape was flat, and the label failed contrast because `ColorScheme.fromSeed`
/// paired a light seed with a light `onPrimary`.
/// The brief's `button-primary`, applied to every filled button in the app.
///
/// Accent fill, black ink, `AppRadius.card` (8px — the brief's default for
/// buttons), 56dp tall. Label is `AppType.buttonLabel`: 13px at 900 with 0.1em
/// tracking — buttons shout.
///
/// **White ink on the accent, and it is measured rather than preferred:** 6.70:1
/// against 3.13:1 for black. `AppPalette.onHue` was written for a lime fill and
/// its name is a leftover; what it has always meant is *the ink that clears AA
/// on this fill*, and on this blue that is white.
///
/// The 56dp is `minimumSize` rather than `fixedSize`, so the button still grows
/// with the user's font scale. `elevation: 0` keeps Material from adding a soft
/// shadow underneath the hard one, which the call sites paint themselves through
/// `AppShadows.stampedIn` — a solid offset rectangle in the accent at 20%.
FilledButtonThemeData _buttonTheme() => FilledButtonThemeData(
  style: ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppPalette.error),
    foregroundColor: WidgetStatePropertyAll(AppPalette.onHue),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: WidgetStatePropertyAll(AppPalette.error),
    minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(AppType.buttonLabel),
  ),
);

/// The brief's `button-secondary` and `button-text`.
///
/// An outlined button is the page colour with a hairline and **no shadow at
/// all** — the brief reserves the stamped displacement for filled surfaces, so a
/// secondary button reads as flat and a primary one as stamped. Text buttons
/// are transparent with the accent ink at the label size.
///
/// **The ink is page ink, because the fill is the page.** The label was
/// `AppSurfaces.onSurface`, which is navy in both ramps since the cards went
/// near-white — **1.22:1** on the dark page, so the button was a rectangle with
/// no visible label. The two call sites that override this (the settings
/// section's secondary buttons and the report's period button) already use
/// `AppGlass.pageInkStrong` for the same reason, so the default has to agree
/// with them.
OutlinedButtonThemeData _outlinedButtonTheme() => OutlinedButtonThemeData(
  style: ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppSurfaces.page),
    foregroundColor: WidgetStatePropertyAll(AppGlass.pageInkStrong),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    side: WidgetStatePropertyAll(AppBorders.hairline),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(AppType.buttonLabel),
  ),
);

TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
  style: ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(AppPalette.error),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    textStyle: const WidgetStatePropertyAll(AppType.labelMicro),
  ),
);

/// Styling for every `SegmentedButton` in the app.
///
/// **The selected segment is a solid fill with dark ink and the unselected one is
/// a hairline on the card.** That is the brief's `chip-active` / `chip`, and it
/// is a change of kind rather than of degree: Material fills the selected segment
/// with `secondaryContainer`, which `ColorScheme.fromSeed` derives by
/// desaturating the seed until it reads as a neutral — invisible on a near-black
/// card, which is where this card's three call sites live.
///
/// The fill is the accent, because a segmented control is chrome and a filter
/// chip is the one shape allowed to pill. It states the same thing as the
/// colour scheme's `secondaryContainer`, deliberately: a `SegmentedButton` that
/// reads red while an unthemed `Chip` beside it does not is two systems on one
/// screen.
SegmentedButtonThemeData _segmentedTheme() => SegmentedButtonThemeData(
  style: ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppPalette.error
          : AppSurfaces.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppPalette.onHue
          // `onSurfaceVariant`, not `Colors.white70`: an unselected segment's
          // label is small body text, and the old grey pair measured ~3.4:1,
          // well under AA.
          : AppSurfaces.onSurfaceVariant,
    ),
    side: WidgetStatePropertyAll(AppBorders.hairline),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(AppType.labelMicro),
  ),
);

/// The app's input fields.
///
/// **The fill is [AppSurfaces.input], which is the same value as
/// [AppSurfaces.surface]: a text field is a surface.** The old system needed an
/// The app's input fields.
///
/// **The fill is [AppSurfaces.input], which is the same value as
/// [AppSurfaces.surface]: a text field is a surface.** 56dp tall, the stamped
/// shadow, and a 2px [AppPalette.error] border on focus — the accent, which is
/// the only attention hue in the palette that is not also a severity.
InputDecorationTheme _inputTheme() => InputDecorationTheme(
  filled: true,
  fillColor: AppSurfaces.input,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.inset),
    borderSide: AppBorders.hairline,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.inset),
    borderSide: AppBorders.hairline,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.inset),
    borderSide: BorderSide(color: AppPalette.error, width: 2),
  ),
  // Uppercase 700 with 0.1em tracking, per `label-uppercase-md`: a
  // placeholder in this system is a shout, not a hint.
  hintStyle: AppType.labelUppercase.copyWith(
    color: AppSurfaces.onSurfaceVariant,
  ),
  labelStyle: AppType.labelUppercase.copyWith(
    color: AppSurfaces.onSurfaceVariant,
  ),
);

/// One `ThemeData`.
///
/// **It takes no arguments, and that is the migration.** It used to take an
/// [AppTheme] and a seed colour and publish three appearances through
/// `MaterialApp`'s two slots. There is one appearance now, so the only decision
/// left in this file is whether the palette is hand-built or derived, and the
/// answer is above.
ThemeData appThemeData() => ThemeData(
  useMaterial3: true,
  brightness: AppTheme.brightness,
  colorScheme: _appColorScheme(),
  // **One family, app-wide.** Without this, a widget that builds a raw
  // `TextStyle(fontSize: ...)` inherits the platform default (Roboto) rather than
  // the `AppType` family, so the app rendered in two fonts at once. `AppType`
  // still wins wherever a style is used explicitly — this is the floor, not an
  // override.
  fontFamily: AppType.sans,
  textTheme: _appTextTheme(),
  scaffoldBackgroundColor: AppSurfaces.page,
  // **Every `AppBar` is transparent, so the page gradient shows through.**
  //
  // There was no `appBarTheme` at all, so every `AppBar` painted
  // `colorScheme.surface` — a near-white slab in **both** ramps, because cards
  // are near-white in both now. On a page that is supposed to be a blue gradient
  // that put a white rectangle across the top of the Settings, the energy
  // report, alarm history and every other screen with a default `AppBar`, and it
  // was invisible until the alarm history screen was measured at **1.00:1**
  // for its own title.
  //
  // Transparent rather than page-coloured: the page is a *gradient*, and a flat
  // colour cannot follow a gradient. What the bar needs is to be out of the way.
  //
  // **And the ink is page ink, because the bar is over the page.** The scheme's
  // default bar ink is `onSurface`, which is navy in **both** ramps now that the
  // cards are near-white — navy on the dark page measured **1.22:1**, so every
  // title was invisible. `AppGlass.pageInkStrong` is white in the dark ramp and
  // navy in the light one, and measures **10.90:1** on the sweep's top stop and
  // **12.56:1** on the flat page.
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    foregroundColor: AppGlass.pageInkStrong,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  // Flat, and a step above the page. `CardTheme` cannot express a hairline
  // *and* a tonal step is still the wrong way round, so both are here: the
  // fill does the separation from the canvas and the hairline draws the edge.
  // Material's own elevation shadow is set to 0 rather than left to a default,
  // because the default is the one shadow the flat system does not have.
  cardTheme: CardThemeData(
    color: AppSurfaces.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: AppBorders.hairline,
    ),
  ),
  dividerTheme: DividerThemeData(
    color: AppSurfaces.border,
    space: 1,
    thickness: 1,
  ),
  filledButtonTheme: _buttonTheme(),
  outlinedButtonTheme: _outlinedButtonTheme(),
  textButtonTheme: _textButtonTheme(),
  segmentedButtonTheme: _segmentedTheme(),
  inputDecorationTheme: _inputTheme(),
  // The brief's progress indicator: an accent line with no soft Material track
  // around it. `RefreshIndicator`'s spinner inherits it.
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: AppPalette.error,
    circularTrackColor: AppSurfaces.surfaceMuted,
  ),
  // Material draws a `SnackBar` on `inverseSurface`, which on a dark scheme is
  // a light box - a white panel on a black page. It is stated here rather than
  // left to the default because the default also picks the action's ink, and the
  // accent on a light surface measures 5.4:1.
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppSurfaces.surface,
    contentTextStyle: AppType.bodySm.copyWith(color: AppSurfaces.onSurface),
    actionTextColor: AppPalette.error,
  ),
  // The date pickers' chrome, which otherwise falls back to Material 3's own
  // dark defaults (`#1C1B1F`-family surface containers) and shows up as a
  // foreign grey dialog on both ramps. Every role here reads the same tokens a
  // card does: near-white fill, navy ink, the one accent — so the picker reads
  // as an app surface in dark mode instead of a system one. The header takes
  // the accent with white ink, matching the hero card, and in-range days take
  // the 12% accent wash from [AppBorders.categoricalWash] for the same
  // contrast reason that value was chosen.
  datePickerTheme: DatePickerThemeData(
    backgroundColor: AppSurfaces.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: AppBorders.hairline,
    ),
    rangePickerBackgroundColor: AppSurfaces.surface,
    rangePickerSurfaceTintColor: Colors.transparent,
    rangePickerShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: AppBorders.hairline,
    ),
    headerBackgroundColor: AppPalette.error,
    headerForegroundColor: AppPalette.onHue,
    rangePickerHeaderBackgroundColor: AppPalette.error,
    rangePickerHeaderForegroundColor: AppPalette.onHue,
    headerHeadlineStyle: AppType.headlineMd,
    rangePickerHeaderHeadlineStyle: AppType.headlineMd,
    weekdayStyle: AppType.labelUppercase.copyWith(
      color: AppSurfaces.onSurfaceVariant,
    ),
    dayBackgroundColor: WidgetStatePropertyAll(AppSurfaces.surface),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppPalette.onHue;
      if (states.contains(WidgetState.disabled)) {
        return AppSurfaces.onSurfaceVariant;
      }
      return AppSurfaces.onSurface;
    }),
    dayShape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheetRow)),
    ),
    dayOverlayColor: WidgetStatePropertyAll(
      AppPalette.error.withValues(alpha: 0.12),
    ),
    todayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppPalette.onHue;
      return AppPalette.error;
    }),
    todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppPalette.error;
      return AppSurfaces.surface;
    }),
    todayBorder: BorderSide(color: AppPalette.error),
    yearBackgroundColor: WidgetStatePropertyAll(AppSurfaces.surface),
    yearForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppPalette.onHue;
      if (states.contains(WidgetState.disabled)) {
        return AppSurfaces.onSurfaceVariant;
      }
      return AppSurfaces.onSurface;
    }),
    rangeSelectionBackgroundColor: AppPalette.error.withValues(alpha: 0.12),
    rangeSelectionOverlayColor: WidgetStatePropertyAll(
      AppPalette.error.withValues(alpha: 0.12),
    ),
  ),
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
  /// The chosen mode, and **the reason this widget is stateful at all.**
  ///
  /// There is one other piece of state here: `AppTheme`'s active palette, which
  /// is a static because 148 call sites read it without a `BuildContext`. A
  /// static cannot notify, so the rebuild comes from the same `setState` that
  /// rebuilds `MaterialApp` — which also rebuilds every `theme:`-derived value
  /// and the tree under it. So this one field drives both.
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-resolves `system` when the platform flips.
  ///
  /// **Without this, `ThemeMode.system` desyncs from itself.**
  /// `MaterialApp` follows the platform on its own — that is what the mode
  /// means — so the moment the user toggles Android's dark theme, the
  /// `ThemeData` flips and `AppTheme` does not, because a static has no
  /// platform listener. The result is the light palette telling Material it is
  /// bright: white ink on white cards, with nothing thrown.
  @override
  void didChangePlatformBrightness() {
    if (_mode != ThemeMode.system) return;
    AppTheme.applyMode(_mode, platformBrightness());
    setState(() {});
  }

  Future<void> _loadMode() async {
    final stored = await loadThemeMode();
    if (!mounted) return;
    // **The palette has to be applied here, not just the mode stored.**
    // `MaterialApp` reads `themeMode` and picks a slot, but both slots are built
    // from `AppTheme.brightness` — which is still its `dark` default at this
    // point, because nothing has called `AppTheme.applyMode` yet. Setting the
    // mode alone gives Material a light slot that holds a dark `ThemeData`, so
    // the app comes back up dark while the settings screen says Light, and the
    // first tap on the segmented control is the thing that "fixes" it.
    AppTheme.applyMode(stored, platformBrightness());
    setState(() => _mode = stored);
  }

  /// Applies [mode]: swaps the palette *first*, then rebuilds.
  ///
  /// The order matters and is the one thing that cannot be got wrong here. If
  /// the tree rebuilt before `AppTheme.apply` ran, one frame would paint with
  /// the new `ThemeData` and the old surface stack — and on the light palette
  /// that frame has white ink on white, which is the "white flash" this whole
  /// static design was meant to avoid.
  void _applyMode(ThemeMode mode) {
    AppTheme.applyMode(mode, platformBrightness());
    setState(() => _mode = mode);
    // Persisted here rather than in Settings, because the root is the only
    // place that owns the value Settings is editing. Writing it down at the
    // call site would put a second writer in the app.
    saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.brightness == Brightness.light;
    return MaterialApp(
      title: 'EnerGrow',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [SecureWindow.observer],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      // **The page colour, because nothing else paints there.**
      //
      // `targetSdk` 36 is edge-to-edge, so the system gesture bar's own strip
      // belongs to the app and the platform ignores
      // `systemNavigationBarColor` below. The dashboard used to cover that
      // strip by accident: with `extendBody: true` its body painted to the very
      // bottom edge, past the nav bar. Docking the bar (`extendBody: false`)
      // removed that accident, and the window's own background showed through —
      // black, in both palettes, under the gesture pill.
      //
      // This is the one paint that has to follow the palette, so it reads
      // `AppSurfaces.page` here rather than being left as `MaterialApp`'s
      // default. Reading `AppSurfaces` in `build` is what makes the swap: the
      // palette is already `applyMode`d by the time either theme slot is built.
      color: AppSurfaces.page,
      // **Both slots, and `themeMode` choosing between them.**
      //
      // `theme:` and `darkTheme:` are the *same* `ThemeData` built from the same
      // tokens — what differs is which one `MaterialApp` publishes, and both
      // read from `AppTheme`, which has already been swapped by the time either
      // is built. Two slots rather than one rebuilt `theme:` because
      // `MaterialApp` re-derives `Theme.of(context)` from the slot it picks, and
      // only the slot mechanism animates and re-inherits that correctly.
      theme: appThemeData(),
      darkTheme: appThemeData(),
      themeMode: _mode,
      builder: (context, child) {
        // **Transparent, because the glass bar now paints that strip itself.**
        // These two used to be `AppSurfaces.page`, which was a flat navy strip
        // under a translucent white bar: a hard horizontal seam across the
        // bottom of the screen, right where the user's thumb is. `GlassNavBar`
        // now reads the bottom inset itself and paints its glass down into the
        // gesture-bar region, so the platform must add nothing of its own colour
        // there. `contrastEnforced: false` is what stops Android painting a
        // scrim over a transparent navigation bar on API 29+.
        //
        // **The handle's brightness still follows the palette.** A transparent
        // strip shows whatever is behind it — the light glass bar — so a dark
        // handle is the readable one there; this is not a value to be pinned
        // once and forgotten.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                light ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                light ? Brightness.dark : Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: ThemeModeScope(
            mode: _mode,
            onChanged: _applyMode,
            child: child!,
          ),
        );
      },
      home: const _SplashRouter(),
    );
  }
}

/// Cek dulu apakah ada token tersimpan sebelum nentuin ke Login atau Dashboard
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

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
                // `AppRadius.card`, and it was a literal 24 until the audit
                // caught it. The token is 8 now, so this corner moved from
                // "rounded-soft" to the brief's rectilinear 8 without anybody
                // noticing — the literal was the copy that survived.
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: const BrandLogo(size: 92),
              ),
              const SizedBox(height: 10),
              // `AppType.wordmark`, because this is the app's name set as a brand
              // lockup rather than in whichever family the framework default
              // happens to be.
              const Text('EnerGrow', style: AppType.wordmark),
            ],
          ),
        ),
      );
    }
    return _hasToken ? DashboardScreen(api: _api) : const LoginScreen();
  }
}
