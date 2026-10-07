import 'package:flutter/material.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The appearance choices in Settings, and the thing that is persisted.
///
/// **This is a preset, not a brightness, and it is an enum rather than two
/// fields for exactly that reason.** Dracula is a complete palette: it brings
/// its own page *and* its own accent. Storing "theme = dracula" alongside
/// "seed = green" would permit a state that is neither Dracula nor the app's
/// dark mode — a purple page with a green accent — and nothing would stop it,
/// because both fields are individually valid. Deriving the accent from the
/// option makes that state unrepresentable; see [AppThemeController.accent].
///
/// The stored spelling is the same string [AppThemeMode] already wrote, under
/// the same key, and `system` / `light` / `dark` all still mean what they meant.
/// Dracula adds a fourth string and nothing else, so an existing install is not
/// migrated, not re-written and not invalidated by this change. An
/// unrecognised or absent value still falls back to [ThemeOption.dark], which is
/// the behaviour that was already there and is deliberately not "improved" into
/// a default of `system`.
enum ThemeOption {
  system('system'),
  light('light'),
  dark('dark'),

  /// Dracula, in the VS Code sense: its surfaces *and* its accent together.
  ///
  /// It maps to [ThemeMode.dark] because Material has no third brightness and
  /// this is a dark theme; the distinction is carried by [resolveAppTheme] and
  /// the accent, not by the brightness the framework is handed.
  dracula('dracula'),

  /// Skeuo: the design brief's own palette, amber and lime on `#0A0A0C`.
  ///
  /// **A fourth option rather than a replacement**, and that is the whole
  /// decision. The brief describes a dark-only palette, and taking it as *the*
  /// theme would have deleted the light theme, whose `#E1E7E4` page the design
  /// notes single out as the most consequential value in the token file, and
  /// with it three contrast guarantees measured against that page. A specified
  /// palette is worth having exactly as much as the ones it is offered beside.
  ///
  /// Stored as `'skeuo'`. Anything unrecognised still falls back to
  /// [ThemeOption.dark], so an old install is unaffected.
  skeuo('skeuo');

  const ThemeOption(this.stored);

  /// The exact string written to SharedPreferences.
  ///
  /// Pinned as a field rather than written out at the call site because the
  /// write and the read are the only two places the value exists, and they are
  /// in different methods: a typo in either would be invisible until an
  /// existing user found their theme silently reverted to dark on next launch.
  final String stored;

  /// Reads a stored string back, or `null` if it is not one of ours.
  ///
  /// Returning `null` rather than a default is what lets [AppThemeController]
  /// distinguish "never set" from "set to something we no longer have", and both
  /// resolve to [ThemeOption.dark] — but only the first should ever be written
  /// back, and neither should cause an existing install's key to be rewritten.
  static ThemeOption? fromStored(String? value) {
    for (final option in ThemeOption.values) {
      if (option.stored == value) return option;
    }
    return null;
  }

  /// The Material brightness this option hands to `MaterialApp`.
  ///
  /// Unchanged in shape, and unchanged in what it returns for the three original
  /// values, so `main.dart` keeps working exactly as it does.
  ThemeMode get themeMode => switch (this) {
    ThemeOption.system => ThemeMode.system,
    ThemeOption.light => ThemeMode.light,
    ThemeOption.dark || ThemeOption.dracula || ThemeOption.skeuo =>
      ThemeMode.dark,
  };

  /// The inverse of [themeMode], for a caller that only knows the brightness.
  ///
  /// Note what this cannot do: `ThemeMode.dark` does not say whether the user
  /// chose dark or Dracula. The other direction has to be lossy, and the only
  /// way to keep a preset from being downgraded to plain dark by accident is for
  /// this to be the *only* conversion available — so [setThemeMode] goes through
  /// it deliberately, meaning a brightness-only caller picks plain dark.
  static ThemeOption fromThemeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.system => ThemeOption.system,
    ThemeMode.light => ThemeOption.light,
    ThemeMode.dark => ThemeOption.dark,
  };
}

