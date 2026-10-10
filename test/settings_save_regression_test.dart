import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plts_monitoring/models/settings_keys.dart';
import 'package:plts_monitoring/screens/settings/settings_controller.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';
import 'package:plts_monitoring/screens/settings_screen.dart';
import 'package:plts_monitoring/services/cctv_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression guards for the "Save settings does nothing" bug.
///
/// The turbidity fish range declares no `minKey` (it is upper bound only), so
/// `save()` reached `range.minKey!` and threw after the environment values
/// were written. `SettingsScreen._save()` had no try/catch, so the exception
/// became an unhandled async error: no SnackBar, no pop, silent failure.

/// A controller over an empty preference store, disposed after each test.
Future<SettingsController> _freshController({
  Map<String, Object> initial = const {},
}) async {
  SharedPreferences.setMockInitialValues(initial);
  // A non-const map: the test platform writes into it, so `const {}` throws
  // "Cannot modify unmodifiable map" as soon as save() stores a CCTV URL.
  FlutterSecureStorage.setMockInitialValues({});
  final controller = SettingsController();
  addTearDown(controller.dispose);
  return controller;
}

EnvRangeSetting _byId(List<EnvRangeSetting> ranges, String id) =>
    ranges.firstWhere((range) => range.id == id);

/// Secure storage whose writes always fail, to exercise the failure path of
/// the save button without depending on the turbidity crash being present.
class _FailingSecureStorage extends FlutterSecureStoragePlatform {
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    throw StateError('secure storage is unavailable');
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      null;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      false;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {}

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      const {};

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}
}

Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'EnerGrow',
    packageName: 'tech.mbkm.energrow',
    version: '1.4.0',
    buildNumber: '10',
    buildSignature: '',
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: SettingsScreen(onLogout: () async {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsController.save()', () {
    test('completes when a fish range has no minKey and writes the rest',
        () async {
      final controller = await _freshController();
      final turbidity = _byId(controller.fishRanges, 'turbidity');
      expect(
        turbidity.minKey,
        isNull,
        reason: 'turbidity is upper bound only, which is the shape that broke save()',
      );
      turbidity.max.text = '2500';

      final error = await controller.save();

      expect(error, isNull, reason: 'save() must return success, not throw');
      expect(controller.saving, isFalse, reason: 'the saving flag must be cleared');

      final prefs = await SharedPreferences.getInstance();
      // The turbidity write sits after the minKey access that used to throw, so
      // it only lands when the loop runs to the end.
      //
      // A value is typed in first because the turbidity default was removed:
      // saving an empty field deliberately removes the key, so with a blank
      // field this probe could not tell "the loop finished" from "the key was
      // dropped for being empty". 2500 is also above the 2396 the sensor was
      // reading, which is the whole reason the upper cap went.
      expect(turbidity.max.text, '2500');
      expect(prefs.getString(SettingsKeys.fishTurbidityMax), turbidity.max.text);
      expect(prefs.getString(SettingsKeys.fishTurbidityMax), isNotEmpty);
      expect(
        prefs.getString(SettingsKeys.fishPhMin),
        _byId(controller.fishRanges, 'ph').min.text,
      );
      expect(
        prefs.getString(SettingsKeys.fishTempMax),
        _byId(controller.fishRanges, 'water_temp').max.text,
      );
      expect(
        prefs.getString(SettingsKeys.environmentTempMin),
        _byId(controller.envRanges, 'temp').min.text,
      );
      expect(
        prefs.getString(SettingsKeys.environmentTdsMin),
        _byId(controller.envRanges, 'tds').min.text,
      );
      expect(prefs.getBool(SettingsKeys.fishAlertsEnabled), isTrue);
      // The CCTV URLs are written after the range loops, so their presence is
      // what proves save() reached the end of its try block.
      expect(
        await const FlutterSecureStorage().read(key: 'cctv_url'),
        defaultAllowedCctvUrl,
      );
    });

    test('a saved one-sided limit survives a reload', () async {
      final controller = await _freshController();
      final turbidity = _byId(controller.fishRanges, 'turbidity');
      turbidity.max.text = '45';
      expect(await controller.save(), isNull);

      await controller.load();

      final reloaded = _byId(controller.fishRanges, 'turbidity');
      expect(reloaded.max.text, '45', reason: 'the keyed side must come back');
      expect(
        reloaded.min.text,
        '',
        reason: 'the missing side has no key, so there is nothing to restore',
      );
    });

    test('skips the missing side of a range that has only an upper key',
        () async {
      final controller = await _freshController();
      // A future range shaped like turbidity must not depend on being listed
      // in a hand-written loop, so the guard is checked generically too.
      controller.fishRanges.add(
        EnvRangeSetting(
          id: 'custom',
          label: 'Custom sensor',
          unit: '',
          minKey: null,
          maxKey: 'custom_sensor_max',
        ),
      );
      controller.fishRanges.last.max.text = '12';

      expect(await controller.save(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_sensor_max'), '12');
      expect(
        prefs.getKeys().contains('custom_sensor_min'),
        isFalse,
        reason: 'a null minKey must not be turned into a write',
      );
    });
  });

  group('SettingsController.load()', () {
    test('tolerates a range with a null minKey', () async {
      final controller = await _freshController(initial: {
        SettingsKeys.fishTurbidityMax: '45',
        SettingsKeys.fishPhMin: '6.1',
        SettingsKeys.environmentHumidityMax: '95',
      });

      await controller.load();

      final turbidity = _byId(controller.fishRanges, 'turbidity');
      expect(turbidity.max.text, '45');
      expect(turbidity.min.text, '', reason: 'nothing to read for a null key');
      expect(_byId(controller.fishRanges, 'ph').min.text, '6.1');
      expect(_byId(controller.envRanges, 'humidity').max.text, '95');
    });
  });

  group('SettingsScreen save feedback', () {
    testWidgets('a successful save closes the settings screen', (tester) async {
      await _pumpSettings(tester);

      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SettingsScreen),
        findsNothing,
        reason: 'a successful save pops the screen; before the fix it neither '
            'popped nor said anything',
      );
    });

    testWidgets('a save that throws reports the failure on screen',
        (tester) async {
      await _pumpSettings(tester);
      // Fail the write that happens after the range loops, so the exception
      // has to be reported by the screen rather than swallowed.
      FlutterSecureStoragePlatform.instance = _FailingSecureStorage();

      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();

      expect(
        find.text('Saving the settings failed. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.byType(SettingsScreen),
        findsOneWidget,
        reason: 'a failed save must keep the user on the screen',
      );
    });
  });
}
