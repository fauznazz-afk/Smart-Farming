import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  static const _seedKey = 'theme_seed';
  static const defaultSeed = Color(0xFF35A968);

  Color _seedColor = defaultSeed;
  Color get seedColor => _seedColor;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedSeed = preferences.getInt(_seedKey);
    if (storedSeed == null) return;
    _seedColor = Color(storedSeed);
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_seedKey, color.toARGB32());
  }
}
