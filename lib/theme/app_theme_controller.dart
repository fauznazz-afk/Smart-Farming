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

  // The Performance setting is gone, and this is the note explaining why the
  // `performance_mode` key is still in SharedPreferences but nothing reads it.
  //
  // It gated a `BackdropFilter` behind a `BackdropFilter(sigma 20)` branch of
  // the card, which had exactly one caller in the whole app — the login screen
  // — and the three ambient orb gradients, which were the most expensive paint
  // in the app and the only thing it meaningfully affected. Surfaces are opaque
  // now, so there is no backdrop left to frost and no orb layer to skip. The
  // key is left in place deliberately: an unread key costs nothing, and
  // removing it would be a migration for no user-visible gain.

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
}
