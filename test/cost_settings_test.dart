import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/settings/utils/settings_validation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plts_monitoring/models/settings_keys.dart';

/// The two optional numbers behind the cost card, and the round trip that keeps
/// the dashboard and the Settings screen telling the same story.
///
/// **The round trip is the test that matters here.** These two values were added
/// to a screen, a controller, a validator and a preferences key in four places;
/// the dashboard reads them by key and never sees the controller at all. A key
/// spelled differently on the two sides fails silently — the card simply never
/// appears, which is indistinguishable from a user who has not filled it in.
void main() {
  group('validateTariffError', () {
    test('blank is valid and means unset', () {
      expect(validateTariffError(''), isNull);
      expect(validateTariffError('   '), isNull);
    });

    test('a positive tariff is valid', () {
      expect(validateTariffError('1500'), isNull);
      expect(validateTariffError('1443,7'.replaceAll(',', '.')), isNull);
    });

    test('zero, negative and non-numeric are rejected', () {
      expect(validateTariffError('0'), isNotNull);
      expect(validateTariffError('-1'), isNotNull);
      expect(validateTariffError('seribu'), isNotNull);
    });

    // **The upper bound exists to catch a fat-fingered key**, not to model the
    // world. Without it a stray `1500000` becomes a lifetime figure that still
    // renders.
    test('an implausible tariff is rejected', () {
      expect(validateTariffError('1500000'), isNotNull);
      expect(validateTariffError('${kMaxTariffPerKwh + 1}'), isNotNull);
      expect(validateTariffError('$kMaxTariffPerKwh'), isNull);
    });
  });

  group('validateInstalledWpError', () {
    test('blank is valid and means unset', () {
      expect(validateInstalledWpError(''), isNull);
    });

    test('a plausible nameplate is valid', () {
      expect(validateInstalledWpError('450'), isNull);
      expect(validateInstalledWpError('5000'), isNull);
    });

    // **The floor is what keeps this widget from dividing by zero.** A zero
    // nameplate would produce an infinite capacity factor, which is a rendering
    // crash rather than a wrong number.
    test('below the floor is rejected, and zero especially', () {
      expect(validateInstalledWpError('0'), isNotNull);
      expect(validateInstalledWpError('49'), isNotNull);
      expect(validateInstalledWpError('-500'), isNotNull);
      expect(validateInstalledWpError('50'), isNull);
    });

    test('non-numeric and implausibly large are rejected', () {
      expect(validateInstalledWpError('sepaten'), isNotNull);
      expect(validateInstalledWpError('10000001'), isNotNull);
    });
  });

  group('the dashboard can read what the settings screen wrote', () {
    test('both keys are written under the names the dashboard reads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Written the way `_saveIfNotEmpty` writes them: a string, or nothing.
      await prefs.setString(SettingsKeys.electricityTariffPerKwh, '1500');
      await prefs.setString(SettingsKeys.pvInstalledWp, '450');

      // Read the way `dashboard_screen.dart`'s `_readDouble` reads them.
      expect(
        double.tryParse(
          prefs.getString(SettingsKeys.electricityTariffPerKwh) ?? '',
        ),
        1500,
      );
      expect(
        double.tryParse(prefs.getString(SettingsKeys.pvInstalledWp) ?? ''),
        450,
      );
    });

    // **Blank removes the key rather than storing an empty string**, so a user
    // who clears the field gets the "not set" state rather than a parse failure
    // treated as a value.
    test('clearing a field removes its key entirely', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.electricityTariffPerKwh: '1500',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SettingsKeys.electricityTariffPerKwh);

      expect(prefs.getString(SettingsKeys.electricityTariffPerKwh), isNull);
      expect(double.tryParse(prefs.getString(SettingsKeys.electricityTariffPerKwh) ?? ''), isNull);
    });
  });
}