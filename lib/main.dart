import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';

import 'services/thingsboard_api.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme_controller.dart';
import 'widgets/brand_logo.dart';
import 'widgets/liquid_glass.dart';
import 'services/alarm_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmNotificationService.initialize();
  await AlarmNotificationService.initializeBackgroundMonitoring();
  runApp(const PltsMonitoringApp());
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
        localizedReason: 'Autentikasi untuk membuka sesi EnerGrow',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;
      setState(() {
        _unlocked = authenticated;
        _authError = authenticated
            ? null
            : 'Autentikasi dibatalkan. Gunakan biometrik untuk melanjutkan.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authError =
            'Biometrik tidak tersedia. Masuk menggunakan akun ThingsBoard.';
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [BrandLogo(size: 92, showName: true)],
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
                      'Gunakan sidik jari atau pengenalan wajah untuk membuka aplikasi.',
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
                            ? 'Memverifikasi…'
                            : 'Buka dengan biometrik',
                      ),
                    ),
                    TextButton(
                      onPressed: _usePasswordLogin,
                      child: const Text('Masuk dengan akun ThingsBoard'),
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
