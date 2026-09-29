import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/settings_keys.dart';
import 'package:plts_monitoring/screens/settings/settings_controller.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pins the difference between a limit the user has saved and a default sitting
/// in the field.
///
/// Found on the test device on 29 September 2026. The Fish tank alerts section
/// showed "Max (NTU) 100" and the switch was on, so turbidity looked guarded at
/// 100 NTU while the device was reading 2396. The native side had been told to
/// configure 19 rules, and 19 is the count *without* a turbidity rule — 20 with
/// one — so the key was never in the preference store. The field showed a
/// shipped default that `load()` kept when the key was missing, and nothing on
/// screen distinguished that from a stored limit.
///
/// Both halves matter. If a default is ever shown as if it were saved, a user
/// believes a limit is enforced when no rule exists. If a stored limit is ever
/// flagged as a default, the same user is told to save something already armed
/// and has no reason to trust the screen.
void main() {
  Future<SettingsController> controller({
    Map<String, Object> initial = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    FlutterSecureStorage.setMockInitialValues({});
    final themeController = AppThemeController();
    await themeController.load();
    final c = SettingsController(themeController: themeController);
    addTearDown(c.dispose);
    await c.load();
    return c;
  }

  EnvRangeSetting byId(List<EnvRangeSetting> ranges, String id) =>
      ranges.firstWhere((r) => r.id == id);

  group('a default is not a saved limit', () {
    test('turbidity is flagged when its key was never stored', () async {
      // The exact state of the test device: pH and water temperature were saved
      // by an earlier release, turbidity was added in 1.6.0 and never armed.
      final c = await controller(
        initial: {
          SettingsKeys.fishPhMin: '6',
          SettingsKeys.fishPhMax: '8.5',
          SettingsKeys.fishTempMin: '20',
          SettingsKeys.fishTempMax: '35',
        },
      );

      final turbidity = byId(c.fishRanges, 'turbidity');
      expect(
        turbidity.max.text,
        '100',
        reason: 'The default is still prefilled, so the user is shown the value '
            'they would get by saving.',
      );
      expect(
        turbidity.maxIsPrefill,
        isTrue,
        reason: 'Nothing is enforcing this number, so the screen has to say so.',
      );

      // The limits that really were saved must not be flagged, or the marker
      // stops meaning anything.
      final ph = byId(c.fishRanges, 'ph');
      expect(ph.max.text, '8.5');
      expect(ph.maxIsPrefill, isFalse);
      final water = byId(c.fishRanges, 'water_temp');
      expect(water.max.text, '35');
      expect(water.maxIsPrefill, isFalse);
    });

    test('a fresh install flags every default, none of them blank', () async {
      final c = await controller();
      for (final range in [...c.envRanges, ...c.fishRanges]) {
        if (range.minKey != null && range.min.text.isNotEmpty) {
          expect(
            range.minIsPrefill,
            isTrue,
            reason: '${range.id} min shows ${range.min.text} with no stored key.',
          );
        }
        if (range.maxKey != null && range.max.text.isNotEmpty) {
          expect(
            range.maxIsPrefill,
            isTrue,
            reason: '${range.id} max shows ${range.max.text} with no stored key.',
          );
        }
      }
    });

    test('a one-sided range only flags the side that has a key', () async {
      final c = await controller();
      final turbidity = byId(c.fishRanges, 'turbidity');
      // Upper bound only: there is no min key, so there is nothing to arm and
      // nothing to warn about on that side.
      expect(turbidity.minKey, isNull);
      expect(turbidity.minIsPrefill, isFalse);
      expect(turbidity.maxIsPrefill, isTrue);
    });

    test('saving clears the flag, because the value is now enforced', () async {
      final c = await controller();
      final turbidity = byId(c.fishRanges, 'turbidity');
      expect(turbidity.maxIsPrefill, isTrue);

      expect(await c.save(), isNull);
      expect(
        turbidity.maxIsPrefill,
        isFalse,
        reason: 'After a save the key exists and a rule is armed, so the field '
            'is no longer showing an unsaved default.',
      );

      // The value really reached the store, and a controller reading that store
      // treats it as saved. Read it back explicitly because the helper seeds a
      // fresh mock store, so a plain reload would just start from empty again.
      final stored = (await SharedPreferences.getInstance())
          .getString(SettingsKeys.fishTurbidityMax);
      expect(stored, '100');

      final reloaded =
          await controller(initial: {SettingsKeys.fishTurbidityMax: stored!});
      expect(
        byId(reloaded.fishRanges, 'turbidity').maxIsPrefill,
        isFalse,
        reason: 'The key is in the store, so this is a saved limit and must not '
            'be marked as an unsaved default.',
      );
    });
  });
}
