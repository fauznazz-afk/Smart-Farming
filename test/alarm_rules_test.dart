import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/alarm_record.dart';
import 'package:plts_monitoring/utils/alarm_helpers.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';

/// Guards for the rule engine that decides what counts as an alarm.
///
/// The same rule list drives the dashboard's alert banner and the native
/// background check, so a mistake here is not cosmetic: it changes what the
/// user gets notified about, and the native half has no test of its own beyond
/// the parity fixture.
void main() {
  group('buildAlarmRules', () {
    test('arms low SOC and one stale rule per device for energy alerts', () {
      final rules = buildAlarmRules(_energy);
      expect(rules.map((rule) => rule.id), [
        'low_soc',
        'offline_battery',
        'stale_battery',
        'offline_pzem',
        'stale_pzem',
        'offline_sensor',
        'stale_sensor',
      ]);
      final lowSoc = rules.first;
      expect(lowSoc.type, AlarmType.lowSoc);
      expect(lowSoc.severity, AlarmSeverity.critical);
      expect(lowSoc.metric, 'soc');
      expect(lowSoc.limit, 20);

      // A device that has stopped is critical; one that is merely behind is a
      // warning. Both exist because the two need different responses, and a short
      // hiccup must not escalate on its own.
      final offline = rules.firstWhere((rule) => rule.id == 'offline_pzem');
      expect(offline.type, AlarmType.deviceOffline);
      expect(offline.severity, AlarmSeverity.critical);
      expect(offline.comparison, AlarmComparison.offline);
      final stale = rules.firstWhere((rule) => rule.id == 'stale_pzem');
      expect(stale.severity, AlarmSeverity.warning);
      expect(offline.staleMinutes, greaterThan(stale.staleMinutes));
    });

    test('omits every rule when both toggles are off', () {
      expect(buildAlarmRules(_none), isEmpty);
    });

    test('builds environment rules only for limits that are set', () {
      final rules = buildAlarmRules(
        const AlarmThresholds(
          energyAlerts: false,
          environmentAlerts: true,
          lowSoc: 20,
          staleMinutes: 10,
          offlineMinutes: 60,
          tempMax: 30,
        ),
      );
      expect(rules.map((rule) => rule.id), ['environment_ambient_temp_high']);
      expect(rules.single.comparison, AlarmComparison.greaterThan);
      expect(rules.single.requireFreshSensor, isTrue);
    });

    test('builds both sides of a range when both limits are set', () {
      final rules = buildAlarmRules(
        const AlarmThresholds(
          energyAlerts: false,
          environmentAlerts: true,
          lowSoc: 20,
          staleMinutes: 10,
          offlineMinutes: 60,
          humidityMin: 40,
          humidityMax: 80,
        ),
      );
      expect(rules.map((rule) => rule.id), [
        'environment_humidity_low',
        'environment_humidity_high',
      ]);
      expect(rules.map((rule) => rule.type), [
        AlarmType.environmentHumidity,
        AlarmType.environmentHumidity,
      ]);
    });

    test('leaves TDS without an upper bound, which the readings require', () {
      // Regression guard. A cap low enough to look safe made the TDS alarm
      // unreachable, because nutrient solution sits at 800-2000 ppm and sea
      // water near 35000.
      final rules = buildAlarmRules(
        const AlarmThresholds(
          energyAlerts: false,
          environmentAlerts: true,
          lowSoc: 20,
          staleMinutes: 10,
          offlineMinutes: 60,
          tdsMin: 800,
        ),
      );
      expect(rules.single.id, 'environment_tds_low');
      expect(rules.single.limit, 800);
    });

    test('carries the staleness window on each rule so it is self-contained', () {
      final rules = buildAlarmRules(
        const AlarmThresholds(
          energyAlerts: true,
          environmentAlerts: false,
          lowSoc: 20,
          staleMinutes: 45,
          offlineMinutes: 300,
        ),
      );
      // The native side cannot read the app's settings, so every window travels
      // with its rule, and each rule only ever uses its own.
      AlarmRule ruleFor(String id) => rules.firstWhere((r) => r.id == id);
      expect(ruleFor('stale_pzem').staleMinutes, 45);
      expect(ruleFor('offline_pzem').staleMinutes, 300);
      expect(ruleFor('low_soc').staleMinutes, 45);
    });
  });

  group('evaluateAlarmRules', () {
    final now = DateTime.utc(2026, 9, 27, 10);

    test('a device that was never read raises nothing at all', () {
      // Not the same as a stale device: a device with no reading means the poll
      // failed or has not run, and turning that into an alarm would report an
      // outage as three conditions.
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(_energy),
        readings: const [],
        now: now,
      );
      expect(signals, isEmpty);
    });

    test('a partial result still evaluates the devices that did answer', () {
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(_energy),
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: const {'soc': 12},
            lastUpdate: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        now: now,
      );
      expect(signals.map((signal) => signal.id), ['low_soc']);
      expect(signals.single.value, 12);
    });

    test('treats a device that has never reported as stale', () {
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(_energy),
        readings: const [
          AlarmReading(
            device: AlarmDevice.pzem,
            values: {},
            lastUpdate: null,
          ),
        ],
        now: now,
      );
      // Both, not just stale: a device that has never reported is past both
      // windows at once, and "stopped sending data" is the more useful of the
      // two things to be told.
      expect(signals.map((signal) => signal.id), ['offline_pzem', 'stale_pzem']);
      expect(signals.every((signal) => signal.value == null), isTrue);
      expect(
        signals.firstWhere((s) => s.id == 'offline_pzem').severity,
        AlarmSeverity.critical,
      );
    });

    test('ignores a timestamp in the future instead of calling it stale', () {
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(_energy),
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: const {'soc': 50},
            lastUpdate: now.add(const Duration(minutes: 30)),
          ),
        ],
        now: now,
      );
      expect(signals, isEmpty);
    });

    test('needs both bounds to be breached to raise both range alarms', () {
      const thresholds = AlarmThresholds(
        energyAlerts: false,
        environmentAlerts: true,
        lowSoc: 20,
        staleMinutes: 10,
        offlineMinutes: 60,
        tdsMin: 800,
        tdsMax: 2000,
      );
      List<String> idsFor(double value) => evaluateAlarmRules(
        rules: buildAlarmRules(thresholds),
        readings: [
          AlarmReading(
            device: AlarmDevice.sensor,
            values: {'tds_ppm': value},
            lastUpdate: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        now: now,
      ).map((signal) => signal.id).toList();

      expect(idsFor(500), ['environment_tds_low']);
      expect(idsFor(1200), isEmpty);
      expect(idsFor(2500), ['environment_tds_high']);
      // Exactly on a limit is not a breach, matching the low-SOC comparison.
      expect(idsFor(800), isEmpty);
      expect(idsFor(2000), isEmpty);
    });

    test('announces an alarm only when it starts, not on every check', () {
      final rules = buildAlarmRules(_energy);
      List<AlarmSignal> firing() => evaluateAlarmRules(
        rules: rules,
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: const {'soc': 12},
            lastUpdate: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        now: now,
      );

      // First sighting: announce it.
      final first = newlyActiveSignals(
        signals: firing(),
        alreadyActive: const {},
      );
      expect(first.map((signal) => signal.id), ['low_soc']);

      // Still firing on a later check: say nothing. The dashboard polls every ten
      // seconds, so without this the user would get a notification every ten
      // seconds for as long as the battery stayed low.
      expect(
        newlyActiveSignals(
          signals: firing(),
          alreadyActive: const {'low_soc'},
        ),
        isEmpty,
      );

      // Cleared, then it happens again: announce it a second time.
      expect(newlyActiveSignals(signals: firing(), alreadyActive: const {}), hasLength(1));
    });

    test('an alarm the background already reported is not announced again', () {
      // The shared set is what makes the background and the dashboard agree that
      // an ongoing condition has been reported exactly once.
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(_energy),
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: const {'soc': 12},
            lastUpdate: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        now: now,
      );
      expect(
        newlyActiveSignals(signals: signals, alreadyActive: const {'low_soc'}),
        isEmpty,
      );
      expect(
        newlyActiveSignals(signals: signals, alreadyActive: const {'low_soc'}).length,
        0,
      );
    });

    test('renders the message the notification has to carry', () {
      expect(
        formatAlarmMessage(
          buildAlarmRules(_energy).first,
          value: 15.4,
        ),
        'SOC baterai rendah: 15%',
      );
      expect(
        formatAlarmMessage(
          buildAlarmRules(_energy).firstWhere((r) => r.id == 'stale_pzem'),
          value: null,
        ),
        'Data PZEM belum diperbarui',
      );
    });
  });

  group('rule serialisation', () {
    test('round-trips through JSON without losing anything', () {
      final rules = buildAlarmRules(
        const AlarmThresholds(
          energyAlerts: true,
          environmentAlerts: true,
          lowSoc: 15,
          staleMinutes: 5,
          offlineMinutes: 60,
          tempMin: 10,
          tempMax: 30,
          humidityMax: 80,
          tdsMin: 800,
        ),
      );
      final restored = alarmRulesFromJson(alarmRulesToJson(rules));
      expect(restored.length, rules.length);
      for (var index = 0; index < rules.length; index++) {
        expect(restored[index].id, rules[index].id);
        expect(restored[index].type, rules[index].type);
        expect(restored[index].severity, rules[index].severity);
        expect(restored[index].device, rules[index].device);
        expect(restored[index].metric, rules[index].metric);
        expect(restored[index].comparison, rules[index].comparison);
        expect(restored[index].limit, rules[index].limit);
        expect(restored[index].label, rules[index].label);
        expect(restored[index].unit, rules[index].unit);
        expect(restored[index].decimals, rules[index].decimals);
        expect(restored[index].message, rules[index].message);
        expect(restored[index].staleMinutes, rules[index].staleMinutes);
        expect(
          restored[index].requireFreshSensor,
          rules[index].requireFreshSensor,
        );
      }
    });

    test('stamps a payload version the native side can reject', () {
      expect(alarmRulesToJson(const [])['version'], 1);
    });

    test('refuses a payload with no rule list', () {
      expect(
        () => alarmRulesFromJson(const {}),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses an unknown device rather than guessing one', () {
      final payload = alarmRulesToJson(buildAlarmRules(_energy));
      (payload['rules'] as List).first['device'] = 'inverter';
      expect(
        () => alarmRulesFromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('alarm_helpers', () {
    test('classifies ids the way the rules that produce them do', () {
      final byId = {
        for (final rule in buildAlarmRules(
          const AlarmThresholds(
            energyAlerts: true,
            environmentAlerts: true,
            lowSoc: 20,
            staleMinutes: 10,
            offlineMinutes: 60,
            tempMax: 30,
            tdsMin: 800,
            humidityMax: 80,
          ),
        ))
          rule.id: rule,
      };
      // The helper classifies ids that arrive from stored history, so it has to
      // agree with the rule that generated them.
      for (final entry in byId.entries) {
        expect(alarmTypeFromId(entry.key), entry.value.type, reason: entry.key);
        expect(
          alarmSeverityFromId(entry.key),
          entry.value.severity,
          reason: entry.key,
        );
      }
    });

    test('lists stale devices for the banner but never an unread one', () {
      final now = DateTime.utc(2026, 9, 27, 10);
      List<String> names({
        required Map<String, double> values,
        required DateTime? lastUpdate,
      }) => staleDeviceNames(
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: values,
            lastUpdate: lastUpdate,
          ),
        ],
        staleMinutes: 10,
        now: now,
      );

      expect(names(values: const {'soc': 50}, lastUpdate: now), isEmpty);
      expect(
        names(
          values: const {'soc': 50},
          lastUpdate: now.subtract(const Duration(minutes: 30)),
        ),
        ['Baterai'],
      );
      // Never read at all: silence before the first poll is not staleness.
      expect(names(values: const {}, lastUpdate: null), isEmpty);
    });
  });
}

const _energy = AlarmThresholds(
  energyAlerts: true,
  environmentAlerts: false,
  lowSoc: 20,
  staleMinutes: 10,
  offlineMinutes: 60,
);

const _none = AlarmThresholds(
  energyAlerts: false,
  environmentAlerts: false,
  lowSoc: 20,
  staleMinutes: 10,
  offlineMinutes: 60,
);
