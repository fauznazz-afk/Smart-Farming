import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/thingsboard_api.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme_controller.dart';
import 'widgets/brand_logo.dart';

void main() {
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
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF101412),
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF101412),
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Color(0xFF101412),
            systemNavigationBarContrastEnforced: false,
          ),
          child: child!,
        ),
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _themeController.seedColor,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF101412),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF1B211E),
            border: OutlineInputBorder(),
          ),
        ),
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(size: 92, showName: true),
              SizedBox(height: 24),
              CircularProgressIndicator(),
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
