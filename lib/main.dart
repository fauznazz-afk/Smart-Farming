import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';

import 'services/thingsboard_api.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme_controller.dart';
import 'widgets/brand_logo.dart';
import 'screens/dashboard/utils/color_helpers.dart';
import 'widgets/liquid_glass.dart';
import 'services/alarm_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PltsMonitoringApp());
  unawaited(_initializeAlarmServices());
}

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
SegmentedButtonThemeData _segmentedTheme(Color seed, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final accent = themeColor(
    seedColor: seed,
    lightness: isDark ? 0.68 : 0.34,
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
            : (isDark ? Colors.white70 : Colors.black54),
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

Future<void> _initializeAlarmServices() async {
  try {
    await AlarmNotificationService.initialize();
    // Hands the current rules and credentials to the native alarm module, which
    // is what actually schedules the background check. Doing this after runApp
    // keeps a slow secure-storage read off the first frame.
    await AlarmNotificationService.sync();
  } catch (error) {
    debugPrint('Alarm notification initialization failed: $error');
  }
}

class PltsMonitoringApp extends StatefulWidget {
  const PltsMonitoringApp({super.key});

  @override
  State<PltsMonitoringApp> createState() => _PltsMonitoringAppState();
}

class _PltsMonitoringAppState extends State<PltsMonitoringApp> {
  final _themeController = AppThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) => MaterialApp(
        title: 'EnerGrow',
        debugShowCheckedModeBanner: false,
        themeMode: _themeController.themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _themeController.seedColor,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF6F8F7),
          cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
          segmentedButtonTheme: _segmentedTheme(
            _themeController.seedColor,
            Brightness.light,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFEBEFEA),
            border: OutlineInputBorder(),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _themeController.seedColor,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF101412),
          cardTheme: const CardThemeData(
            color: Color(0xFF1B211E),
            elevation: 0,
          ),
          segmentedButtonTheme: _segmentedTheme(
            _themeController.seedColor,
            Brightness.dark,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF1B211E),
            border: OutlineInputBorder(),
          ),
        ),
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final navColor = isDark
              ? const Color(0xFF101412)
              : const Color(0xFFF6F8F7);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: navColor,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarDividerColor: navColor,
              systemNavigationBarContrastEnforced: false,
            ),
            child: child!,
          );
        },
        home: _SplashRouter(themeController: _themeController),
      ),
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
  final _localAuth = LocalAuthentication();
  bool _checking = true;
  bool _hasToken = false;
  bool _unlocked = false;
  bool _authenticating = false;
  String? _authError;

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
    if (has) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticate();
      });
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating || !_hasToken || _unlocked) return;
    setState(() {
      _authenticating = true;
      _authError = null;
    });
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock the EnerGrow session',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      setState(() {
        _unlocked = authenticated;
        _authError = authenticated
            ? null
            : 'Authentication cancelled. Use biometrics to continue.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authError =
            'Biometrics unavailable. Sign in with your ThingsBoard account.';
      });
    } finally {
      _authenticating = false;
    }
  }

  void _usePasswordLogin() {
    setState(() {
      _hasToken = false;
      _authError = null;
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
    if (_hasToken && !_unlocked) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AmbientBackground(
          isDark: isDark,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: const BrandLogo(size: 88),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sesi EnerGrow tersimpan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use your fingerprint or face recognition to unlock the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    if (_authError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _authError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _authenticating ? null : _authenticate,
                      icon: _authenticating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(
                        _authenticating
                            ? 'Verifying…'
                            : 'Unlock with biometrics',
                      ),
                    ),
                    TextButton(
                      onPressed: _usePasswordLogin,
                      child: const Text(
                        'Sign in with your ThingsBoard account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return _hasToken
        ? DashboardScreen(api: _api, themeController: widget.themeController)
        : LoginScreen(themeController: widget.themeController);
  }
}
