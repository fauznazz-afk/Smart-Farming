import 'package:flutter/material.dart';

import 'services/thingsboard_api.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/brand_logo.dart';

void main() {
  runApp(const PltsMonitoringApp());
}

class PltsMonitoringApp extends StatelessWidget {
  const PltsMonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PLTS Monitoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF4B942),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101412),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1B211E),
          border: OutlineInputBorder(),
        ),
      ),
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
    return _hasToken ? DashboardScreen(api: _api) : const LoginScreen();
  }
}
