import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  static const _seedKey = 'theme_seed';
  static const _themeModeKey = 'theme_mode';
  static const defaultSeed = Color(0xFF35A968);

  Color _seedColor = defaultSeed;
  Color get seedColor => _seedColor;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool _performanceMode = true;
  bool get performanceMode => _performanceMode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSeed = preferences.getInt(_seedKey);
    if (storedSeed != null) {
      _seedColor = Color(storedSeed);
    }

    final storedMode = preferences.getString(_themeModeKey);
    if (storedMode != null) {
      switch (storedMode) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
        case 'dark':
        default:
          _themeMode = ThemeMode.dark;
          break;
      }
    } else {
      _themeMode = ThemeMode.dark;
    }

    _performanceMode = preferences.getBool('performance_mode') ?? true;
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_seedKey, color.toARGB32());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await preferences.setString(_themeModeKey, modeString);
  }

  Future<void> toggleDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setPerformanceMode(bool value) async {
    _performanceMode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('performance_mode', value);
  }
}