/// The [AppTheme] a persisted option resolves to, for a given resolved
/// brightness.
///
/// Free function rather than a member so it can be tested without a controller
/// and without `SharedPreferences`. [ThemeOption.system] is the only case that
/// needs the platform brightness, and that is not a gap — the platform brightness
/// is what `MaterialApp` has already resolved by the time anything paints, so
/// the caller passes `Theme.of(context).brightness` and the answer is the same
/// one the framework is using.
///
/// Dracula resolves to [AppTheme.dracula] whatever the brightness is, because
/// Dracula is not a brightness and asking the system which one it prefers is
/// meaningless for a palette that overrides the page entirely.
AppTheme resolveAppTheme(ThemeOption option, Brightness resolvedBrightness) =>
    switch (option) {
      ThemeOption.dracula => AppTheme.dracula,
      ThemeOption.skeuo => AppTheme.skeuo,
      ThemeOption.dark => AppTheme.dark,
      ThemeOption.light => AppTheme.light,
      ThemeOption.system => resolvedBrightness == Brightness.dark
          ? AppTheme.dark
          : AppTheme.light,
    };

class AppThemeController extends ChangeNotifier {
  static const _seedKey = 'theme_seed';
  static const _themeModeKey = 'theme_mode';
  static const defaultSeed = Color(0xFF35A968);

  Color _seedColor = defaultSeed;
  Color get seedColor => _seedColor;

  ThemeOption _option = ThemeOption.dark;

  /// The persisted appearance choice.
  ThemeOption get option => _option;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  /// The brightness in force. `true` for Dracula too, because Dracula *is* dark;
  /// it is [AppTheme] that distinguishes the two.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// The [AppTheme] currently in force, resolved against [brightness].
  ///
  /// This is what the surface and elevation tokens are keyed on, and it is
  /// strictly more information than [isDarkMode] — the boolean is kept because
  /// the text and status palette in `color_helpers.dart` is genuinely shared
  /// between the two dark themes, so those call sites can go on passing a bool
  /// and cannot be made wrong by choosing Dracula.
  AppTheme appTheme(Brightness brightness) =>
      resolveAppTheme(_option, brightness);

  /// The accent the app should actually paint with, right now.
  ///
  /// **This is a getter over [option], not a stored field, and that is the whole
  /// design.** A preset that carries its accent and a seed the user picked are
  /// two pieces of state, and storing them separately makes the inconsistent
  /// pair representable. Deriving one from the other means there is no code path
  /// that can produce Dracula's purple page beside the app's green accent, and
  /// no test that has to be told to look for it.
  Color get accent => presetAccent(appTheme(_resolvedBrightness)) ?? _seedColor;

  /// The brightness the option resolves to, used by [accent].
  ///
  /// Cached from the last [resolve] call rather than read from the platform,
  /// because the accent is needed *before* a build in at least one place — the
  /// `ColorScheme` handed to `MaterialApp` — and reading the platform there
  /// would be a context lookup in a non-widget. It defaults to
  /// [Brightness.dark], which is the mode the app has defaulted to since before
  /// any of this and therefore the right guess for a `system` option that has
  /// not been resolved yet.
  Brightness _resolvedBrightness = Brightness.dark;
  Brightness get resolvedBrightness => _resolvedBrightness;

  /// Tells the controller what the framework resolved `system` to.
  ///
  /// Called from the widget layer, not from [load], because only a widget can
  /// see the platform brightness. Without it a `system` option would take the
  /// [accent] from [Brightness.dark] and produce a dark accent for a light
  /// system theme, which is the one way the derived-accent design could
  /// introduce a bug rather than remove one.
  void resolve(Brightness brightness) {
    if (_resolvedBrightness == brightness) return;
    _resolvedBrightness = brightness;
    notifyListeners();
  }

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

    // The new option is read through one parse, so a stored value this build
    // does not recognise is a *missing* value rather than a crash. The old
    // `switch` had the same property by virtue of a `default`, but it could not
    // distinguish 'dark' from 'unknown' and so had nowhere to put a fourth
    // case; that is the whole reason this is an enum now.
    _option = ThemeOption.fromStored(preferences.getString(_themeModeKey)) ??
        ThemeOption.dark;
    _themeMode = _option.themeMode;

    notifyListeners();
  }

  /// Picks an accent from the Settings swatches.
  ///
  /// **This has no visible effect while a preset is active, and that is not a
  /// bug.** Dracula is one complete palette; letting the swatch underneath it
  /// show through would be the half-measure this was designed to avoid. The
  /// stored seed is still written, so switching back to light or dark restores
  /// whatever the user last chose — which is why this is not gated on the
  /// option instead of ignored: a caller must not be able to leave the
  /// controller in a state where the value it reads back has been discarded.
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_seedKey, color.toARGB32());
  }

  /// Picks a complete appearance preset.
  Future<void> setOption(ThemeOption option) async {
    _option = option;
    _themeMode = option.themeMode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, option.stored);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      setOption(ThemeOption.fromThemeMode(mode));

  Future<void> toggleDarkMode(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
}
