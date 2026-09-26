// Throwaway generator for test/fixtures/alarm_parity_vectors.json.
//
// The fixture is consumed by both test/alarm_parity_test.dart and
// android/app/src/test/kotlin/.../AlarmParityTest.kt, so the rule blocks in it
// have to be exactly what buildAlarmRules produces. Writing them by hand is how
// the two sides would drift in the first place, so they are generated here and
// the hand-written part is the expected messages.
//
// Run with: dart run tool/generate_alarm_parity_fixture.dart
import 'dart:convert';
import 'dart:io';

import 'package:plts_monitoring/utils/alarm_rules.dart';

final now = DateTime.utc(2026, 9, 27, 10);

DateTime ago(Duration d) => now.subtract(d);

Map<String, dynamic> reading(
  AlarmDevice device,
  Map<String, double> values,
  Duration age,
) => {
  'device': device.wireName,
  'values': values,
  'lastUpdate': ago(age).toIso8601String(),
};

Map<String, dynamic> scenario(
  String name,
  String description,
  AlarmThresholds thresholds,
  List<Map<String, dynamic>> readings,
  List<Map<String, String>> expected,
) {
  final rules = buildAlarmRules(thresholds);
  final signals = evaluateAlarmRules(
    rules: rules,
    readings: [
      for (final entry in readings)
        AlarmReading(
          device: AlarmDevice.fromWireName(entry['device'] as String)!,
          values: (entry['values'] as Map).cast<String, double>(),
          lastUpdate: DateTime.parse(entry['lastUpdate'] as String),
        ),
    ],
    now: now,
  );
  final actual = [
    for (final signal in signals)
      {'id': signal.id, 'message': signal.message},
  ];
  if (jsonEncode(actual) != jsonEncode(expected)) {
    stderr.writeln('MISMATCH in "$name"');
    stderr.writeln('  expected: ${jsonEncode(expected)}');
    stderr.writeln('  actual:   ${jsonEncode(actual)}');
    exitCode = 1;
  }
  return {
    'name': name,
    'description': description,
    'now': now.toIso8601String(),
    'thresholds': _thresholdsToJson(thresholds),
    'rules': alarmRulesToJson(rules)['rules'],
    'readings': readings,
    'expected': expected,
  };
}

Map<String, dynamic> _thresholdsToJson(AlarmThresholds t) => {
  'energyAlerts': t.energyAlerts,
  'environmentAlerts': t.environmentAlerts,
  'lowSoc': t.lowSoc,
  'staleMinutes': t.staleMinutes,
  'tempMin': t.tempMin,
  'tempMax': t.tempMax,
  'humidityMin': t.humidityMin,
  'humidityMax': t.humidityMax,
  'tdsMin': t.tdsMin,
  'tdsMax': t.tdsMax,
};

