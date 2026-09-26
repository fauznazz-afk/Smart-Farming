import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/settings/settings_controller.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';
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
      expect(validateEnvRange(range(), errorLabel: 'suhu'), isNull);
    });

    test('accepts a valid ordered pair', () {
      expect(
        validateEnvRange(
          range(min: '10', max: '30', minAllowed: -40, maxAllowed: 100),
          errorLabel: 'suhu',
        ),
        isNull,
      );
    });

    test('rejects non-numeric input', () {
      expect(
        validateEnvRange(range(min: 'abc'), errorLabel: 'suhu'),
        'suhu harus berupa angka yang valid.',
      );
      expect(
        validateEnvRange(range(max: '12,5'), errorLabel: 'suhu'),
        'suhu harus berupa angka yang valid.',
      );
    });

    test('rejects values outside the allowed bounds', () {
      expect(
        validateEnvRange(
          range(min: '-60', minAllowed: -40),
          errorLabel: 'suhu',
        ),
        'suhu tidak boleh kurang dari -40.0.',
      );
      expect(
        validateEnvRange(
          range(max: '120', maxAllowed: 100),
          errorLabel: 'suhu',
        ),
        'suhu tidak boleh lebih dari 100.0.',
      );
    });

    test('rejects a minimum that is not below the maximum', () {
      expect(
        validateEnvRange(range(min: '30', max: '30'), errorLabel: 'suhu'),
        'Batas minimum suhu harus lebih kecil dari batas maksimum.',
      );
      expect(
        validateEnvRange(range(min: '40', max: '30'), errorLabel: 'suhu'),
        'Batas minimum suhu harus lebih kecil dari batas maksimum.',
      );
    });

    test('validates only the populated side when one is blank', () {
      expect(
        validateEnvRange(
          range(min: '10', maxAllowed: 5),
          errorLabel: 'suhu',
        ),
        'suhu tidak boleh lebih dari 5.0.',
      );
      expect(
        validateEnvRange(range(max: '10', minAllowed: 20), errorLabel: 'suhu'),
        'suhu tidak boleh kurang dari 20.0.',
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
      const message = 'Target produksi harus berupa angka lebih besar dari 0.';
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
        'Isi minimal satu batas sensor untuk mengaktifkan peringatan.',
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
    test('derive keys from the id', () {
      final setting = EnvRangeSetting(
        id: 'humidity',
        label: 'Humidity',
        unit: '%',
      );
      expect(setting.minKey, 'environment_humidity_min');
      expect(setting.maxKey, 'environment_humidity_max');
      expect(setting.isEmpty, isTrue);
      setting.min.text = '  ';
      expect(setting.isEmpty, isTrue, reason: 'whitespace counts as blank');
      setting.min.text = '40';
      expect(setting.isEmpty, isFalse);
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
        'TDS tidak boleh kurang dari 0.0.',
      );
    });
  });
}
