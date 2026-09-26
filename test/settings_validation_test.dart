import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';

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
}
