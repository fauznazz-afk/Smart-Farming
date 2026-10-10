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
/// `onHue` on every role it can sit on is not decoration. Every hue in
/// [AppPalette] is light enough that dark ink is correct, and white on
/// [AppPalette.primary] measures 1.71:1.
ColorScheme _appColorScheme() => const ColorScheme.dark(
      primary: AppPalette.primary,
      onPrimary: AppPalette.onHue,
      primaryContainer: AppPalette.primary,
      onPrimaryContainer: AppPalette.onHue,
      secondary: AppPalette.secondary,
      onSecondary: AppPalette.onHue,
      secondaryContainer: AppPalette.secondary,
      onSecondaryContainer: AppPalette.onHue,
      tertiary: AppPalette.accent,
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
/// `test/type_scale_test.dart` asserts on [AppType] and on the rendered result,
/// not on this function. Only the colour is added here, because [AppType] is
/// about shape and colour belongs to the surface it lands on.
TextTheme _appTextTheme() {
  TextStyle ink(TextStyle style) => style.copyWith(color: AppSurfaces.onSurface);
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

/// The app's buttons: a solid categorical pill with dark ink.
///
/// `filledButtonTheme` was simply absent for most of this app's life, so every
/// `FilledButton` — "Sign in", "Save settings", "Play camera" — was a raw
/// Material block with a default elevation and the framework's own corner radius.
/// Two things were wrong with that on a device and only one was cosmetic: the
/// shape was flat, and the label failed contrast because `ColorScheme.fromSeed`
/// paired a light seed with a light `onPrimary`.
///
/// Both are fixed by the brief's own recipe rather than by styling around
/// Material's defaults: solid [AppPalette.primary], [AppPalette.onHue] on it,
/// [AppRadius.pill], 48dp tall, uppercase label. The 48dp is the minimum touch
/// target and is set as `minimumSize` rather than `fixedSize` so the button still
/// grows with the user's font scale.
FilledButtonThemeData _buttonTheme() => FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(AppPalette.primary),
        foregroundColor: const WidgetStatePropertyAll(AppPalette.onHue),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(AppType.labelUppercase),
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
SegmentedButtonThemeData _segmentedTheme() => SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.secondary
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
        side: const WidgetStatePropertyAll(AppBorders.hairline),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(AppType.labelUppercase),
      ),
    );

/// The app's input fields.
///
/// **The fill is [AppSurfaces.input], which is the same value as
/// [AppSurfaces.surface]: a text field is a surface.** The old system needed an
/// inset field to be *lighter* than its card, because the deboss was supposed to
/// come from a shadow and could not come from the fill without costing contrast
/// — and that constraint disappears with the shadows. The hairline is now a real
/// edge rather than a hint at one, and the focus ring is [AppPalette.accent]
/// because butter is the only attention hue in the palette that is not also a
/// severity.
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
        borderSide: const BorderSide(color: AppPalette.accent, width: 2),
      ),
      hintStyle: AppType.bodyMd.copyWith(color: AppSurfaces.onSurfaceVariant),
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
ThemeData _appThemeData() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _appColorScheme(),
      textTheme: _appTextTheme(),
      scaffoldBackgroundColor: AppSurfaces.page,
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
      dividerTheme: const DividerThemeData(
        color: AppSurfaces.border,
        space: 1,
        thickness: 1,
      ),
      filledButtonTheme: _buttonTheme(),
      segmentedButtonTheme: _segmentedTheme(),
      inputDecorationTheme: _inputTheme(),
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

class PltsMonitoringApp extends StatelessWidget {
  const PltsMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      // **`theme:` only.** There is no `darkTheme` and no `themeMode`, because
      // there is one appearance and it is dark. The old `builder:` resolved an
      // `AppTheme` back out of what `MaterialApp` had published — a round trip
      // through a `scaffoldBackgroundColor` comparison that existed solely because
      // `MaterialApp` cannot express a third brightness. With one theme there is
      // nothing to recover.
      theme: _appThemeData(),
      builder: (context, child) {
        // The system navigation bar is opaque and sits over the app's bottom
        // edge. It has to match the page or there is a visible seam where the two
        // meet. The icons are always light: the app is dark by design, so there
        // is no platform brightness left to consult here either.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppSurfaces.page,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: AppSurfaces.page,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child!,
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
                borderRadius: BorderRadius.circular(24),
                child: const BrandLogo(size: 92),
              ),
              const SizedBox(height: 10),
              // `AppType.heading`, because this is the app's name set in its
              // display face rather than in whichever family the framework
              // default happens to be.
              Text(
                'EnerGrow',
                style: AppType.numeralLg.copyWith(
                  fontFamily: AppType.heading,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _hasToken
        ? DashboardScreen(api: _api)
        : const LoginScreen();
  }
}
