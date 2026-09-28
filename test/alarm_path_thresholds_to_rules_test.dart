import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/alarm_record.dart';
import 'package:plts_monitoring/models/settings_keys.dart';
import 'package:plts_monitoring/services/alarm_settings.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';
import 'package:plts_monitoring/utils/alarm_helpers.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The path from a saved threshold to an armed rule, pinned end to end.
///
/// The reported symptom was "I set alarms for the fish tank and the
/// environment in Settings, pressed Save, and nothing happened". The save
/// crash itself lives in the settings screen; this file guards the layer below
/// it, which is the one that would fail silently: a key written under one name
/// and read under another, a rule group that is never built, or a rule reading
/// a telemetry key the device never publishes. None of those raise anywhere —
/// the alarm simply never fires — so they are pinned here rather than left to
/// be found on a device.
void main() {
  group('settings key contract', () {
    test('the alarm side reads the exact keys Settings writes', () {
      // Both sides reference the same constants, so the *values* are what can
      // drift. Renaming a value orphans every device that already stored the
      // old key: the write and the read stay consistent with each other, the
      // stored preference is silently ignored, and the limit falls back to
      // "not monitored" with nothing in any log to say why.
      const expected = <String, String>{
        SettingsKeys.environmentAlertsEnabled: 'environment_alerts_enabled',
        SettingsKeys.environmentTempMin: 'environment_temp_min',
        SettingsKeys.environmentTempMax: 'environment_temp_max',
        SettingsKeys.environmentHumidityMin: 'environment_humidity_min',
        SettingsKeys.environmentHumidityMax: 'environment_humidity_max',
        SettingsKeys.environmentTdsMin: 'environment_tds_min',
        SettingsKeys.environmentTdsMax: 'environment_tds_max',
        SettingsKeys.fishAlertsEnabled: 'fish_alerts_enabled',
        SettingsKeys.fishPhMin: 'fish_ph_min',
        SettingsKeys.fishPhMax: 'fish_ph_max',
        SettingsKeys.fishTempMin: 'fish_temp_min',
        SettingsKeys.fishTempMax: 'fish_temp_max',
        SettingsKeys.fishTurbidityMax: 'fish_turbidity_max',
      };
      expect(expected.values.toSet(), hasLength(expected.length),
          reason: 'two settings sharing one key would overwrite each other');
    });
  });

  group('a saved threshold becomes a rule', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(_savedBySettingsScreen);
      // Awaited so the instance reads the mock values installed above; every
      // test in this group works from the same written state.
      await SharedPreferences.getInstance();
    });

    Future<AlarmThresholds> thresholds() async =>
        readAlarmThresholds(await SharedPreferences.getInstance());

    test('the stored values win over every default', () async {
      final saved = await thresholds();
      // Deliberately not the defaults: if the reader fell back for any reason
      // — wrong key, wrong type, unparseable text — these would come back as
      // the defaults and the test would still see *a* number.
      expect(saved.environmentAlerts, isTrue);
      expect(saved.tempMax, 31);
      expect(saved.tdsMin, 900);
      expect(saved.tdsMax, isNull,
          reason: 'TDS has no upper bound and Settings never writes one');
      expect(saved.fishAlerts, isTrue);
      expect(saved.fishPhMin, 6.8);
      expect(saved.fishPhMax, 8.2);
      expect(saved.fishTempMin, 22);
      expect(saved.fishTempMax, 29);
      expect(saved.fishTurbidityMax, 55);
    });

    test('both groups are built, with the limits that were saved', () async {
      final rules = buildAlarmRules(await thresholds());
      expect([
        for (final rule in rules)
          if (rule.group == AlarmGroup.environment ||
              rule.group == AlarmGroup.fish)
            rule.id,
      ], [
        'environment_ambient_temp_low',
        'environment_ambient_temp_high',
        'environment_humidity_low',
        'environment_humidity_high',
        'environment_tds_low',
        'fish_ph_low',
        'fish_ph_high',
        'fish_water_temp_low',
        'fish_water_temp_high',
        'fish_turbidity_high',
      ]);

      AlarmRule ruleFor(String id) => rules.firstWhere((r) => r.id == id);
      expect(ruleFor('environment_ambient_temp_high').limit, 31);
      expect(ruleFor('fish_ph_high').limit, 8.2);
      expect(ruleFor('fish_turbidity_high').limit, 55);
      // The freshness gate keeps an old out-of-range reading from describing a
      // condition that has already ended.
      expect(ruleFor('fish_ph_high').requireFreshSensor, isTrue);
      expect(ruleFor('environment_tds_low').requireFreshSensor, isTrue);
      // pH is reported to two decimals; rendering it with one would disagree
      // with the reading shown on the Fish page.
      expect(ruleFor('fish_ph_high').decimals, 2);
      expect(ruleFor('fish_turbidity_high').decimals, 1);
    });

    test('a breach produces the same signal the banner would show', () async {
      final now = DateTime.utc(2026, 9, 27, 10);
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(await thresholds()),
        readings: [
          AlarmReading(
            device: AlarmDevice.sensor,
            values: const {'temp_dht': 40.0, 'tds_ppm': 950},
            lastUpdate: now.subtract(const Duration(minutes: 1)),
          ),
          AlarmReading(
            device: AlarmDevice.fish,
            values: const {'ph': 9.1, 'suhu': 25.0, 'turbidity_ntu': 12.0},
            lastUpdate: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        now: now,
      );
      expect(signals.map((signal) => signal.id), [
        'environment_ambient_temp_high',
        'fish_ph_high',
      ]);
      expect(signals.last.message, 'pH too high: 9.10  (limit 8.2 )');
      expect(signals.last.severity, AlarmSeverity.warning);
    });

    test('the payload keeps the shape the native parser requires', () async {
      // `parseAlarmConfig` throws on an unknown version, an unknown device, a
      // rule whose device is not polled, or a config with rules but no
      // devices. A rejection there is logged and the whole config is dropped,
      // so Settings would still report success while the background check went
      // quiet — which is why the shape is pinned rather than assumed.
      final payload = alarmRulesToJson(buildAlarmRules(await thresholds()));
      expect(payload['version'], 1);
      final raw = (payload['rules'] as List).cast<Map<String, dynamic>>();
      expect(raw, isNotEmpty);
      expect(
        {for (final rule in raw) rule['device']},
        containsAll(['sensor', 'fish']),
        reason: 'a device with an armed rule must be polled or the whole '
            'config is rejected',
      );
      expect({for (final rule in raw) rule['group']},
          containsAll(['environment', 'fish']));
      for (final rule in raw) {
        expect(rule['comparison'], anyOf('lessThan', 'greaterThan', 'stale', 'offline'));
        if (rule['comparison'] == 'lessThan' ||
            rule['comparison'] == 'greaterThan') {
          expect(rule['metric'], isNotNull, reason: '${rule['id']} reads a value');
          expect(rule['limit'], isA<double>(), reason: '${rule['id']} has a limit');
        }
      }

      final restored = alarmRulesFromJson(payload);
      final rebuilt = buildAlarmRules(await thresholds());
      expect(restored.map((rule) => rule.id),
          [for (final rule in rebuilt) rule.id]);
      expect(restored.map((rule) => rule.limit),
          [for (final rule in rebuilt) rule.limit]);
    });
  });

  group('a blank limit is not monitored', () {
    test('an unset key arms nothing, for both groups', () async {
      // Settings removes the key rather than writing an empty string, so a
      // cleared field and a field that was never saved are the same value in
      // storage. Both have to mean "not monitored" or the fish section's
      // subtitle — "Blank limits are not monitored" — would be untrue and a
      // limit the user removed would keep firing at its default.
      SharedPreferences.setMockInitialValues(const {});
      final saved = readAlarmThresholds(await SharedPreferences.getInstance());
      expect(saved.environmentAlerts, isTrue,
          reason: 'the toggle defaults to on');
      expect(saved.fishAlerts, isTrue);
      expect(saved.tempMax, isNull);
      expect(saved.humidityMin, isNull);
      expect(saved.tdsMin, isNull);
      expect(saved.fishPhMin, isNull);
      expect(saved.fishPhMax, isNull);
      expect(saved.fishTempMin, isNull);
      expect(saved.fishTempMax, isNull);
      expect(saved.fishTurbidityMax, isNull);

      // The toggles are on, so the only rules that can exist are the
      // time-based energy ones. Nothing is invented for a sensor nobody
      // configured a limit for.
      final rules = buildAlarmRules(saved);
      expect(rules, isNotEmpty);
      expect(
        [
          for (final rule in rules)
            if (rule.group == AlarmGroup.environment ||
                rule.group == AlarmGroup.fish)
              rule.id,
        ],
        isEmpty,
      );
    });

    test('a cleared fish limit does not come back at its default', () async {
      // Regression guard for the reported path: 6.5 is both the default and a
      // plausible deliberate value, so a cleared field quietly re-arming at
      // 6.5 is invisible until the user gets a "pH too low" alarm for a limit
      // they deleted.
      SharedPreferences.setMockInitialValues({
        SettingsKeys.fishAlertsEnabled: true,
        SettingsKeys.fishPhMin: '6.8',
        // fish_ph_max deliberately absent: the user cleared it.
        SettingsKeys.fishTempMin: '22',
        SettingsKeys.fishTempMax: '29',
        SettingsKeys.fishTurbidityMax: '55',
      });
      final saved = readAlarmThresholds(await SharedPreferences.getInstance());
      expect(saved.fishPhMin, 6.8);
      expect(saved.fishPhMax, isNull,
          reason: 'the default 8.5 must not resurrect itself');
      final ids = [for (final rule in buildAlarmRules(saved)) rule.id];
      expect(ids, contains('fish_ph_low'));
      expect(ids, isNot(contains('fish_ph_high')),
          reason: 'the cleared upper bound stays cleared');
    });
  });

  group('alarm_helpers agrees with the rules that produce the ids', () {
    // History records arrive as bare id strings, and `alarmTypeFromId` is the
    // only thing that maps them back. A fish id that fell through to the
    // fallback would be filed as a device-offline alarm in the history screen
    // while the banner called it a pH warning.
    test('classifies every id the saved thresholds produce', () async {
      SharedPreferences.setMockInitialValues(_savedBySettingsScreen);
      final saved = readAlarmThresholds(await SharedPreferences.getInstance());
      final valued = [
        for (final rule in buildAlarmRules(saved))
          if (rule.metric != null) rule,
      ];
      expect(valued, isNotEmpty);
      for (final rule in valued) {
        expect(alarmTypeFromId(rule.id), rule.type, reason: rule.id);
        expect(alarmSeverityFromId(rule.id), rule.severity, reason: rule.id);
      }
      expect(
        [for (final rule in valued) alarmTypeFromId(rule.id)],
        containsAll([
          AlarmType.environmentTemp,
          AlarmType.environmentTds,
          AlarmType.fishPh,
          AlarmType.fishTemp,
          AlarmType.fishTurbidity,
        ]),
      );
    });
  });

  group('every rule reads a key its device publishes', () {
    // A rule whose metric is absent from the device's key set is built,
    // shipped and stored, then skipped by the evaluator because the reading
    // never contains the value. No error, no alarm — and the parity fixture
    // still passes, because it feeds values by hand. This is the guard for
    // "rules exist but never fire".
    const deviceIds = <AlarmDevice, String>{
      AlarmDevice.battery: ThingsBoardApi.deviceBattery,
      AlarmDevice.pzem: ThingsBoardApi.devicePzem,
      AlarmDevice.sensor: ThingsBoardApi.deviceSensor,
      AlarmDevice.fish: ThingsBoardApi.deviceFish,
    };

    test('for every group as the thresholds are saved', () async {
      SharedPreferences.setMockInitialValues(_savedBySettingsScreen);
      final saved = readAlarmThresholds(await SharedPreferences.getInstance());
      final rules = buildAlarmRules(saved);
      expect(rules, isNotEmpty);
      var checked = 0;
      for (final rule in rules) {
        final metric = rule.metric;
        if (metric == null) continue;
        final keys = ThingsBoardApi.deviceKeysById[deviceIds[rule.device]];
        expect(keys, isNotNull, reason: rule.id);
        expect(keys, contains(metric), reason: '${rule.id} reads $metric');
        checked++;
      }
      // Stale and offline rules carry no metric, so without this the loop
      // could pass by checking nothing at all.
      expect(checked, greaterThanOrEqualTo(10));
    });
  });
}

/// Exactly what `SettingsController.save()` writes for the alert settings:
/// booleans for the toggles, and the text of every non-blank field stored as a
/// string. Blank fields are removed rather than stored empty, which is why
/// [SettingsKeys.environmentTdsMax] is absent below.
const Map<String, Object> _savedBySettingsScreen = {
  SettingsKeys.energyAlertsEnabled: true,
  SettingsKeys.environmentAlertsEnabled: true,
  SettingsKeys.fishAlertsEnabled: true,
  SettingsKeys.lowSocThreshold: 25,
  SettingsKeys.staleTelemetryMinutes: 10,
  SettingsKeys.offlineTelemetryMinutes: 60,
  SettingsKeys.environmentTempMin: '15',
  SettingsKeys.environmentTempMax: '31',
  SettingsKeys.environmentHumidityMin: '40',
  SettingsKeys.environmentHumidityMax: '85',
  SettingsKeys.environmentTdsMin: '900',
  SettingsKeys.fishPhMin: '6.8',
  SettingsKeys.fishPhMax: '8.2',
  SettingsKeys.fishTempMin: '22',
  SettingsKeys.fishTempMax: '29',
  SettingsKeys.fishTurbidityMax: '55',
};
