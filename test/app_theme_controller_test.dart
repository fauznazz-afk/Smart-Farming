import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The persisted appearance setting, and the rule that adding a preset must not
/// cost an existing user their theme.
///
/// **The threat this file guards is narrow and specific.** A new appearance
/// option is the kind of change that gets made by adding an enum value, and an
/// enum value is invisible until one of three things breaks: the *stored*
/// spelling drifts from the one [AppThemeController.load] reads, a value that
/// used to parse now falls through to a different default, or the conversion
/// back out to a `ThemeMode` loses the distinction. Each of those produces the
/// same symptom — a user's theme silently reverting to dark on next launch —
/// and none of them is caught by the app building.
void main() {
  const seedKey = 'theme_seed';
  const modeKey = 'theme_mode';

  Future<AppThemeController> loadedWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final controller = AppThemeController();
    await controller.load();
    return controller;
  }

  /// Round-trips an option through the real write and the real read.
  Future<AppThemeController> roundTrip(ThemeOption option) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppThemeController();
    await controller.load();
    await controller.setOption(option);
    final reloaded = AppThemeController();
    await reloaded.load();
    return reloaded;
  }

  group('an existing install keeps its theme', () {
    // The three strings that were written by every release before Dracula
    // existed. They are literals rather than `ThemeOption.light.stored` on
    // purpose: the whole claim is about the bytes on disk, and deriving them
    // from the enum would make the test pass even if the spelling changed.
    test('each pre-Dracula value still parses to what it always meant', () async {
      final cases = <String, ThemeOption>{
        'light': ThemeOption.light,
        'system': ThemeOption.system,
        'dark': ThemeOption.dark,
      };

      for (final entry in cases.entries) {
        final controller = await loadedWith({modeKey: entry.key});
        expect(
          controller.option,
          entry.value,
          reason: "a stored 'theme_mode' of '${entry.key}' must not change "
              'meaning when a fourth option is added',
        );
        expect(
          controller.themeMode,
          entry.value.themeMode,
          reason: "the Material brightness for '${entry.key}' is what "
              'main.dart already hands to MaterialApp',
        );
      }
    });

    test('an absent value still defaults to dark, not to system', () async {
      // Not "improved". The app has defaulted to dark since before this file
      // existed, and changing the default for a fresh install while adding a
      // preset would change what a new user sees for no reason connected to the
      // change being made.
      final controller = await loadedWith({});
      expect(controller.option, ThemeOption.dark);
      expect(controller.themeMode, ThemeMode.dark);
    });

    test('a value this build does not recognise is treated as absent', () async {
      // The forward-compatibility direction, and the one that is easy to get
      // wrong by throwing: a user who downgrades must not be locked out.
      final controller = await loadedWith({modeKey: 'solarized'});
      expect(controller.option, ThemeOption.dark);
    });

    test('an existing seed is untouched by the appearance option', () async {
      // The two keys are independent and have to stay that way: picking Dracula
      // must not clear the accent the user chose for light and dark mode, which
      // is the whole argument for deriving the preset accent rather than
      // overwriting the seed.
      final controller = await loadedWith({modeKey: 'light', seedKey: 0xFF2AA7A1});
      expect(controller.seedColor, const Color(0xFF2AA7A1));

      await controller.setOption(ThemeOption.dracula);

      final prefs = await SharedPreferences.getInstance();
      expect(
        Color(prefs.getInt(seedKey)!),
        const Color(0xFF2AA7A1),
        reason: 'the stored seed has to survive a preset change, or switching '
            'back to dark mode loses the colour the user picked. Read off the '
            'store rather than through a second controller, because the '
            'controller under test is the one that would hide a lost write.',
      );
      expect(prefs.getString(modeKey), 'dracula');
    });
  });

  group('the stored spelling is pinned on both sides', () {
    test('every option has a distinct, non-empty key', () {
      final stored = ThemeOption.values.map((o) => o.stored).toList();
      expect(stored.toSet().length, stored.length,
          reason: 'two options sharing a key would make one of them '
              'unreachable');
      for (final value in stored) {
        expect(value, isNotEmpty);
      }
    });

    test('the read side and the write side agree for all four', () async {
      // The failure mode this closes is a typo on either side: the write is in
      // `setOption` and the read is in `fromStored`, in different methods, and
      // nothing in the type system connects them. A typo would not crash -- the
      // value would simply never be read back.
      for (final option in ThemeOption.values) {
        expect(ThemeOption.fromStored(option.stored), option);
        final reloaded = await roundTrip(option);
        expect(reloaded.option, option, reason: 'round-trip of ${option.stored}');
      }
    });

    test('fromStored returns null for a miss, so a bad value is a missing one',
        () {
      expect(ThemeOption.fromStored(null), isNull);
      expect(ThemeOption.fromStored(''), isNull);
      expect(ThemeOption.fromStored('Dracula'), isNull,
          reason: 'stored values are lower case; a case-sensitive match is what '
              'keeps a hand-edited prefs file from silently half-working');
    });
  });

  group('Dracula is one preset, so the accent follows it', () {
    test('the option resolves to the Dracula theme whatever the brightness', () {
      // Not a bug that it ignores the platform: Dracula overrides the page
      // entirely, so asking the system which brightness it prefers is
      // meaningless for a palette that does not consult it.
      for (final brightness in Brightness.values) {
        expect(
          resolveAppTheme(ThemeOption.dracula, brightness),
          AppTheme.dracula,
        );
      }
    });

    test('the accent is derived, so the two cannot be set inconsistently', () {
      // the design claim: a preset carries its accent, and the accent is a
      // getter over the option rather than a second stored field. So Dracula's
      // purple page with the app's green accent is not a state this class can
      // reach -- there is no second setter to call.
      expect(presetAccent(AppTheme.dracula), draculaAccent);
      expect(presetAccent(AppTheme.dark), isNull);
      expect(AppTheme.dracula.usesPresetAccent, isTrue);
      expect(AppTheme.dark.usesPresetAccent, isFalse);
    });

    test('a brightness-only caller picks plain dark, never Dracula', () async {
      // `setThemeMode` has to go through the lossy conversion on purpose, or a
      // caller that only knows about brightness could downgrade a preset the
      // user deliberately chose -- which is a state change nobody asked for and
      // nothing would report.
      expect(ThemeOption.fromThemeMode(ThemeMode.dark), ThemeOption.dark);
      expect(ThemeOption.fromThemeMode(ThemeMode.light), ThemeOption.light);
      expect(
        ThemeOption.fromThemeMode(ThemeMode.system),
        ThemeOption.system,
      );
    });

    test('system still resolves against the platform brightness', () {
      // The one case that genuinely needs the brightness, and the reason
      // `resolveAppTheme` takes one as a parameter rather than reading anything:
      // only a widget can see it, and the answer has to agree with what
      // MaterialApp already resolved.
      expect(
        resolveAppTheme(ThemeOption.system, Brightness.dark),
        AppTheme.dark,
      );
      expect(
        resolveAppTheme(ThemeOption.system, Brightness.light),
        AppTheme.light,
      );
    });

    test('every option resolves to a theme, and dark ones say so', () {
      for (final option in ThemeOption.values) {
        for (final brightness in Brightness.values) {
          final theme = resolveAppTheme(option, brightness);
          expect(AppTheme.values, contains(theme));
          expect(theme.isDark, theme != AppTheme.light);
        }
      }
    });
  });
}
