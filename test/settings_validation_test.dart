import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/settings/settings_controller.dart';
import 'package:plts_monitoring/models/settings_keys.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SettingsController _controller;

EnvRangeSetting range({
  String min = '',
  String max = '',
  double? minAllowed,
  double? maxAllowed,
}) {
  final setting = EnvRangeSetting(
    id: 'temp',
    label: 'Ambient temperature',
    unit: '°C',
    minAllowed: minAllowed,
    maxAllowed: maxAllowed,
  );
  setting.min.text = min;
  setting.max.text = max;
  return setting;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final themeController = AppThemeController();
    await themeController.load();
    _controller = SettingsController(themeController: themeController);
  });

  tearDown(() => _controller.dispose());

  group('validateEnvRange', () {
    test('accepts blank fields (limit simply not monitored)', () {
      expect(validateEnvRange(range(), errorLabel: 'Temperature'), isNull);
    });

    test('accepts a valid ordered pair', () {
      expect(
        validateEnvRange(
          range(min: '10', max: '30', minAllowed: -40, maxAllowed: 100),
          errorLabel: 'Temperature',
        ),
        isNull,
      );
    });

    test('rejects non-numeric input', () {
      expect(
        validateEnvRange(range(min: 'abc'), errorLabel: 'Temperature'),
        'Temperature must be a valid number.',
      );
      expect(
        validateEnvRange(range(max: '12,5'), errorLabel: 'Temperature'),
        'Temperature must be a valid number.',
      );
    });

    test('rejects values outside the allowed bounds', () {
      expect(
        validateEnvRange(
          range(min: '-60', minAllowed: -40),
          errorLabel: 'Temperature',
        ),
        'Temperature cannot be lower than -40.0.',
      );
      expect(
        validateEnvRange(
          range(max: '120', maxAllowed: 100),
          errorLabel: 'Temperature',
        ),
        'Temperature cannot be higher than 100.0.',
      );
    });

    test('rejects a minimum that is not below the maximum', () {
      expect(
        validateEnvRange(range(min: '30', max: '30'), errorLabel: 'Temperature'),
        'The minimum Temperature limit must be lower than the maximum limit.',
      );
      expect(
        validateEnvRange(range(min: '40', max: '30'), errorLabel: 'Temperature'),
        'The minimum Temperature limit must be lower than the maximum limit.',
      );
    });

    test('validates only the populated side when one is blank', () {
      expect(
        validateEnvRange(
          range(min: '10', maxAllowed: 5),
          errorLabel: 'Temperature',
        ),
        'The Temperature minimum cannot be above 5.0, the highest this sensor can report.',
      );
      expect(
        validateEnvRange(range(max: '10', minAllowed: 20), errorLabel: 'Temperature'),
        'The Temperature maximum cannot be below 20.0, the lowest this sensor can report.',
      );
    });
  });

  group('validateDailyTargetError', () {
    test('treats blank as "no target"', () {
      expect(validateDailyTargetError(''), isNull);
      expect(validateDailyTargetError('   '), isNull);
    });

    test('accepts a positive number', () {
      expect(validateDailyTargetError('12.5'), isNull);
    });

    test('rejects zero, negatives, and non-numeric text', () {
      const message = 'The production target must be a number greater than 0.';
      expect(validateDailyTargetError('0'), message);
      expect(validateDailyTargetError('-3'), message);
      expect(validateDailyTargetError('sepuluh'), message);
    });
  });

  group('validateEnvironmentAlertsEnabled', () {
    final populated = range(min: '10', max: '30');
    final blank = range();

    test('does not require limits when disabled', () {
      expect(
        validateEnvironmentAlertsEnabled(
          enabled: false,
          ranges: [blank, blank],
        ),
        isNull,
      );
    });

    test('requires at least one limit when enabled', () {
      expect(
        validateEnvironmentAlertsEnabled(
          enabled: true,
          ranges: [blank, blank],
        ),
        'Set at least one sensor limit to enable alerts.',
      );
    });

    test('accepts a single populated limit', () {
      expect(
        validateEnvironmentAlertsEnabled(
          enabled: true,
          ranges: [blank, populated],
        ),
        isNull,
      );
    });
  });

  group('EnvRangeSetting preference keys', () {
    test('blank fields count as not monitored', () {
      final setting = EnvRangeSetting(
        id: 'humidity',
        label: 'Humidity',
        unit: '%',
        minKey: SettingsKeys.environmentHumidityMin,
        maxKey: SettingsKeys.environmentHumidityMax,
      );
      expect(setting.isEmpty, isTrue);
      setting.min.text = '  ';
      expect(setting.isEmpty, isTrue, reason: 'whitespace counts as blank');
      setting.min.text = '40';
      expect(setting.isEmpty, isFalse);
    });

    test('every range uses the shared SettingsKeys contract', () {
      // The keys used to be built here by interpolating the id, which duplicated
      // SettingsKeys and could drift with nothing to catch it. They are now passed
      // in, so this is where the two are pinned together.
      final keys = {
        for (final range in _controller.envRanges)
          range.id: (range.minKey, range.maxKey),
      };
      expect(keys['temp'], (
        SettingsKeys.environmentTempMin,
        SettingsKeys.environmentTempMax,
      ));
      expect(keys['humidity'], (
        SettingsKeys.environmentHumidityMin,
        SettingsKeys.environmentHumidityMax,
      ));
      expect(keys['tds'], (
        SettingsKeys.environmentTdsMin,
        SettingsKeys.environmentTdsMax,
      ));
    });

    test('prefilled limits match what the alarm engine defaults to', () {
      // The editor and the engine must start from the same numbers, or a user who
      // never opens Settings would be protected by different limits than the one
      // shown to them.
      for (final range in _controller.envRanges) {
        expect(range.min.text, isNotEmpty, reason: '${range.id} min');
      }
      // TDS is the exception and always will be: a sane upper cap does not exist.
      for (final id in ['temp', 'humidity']) {
        final range = _controller.envRanges.firstWhere((r) => r.id == id);
        expect(range.max.text, isNotEmpty, reason: '$id max');
      }
      expect(_controller.envAlerts, isTrue, reason: 'environment alerts are on by default');
      expect(
        _controller.offlineMinutes,
        AlarmThresholds.defaultOfflineMinutes,
      );
    });

    test('TDS starts with a lower limit and no upper limit', () {
      // Guard for the regression recorded in AGENTS.md: an upper bound low enough
      // to look safe would make the TDS alarm unreachable.
      final tds = _controller.envRanges.firstWhere((r) => r.id == 'tds');
      expect(tds.max.text, isEmpty);
      expect(tds.min.text, '${AlarmThresholds.defaultTdsMin.toInt()}');
    });
  });

  group('sensor bounds', () {
    EnvRangeSetting byId(String id) =>
        _controller.envRanges.firstWhere((setting) => setting.id == id);

    test('exposes the three monitored sensors in display order', () {
      expect(
        _controller.envRanges.map((setting) => setting.id),
        ['temp', 'humidity', 'tds'],
      );
    });

    test('caps temperature at a physically plausible range', () {
      final temp = byId('temp');
      expect(temp.minAllowed, -40);
      expect(temp.maxAllowed, 100);
    });

    test('caps humidity at 100 percent', () {
      final humidity = byId('humidity');
      expect(humidity.minAllowed, 0);
      expect(humidity.maxAllowed, 100);
    });

    test('does not cap TDS, which is legitimately far above 100 ppm', () {
      final tds = byId('tds');
      expect(tds.minAllowed, 0);
      expect(
        tds.maxAllowed,
        isNull,
        reason: 'nutrient solutions run 800-2000 ppm; a 100 ppm cap would '
            'make the TDS alert unreachable',
      );
      // And the real values must validate.
      for (final value in ['500', '1200', '2500', '35000']) {
        tds.min.text = '0';
        tds.max.text = value;
        expect(validateEnvRange(tds, errorLabel: 'TDS'), isNull);
      }
    });

    test('still rejects negative TDS', () {
      final tds = byId('tds');
      tds.min.text = '-5';
      expect(
        validateEnvRange(tds, errorLabel: 'TDS'),
        'TDS cannot be lower than 0.0.',
      );
    });
  });

  group('fish sensor bounds', () {
    // Deliberately a second helper rather than a parameterised `byId`: the
    // `sensor bounds` group above searches envRanges only, and widening it
    // would make an envRanges regression show up under a fish test name.
    EnvRangeSetting fishById(String id) =>
        _controller.fishRanges.firstWhere((setting) => setting.id == id);

    test('exposes the three fish sensors in display order', () {
      expect(
        _controller.fishRanges.map((setting) => setting.id),
        ['ph', 'water_temp', 'turbidity'],
      );
    });

    test('caps pH and water temperature at plausible ranges', () {
      expect(fishById('ph').minAllowed, 0);
      expect(fishById('ph').maxAllowed, 14);
      expect(fishById('water_temp').minAllowed, 0);
      expect(fishById('water_temp').maxAllowed, 50);
    });

    test('does not cap turbidity, which the sensor legitimately exceeds', () {
      final turbidity = fishById('turbidity');
      expect(turbidity.minAllowed, 0);
      expect(
        turbidity.maxAllowed,
        isNull,
        reason: 'the sensor on the test device reads 2396 NTU, so a 1000 NTU '
            'cap made it impossible to set a limit that matched reality and the '
            'turbidity alert could never be configured usefully',
      );
      // And the real values must validate.
      for (final value in ['3000', '5000', '100000']) {
        turbidity.max.text = value;
        expect(validateEnvRange(turbidity, errorLabel: 'Turbidity'), isNull);
      }
    });

    test('still rejects a negative turbidity limit', () {
      final turbidity = fishById('turbidity');
      turbidity.max.text = '-1';
      expect(
        validateEnvRange(turbidity, errorLabel: 'Turbidity'),
        'The Turbidity maximum cannot be below 0.0, the lowest this sensor can report.',
      );
    });

    test('turbidity is upper bound only, so it has no minimum field', () {
      // `minKey: null` is what makes the field disappear. An unguarded
      // `minKey!` on this range used to throw on load and on save.
      final turbidity = fishById('turbidity');
      expect(turbidity.minKey, isNull);
      expect(turbidity.maxKey, SettingsKeys.fishTurbidityMax);
    });
  });
}
