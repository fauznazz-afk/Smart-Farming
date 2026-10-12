import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_keys.dart';

/// The chosen appearance, and the handle a deep widget uses to change it.
///
/// **An inherited widget rather than a singleton, and this is the one thing the
/// static palette design could not do for itself.** `AppTheme` is a static
/// because 148 call sites read `AppSurfaces.page` without a `BuildContext`, and
/// a static cannot publish anything down the tree. So the *choice* lives here,
/// where it can reach a Settings screen four navigations deep, and only the
/// *effect* lives in the static.
///
/// `MaterialApp`'s `builder:` is above every route, so the scope it installs is
/// visible to all of them without any route knowing about the root widget.
class ThemeModeScope extends InheritedWidget {
  const ThemeModeScope({
    super.key,
    required this.mode,
    required this.onChanged,
    required super.child,
  });

  /// The mode as chosen by the user, before platform resolution.
  final ThemeMode mode;

  /// Replaces the mode, applies it to [AppTheme], and rebuilds the root.
  final ValueChanged<ThemeMode> onChanged;

  static ThemeModeScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) =>
      oldWidget.mode != mode;
}

/// Reads the stored preference.
///
/// **`system` when nothing is stored, and it is a real default rather than a
/// fallback.** A user whose phone is already in dark mode gets dark without
/// ever touching a setting, which is the same answer they would have picked.
Future<ThemeMode> loadThemeMode() async {
  final p = await SharedPreferences.getInstance();
  return switch (p.getString(SettingsKeys.themeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// Writes the preference.
Future<void> saveThemeMode(ThemeMode mode) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(
    SettingsKeys.themeMode,
    switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    },
  );
}

/// The platform brightness, resolved without a `BuildContext`.
///
/// Avoids taking a context in `main()` before the first frame, where
/// `MediaQuery.platformBrightnessOf` has nothing to read.
Brightness platformBrightness() {
  final view = PlatformDispatcher.instance.views.firstOrNull;
  if (view == null) return Brightness.dark;
  return MediaQueryData.fromView(view).platformBrightness;
}
