import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';

/// Replays the shared parity vectors through the Dart evaluator.
///
/// The same file is replayed by
/// `android/app/src/test/kotlin/tech/mbkm/energrow/alarm/AlarmParityTest.kt`.
/// The two evaluators are separate implementations of the same rules, one in
/// Dart for the dashboard and one in Kotlin for the background check, and the
/// only thing keeping them in agreement is that both are asserted against this
/// one set of expected messages. If a change lands on one side and not the
/// other, one of the two tests fails rather than the user discovering that a
/// notification says something different from the app.
void main() {
  // Lives under android/ because the Kotlin test reads it from the JVM test
  // classpath, which is the one place both languages can load the same file
  // from. Reading it by path keeps a single copy; a duplicated fixture would
  // drift, which is the entire problem this file exists to catch.
  final fixture = File(
    'android/app/src/test/resources/alarm_parity_vectors.json',
  );
  final scenarios =
      ((jsonDecode(fixture.readAsStringSync()) as Map)['scenarios'] as List)
          .cast<Map<String, dynamic>>();

  test('the fixture exists and has scenarios', () {
    expect(scenarios, isNotEmpty);
  });

  for (final scenario in scenarios) {
    final name = scenario['name'] as String;
    test('evaluates "$name" the same way the native side will', () {
      // The rule block in the fixture is what buildAlarmRules produced when the
      // fixture was generated. Asserting it still matches means the generator
      // cannot quietly go stale, which would otherwise turn this into a test
      // that only compares the evaluator against itself.
      final rebuilt = alarmRulesToJson(
        buildAlarmRules(
          _thresholdsOf(
            (scenario['thresholds'] as Map).cast<String, dynamic>(),
          ),
        ),
      );
      expect(
        rebuilt['rules'],
        scenario['rules'],
        reason: 'run tool/generate_alarm_parity_fixture.dart to refresh',
      );

      final rules = alarmRulesFromJson({
        'version': 1,
        'rules': scenario['rules'],
      });
      final signals = evaluateAlarmRules(
        rules: rules,
        readings: [
          for (final raw in (scenario['readings'] as List).cast<Map>())
            AlarmReading(
              device: AlarmDevice.fromWireName(raw['device'] as String)!,
              values: (raw['values'] as Map).cast<String, double>(),
              lastUpdate: DateTime.parse(raw['lastUpdate'] as String),
            ),
        ],
        now: DateTime.parse(scenario['now'] as String),
      );

      expect(
        [
          for (final signal in signals)
            {'id': signal.id, 'message': signal.message},
        ],
        scenario['expected'],
        reason: scenario['description'] as String,
      );
    });
  }
}

AlarmThresholds _thresholdsOf(Map<String, dynamic> json) => AlarmThresholds(
  energyAlerts: json['energyAlerts'] as bool,
  environmentAlerts: json['environmentAlerts'] as bool,
  lowSoc: (json['lowSoc'] as num).toDouble(),
  staleMinutes: (json['staleMinutes'] as num).toInt(),
  offlineMinutes: (json['offlineMinutes'] as num?)?.toInt() ?? 60,
  tempMin: (json['tempMin'] as num?)?.toDouble(),
  tempMax: (json['tempMax'] as num?)?.toDouble(),
  humidityMin: (json['humidityMin'] as num?)?.toDouble(),
  humidityMax: (json['humidityMax'] as num?)?.toDouble(),
  tdsMin: (json['tdsMin'] as num?)?.toDouble(),
  tdsMax: (json['tdsMax'] as num?)?.toDouble(),
  fishAlerts: json['fishAlerts'] as bool? ?? false,
  fishPhMin: (json['fishPhMin'] as num?)?.toDouble(),
  fishPhMax: (json['fishPhMax'] as num?)?.toDouble(),
  fishTempMin: (json['fishTempMin'] as num?)?.toDouble(),
  fishTempMax: (json['fishTempMax'] as num?)?.toDouble(),
  fishTurbidityMax: (json['fishTurbidityMax'] as num?)?.toDouble(),
);