void main() {
  const energy = AlarmThresholds(
    energyAlerts: true,
    environmentAlerts: false,
    lowSoc: 20,
    staleMinutes: 10,
  );
  const energyWithEnvironment = AlarmThresholds(
    energyAlerts: true,
    environmentAlerts: true,
    lowSoc: 20,
    staleMinutes: 10,
    tempMax: 30,
    tdsMin: 800,
  );
  const environmentOnlyTemp = AlarmThresholds(
    energyAlerts: false,
    environmentAlerts: true,
    lowSoc: 20,
    staleMinutes: 10,
    tempMax: 30,
  );
  const environmentOnly = AlarmThresholds(
    energyAlerts: false,
    environmentAlerts: true,
    lowSoc: 20,
    staleMinutes: 10,
    humidityMax: 80,
  );
  const none = AlarmThresholds(
    energyAlerts: false,
    environmentAlerts: false,
    lowSoc: 20,
    staleMinutes: 10,
  );
  const blankLimits = AlarmThresholds(
    energyAlerts: false,
    environmentAlerts: true,
    lowSoc: 20,
    staleMinutes: 10,
  );

  final fresh = Duration(minutes: 1);
  final scenarios = <Map<String, dynamic>>[
    scenario(
      'low_soc_below_threshold',
      'A battery below the charge threshold raises the one critical alarm.',
      energy,
      [reading(AlarmDevice.battery, {'soc': 15.4}, fresh)],
      [
        {'id': 'low_soc', 'message': 'SOC baterai rendah: 15%'},
      ],
    ),
    scenario(
      'low_soc_at_threshold_is_not_breached',
      'The comparison is strictly less than, so exactly at the threshold is fine.',
      energy,
      [reading(AlarmDevice.battery, {'soc': 20}, fresh)],
      [],
    ),
    scenario(
      'low_soc_rounds_to_whole_percent',
      'The charge is shown without decimals, rounding half away from zero.',
      energy,
      [reading(AlarmDevice.battery, {'soc': 15.5}, fresh)],
      [
        {'id': 'low_soc', 'message': 'SOC baterai rendah: 16%'},
      ],
    ),
    scenario(
      'stale_telemetry_names_the_device',
      'A device that stopped reporting is stale, and the message names it.',
      energy,
      [reading(AlarmDevice.pzem, {'power_ac': 120}, const Duration(minutes: 11))],
      [
        {
          'id': 'stale_pzem',
          'message': 'Data PZEM belum diperbarui',
        },
      ],
    ),
    scenario(
      'environment_high_needs_fresh_sensor',
      'An over-limit reading raises an alarm while the sensor is still reporting.',
      energyWithEnvironment,
      [
        reading(AlarmDevice.sensor, {'temp_dht': 31.2}, fresh),
        reading(AlarmDevice.battery, {'soc': 88}, fresh),
      ],
      [
        {
          'id': 'environment_ambient_temp_high',
          'message': 'Suhu lingkungan tinggi: 31.2 °C (batas 30.0 °C)',
        },
      ],
    ),
    scenario(
      'environment_is_silent_while_the_sensor_is_stale',
      'An old reading that crosses a limit describes a condition that already '
          'ended, so environment alarms wait for fresh data.',
      environmentOnlyTemp,
      [
        reading(AlarmDevice.sensor, {'temp_dht': 31.2}, const Duration(minutes: 40)),
        reading(AlarmDevice.battery, {'soc': 88}, fresh),
      ],
      [],
    ),
    scenario(
      'stale_sensor_still_alarms_alongside_a_silent_environment',
      'The freshness gate suppresses only the environment rules. A sensor that '
          'has stopped reporting is itself the alarm.',
      energyWithEnvironment,
      [
        reading(AlarmDevice.sensor, {'temp_dht': 31.2}, const Duration(minutes: 40)),
        reading(AlarmDevice.battery, {'soc': 88}, fresh),
      ],
      [
        {
          'id': 'stale_sensor',
          'message': 'Data Sensor lingkungan belum diperbarui',
        },
      ],
    ),
    scenario(
      'tds_lower_limit_without_an_upper_bound',
      'Nutrient solution runs well past any sane upper cap, so only a minimum '
          'is configured and only a low reading alarms.',
      energyWithEnvironment,
      [
        reading(AlarmDevice.sensor, {'tds_ppm': 650}, fresh),
        reading(AlarmDevice.battery, {'soc': 88}, fresh),
      ],
      [
        {
          'id': 'environment_tds_low',
          'message': 'TDS rendah: 650.0 ppm (batas 800.0 ppm)',
        },
      ],
    ),
    scenario(
      'environment_group_can_run_without_energy_alerts',
      'The two toggles are independent, so environment limits still work with '
          'energy alerts switched off. 84.25 is exactly representable in binary, '
          'so it also pins that both sides round a half away from zero.',
      environmentOnly,
      [reading(AlarmDevice.sensor, {'humidity_dht': 84.25}, fresh)],
      [
        {
          'id': 'environment_humidity_high',
          'message': 'Kelembapan tinggi: 84.3 % (batas 80.0 %)',
        },
      ],
    ),
    scenario(
      'no_rules_when_both_toggles_are_off',
      'With nothing armed there is nothing to evaluate, background included.',
      none,
      [reading(AlarmDevice.battery, {'soc': 3}, const Duration(hours: 5))],
      [],
    ),
    scenario(
      'blank_limit_is_not_monitored',
      'A limit left empty in Settings means the condition is not watched.',
      blankLimits,
      [reading(AlarmDevice.sensor, {'temp_dht': 55}, fresh)],
      [],
    ),
    scenario(
      'device_that_never_reported_is_not_an_alarm',
      'Silence from a device that was never read is missing data, not stale '
          'telemetry, and must not raise an alarm.',
      energy,
      [],
      [],
    ),
  ];

  final file = File('android/app/src/test/resources/alarm_parity_vectors.json')
    ..parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'scenarios': scenarios})}\n',
  );
  stdout.writeln('wrote ${file.path} with ${scenarios.length} scenarios');
}
