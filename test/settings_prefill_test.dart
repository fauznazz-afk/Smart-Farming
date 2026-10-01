import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/settings_keys.dart';
import 'package:plts_monitoring/screens/settings/settings_controller.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';
import 'package:plts_monitoring/screens/settings/widgets/settings_fields.dart';
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
    test('turbidity is left empty, because no default is honest', () async {
      // The exact state of the test device after a save: pH and water
      // temperature were stored by an earlier release, turbidity was added in
      // 1.6.0 and was armed at the old 100 NTU default.
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
        isEmpty,
        reason: 'The default was removed. The sensor reads 2396 and then 2993.5 '
            'NTU, so any shipped number is a guess about a sensor nobody has '
            'calibrated, and a guess that fails high is an alarm that can never '
            'clear.',
      );
      expect(
        turbidity.maxIsPrefill,
        isFalse,
        reason: 'An empty field is not a prefill, so it must not be marked as '
            'one. Blank already means "not monitored" in this section.',
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

    test('a one-sided range with no default has nothing to flag', () async {
      final c = await controller();
      final turbidity = byId(c.fishRanges, 'turbidity');
      // Upper bound only: there is no min key, so there is nothing to arm and
      // nothing to warn about on that side.
      expect(turbidity.minKey, isNull);
      expect(turbidity.minIsPrefill, isFalse);
      // And no default, so the max side is empty too. An empty field is not a
      // prefill and must not be dressed as one — the section's own "Blank
      // limits are not monitored" already covers it, and the marker exists to
      // separate a *number* that looks armed from one that is.
      expect(turbidity.max.text, isEmpty);
      expect(turbidity.maxIsPrefill, isFalse);
    });

    test('saving clears the flag, because the value is now enforced', () async {
      final c = await controller();
      // The environment temperature range, which still ships a default. Turbidity
      // cannot be used here any more: with no default its field is empty, and
      // saving an empty field removes the key rather than writing one, so there
      // would be nothing to become "saved".
      final temp = byId(c.envRanges, 'temp');
      expect(temp.maxIsPrefill, isTrue);
      expect(temp.max.text, isNotEmpty);

      expect(await c.save(), isNull);
      expect(
        temp.maxIsPrefill,
        isFalse,
        reason: 'After a save the key exists and a rule is armed, so the field '
            'is no longer showing an unsaved default.',
      );

      // The value really reached the store, and a controller reading that store
      // treats it as saved. Read it back explicitly because the helper seeds a
      // fresh mock store, so a plain reload would just start from empty again.
      final stored = (await SharedPreferences.getInstance())
          .getString(SettingsKeys.environmentTempMax);
      expect(stored, isNotNull);

      final reloaded =
          await controller(initial: {SettingsKeys.environmentTempMax: stored!});
      expect(
        byId(reloaded.envRanges, 'temp').maxIsPrefill,
        isFalse,
        reason: 'The key is in the store, so this is a saved limit and must not '
            'be marked as an unsaved default.',
      );
    });

    testWidgets('the note counts limits, and they match the fields it sits under',
        (tester) async {
      // **Found on an emulator.** The note at the foot of the Environment alerts
      // card read "3 limits are shown as defaults" directly beneath five fields
      // each captioned "Not saved yet". It counted the *ranges* that had at least
      // one prefilled side -- temperature, humidity, TDS -- while the sentence and
      // the per-field captions are both about *limits*.
      //
      // The count is derived from the controller rather than written out, so this
      // cannot drift from the data again. And the cross-check against the actual
      // count of flagged fields is the part that matters: it is what makes the
      // sentence a claim about the screen rather than a claim about the model.
      final c = await controller();
      final flaggedFields = [
        for (final range in c.envRanges) ...[
          if (range.minIsPrefill) 'min',
          if (range.maxIsPrefill) 'max',
        ],
      ].length;

      expect(
        flaggedFields,
        greaterThan(0),
        reason: 'a fresh install has defaults, so there is something to count; '
            'if this is zero the test is not exercising the case at all',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnsavedDefaultsNote(ranges: c.envRanges),
          ),
        ),
      );

      // Read the sentence off the rendered paragraph rather than asserting a
      // literal, so this test breaks when the *number* is wrong and not when the
      // wording is reworded.
      final text = tester.widgetList<Text>(find.byType(Text)).first.data!;
      final match = RegExp(r'^(\d+) limits?').firstMatch(text);
      expect(match, isNotNull, reason: 'the note said "$text"');
      expect(
        int.parse(match!.group(1)!),
        flaggedFields,
        reason: 'the note said "$text" while $flaggedFields fields are captioned '
            '"Not saved yet" -- a count that contradicts what it counts is worse '
            'than no count',
      );
    });
  });
}
