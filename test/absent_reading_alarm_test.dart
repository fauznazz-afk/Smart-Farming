import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';

/// Two tests for the places where an *absence* used to be manufactured into a
/// confident zero.
///
/// Both are here because the failure in each case is silent and, in the first,
/// reaches a user as a critical notification about their battery.
void main() {
  group('a payload with no readable number is not a zero', () {
    /// `soc` with a `null` payload, which is the shape that matters: the key is
    /// present in a 200 response, so it is not a missing reading in the sense the
    /// alarm engine already understood.
    DeviceTelemetry nullSoc() => DeviceTelemetry.fromJson({
          'soc': [
            {'ts': 1758900000000, 'value': null},
          ],
        });

    test('the key is left out of the map entirely', () {
      final telemetry = nullSoc();
      expect(
        telemetry.latestValues.containsKey('soc'),
        isFalse,
        reason: 'a present-but-null key used to be stored as 0.0, which is '
            'indistinguishable from a real reading of zero',
      );
    });

    test('it raises no low-charge alarm', () {
      // **This is the part that reached the user.** `evaluateAlarmRules` reads
      // `if (value == null) continue;`, so with the key absent the low-SOC rule
      // never compares anything. With the key present as 0.0 it did compare, and
      // 0.0 is below any threshold a user would set -- so a null payload produced
      // `Battery charge low: 0%` at **critical** severity, persisted to the alarm
      // history and posted as a notification.
      const thresholds = AlarmThresholds(
        energyAlerts: true,
        environmentAlerts: false,
        lowSoc: 20,
        staleMinutes: 10,
        offlineMinutes: 60,
      );

      final telemetry = nullSoc();
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(thresholds),
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: telemetry.latestValues,
            lastUpdate: telemetry.lastUpdate,
          ),
        ],
        now: DateTime.fromMillisecondsSinceEpoch(1758900000000),
      );

      expect(
        signals.where((s) => s.id == 'low_soc'),
        isEmpty,
        reason: 'a null payload is missing data, not an empty battery',
      );
    });

    test('but a real zero still alarms', () {
      // The other half, and the reason this is not simply "null and zero are the
      // same": the key must be *absent*, not zero-valued. A pack genuinely at 0%
      // is the single most urgent thing this app can tell its user, and a fix that
      // conflated the two would have silenced it.
      final telemetry = DeviceTelemetry.fromJson({
        'soc': [
          {'ts': 1758900000000, 'value': '0'},
        ],
      });
      expect(telemetry.latestValues['soc'], 0.0);

      const thresholds = AlarmThresholds(
        energyAlerts: true,
        environmentAlerts: false,
        lowSoc: 20,
        staleMinutes: 10,
        offlineMinutes: 60,
      );
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(thresholds),
        readings: [
          AlarmReading(
            device: AlarmDevice.battery,
            values: telemetry.latestValues,
            lastUpdate: telemetry.lastUpdate,
          ),
        ],
        now: DateTime.fromMillisecondsSinceEpoch(1758900000000),
      );
      expect(signals.map((s) => s.id), contains('low_soc'));
    });

    test('lastUpdate still advances, because the device did answer', () {
      // The distinction that keeps "stale" and "no value" separate. The BMS
      // replied; it just did not report a number. Advancing the timestamp only for
      // parseable keys would instead report a talking device as silent.
      //
      // Asserted against the payload's own timestamp rather than through
      // `ageLabel`, which compares against the wall clock -- and a fixed fixture
      // timestamp is 370 days old by the time this runs.
      final telemetry = nullSoc();
      expect(telemetry.lastUpdate, isNotNull);
      expect(
        telemetry.lastUpdate!.millisecondsSinceEpoch,
        1758900000000,
        reason: 'a null value must not stop the device looking alive',
      );
    });

    test('a boolean payload is also not a number', () {
      // `turbidity_keruh` is a boolean on the fish device. `thingsboard_api.dart`
      // documents this hazard and avoids it by never requesting that key, which
      // protects one key while leaving the fallback in place for the rest. This
      // pins the general case.
      final telemetry = DeviceTelemetry.fromJson({
        'turbidity_keruh': [
          {'ts': 1758900000000, 'value': true},
        ],
      });
      expect(telemetry.latestValues.containsKey('turbidity_keruh'), isFalse);
    });

    test('a cache written by an older build cannot reintroduce the zero', () {
      // `fromCacheJson` used to fabricate the same 0.0 on the way *back in*, so a
      // cache from a build before the fix could resurrect exactly the value
      // `fromJson` now refuses to create.
      final telemetry = DeviceTelemetry.fromCacheJson({
        'latestValues': {'soc': null, 'voltage': '230.4', 'current': 'garbage'},
        'lastUpdate': '2026-09-30T10:00:00.000',
      });
      expect(telemetry.latestValues.containsKey('soc'), isFalse);
      expect(telemetry.latestValues.containsKey('current'), isFalse);
      expect(telemetry.latestValues['voltage'], 230.4);
    });
  });

  group('alarm rules still treat an absent reading as absent', () {
    test('a device that never reported raises nothing at all', () {
      // The documented rule, kept here so the change above cannot have quietly
      // altered it: `alarm_rules.dart` states that a device which produced no
      // reading is neither stale nor a fault.
      const thresholds = AlarmThresholds(
        energyAlerts: true,
        environmentAlerts: false,
        lowSoc: 20,
        staleMinutes: 10,
        offlineMinutes: 60,
      );
      final signals = evaluateAlarmRules(
        rules: buildAlarmRules(thresholds),
        readings: const [],
        now: DateTime.fromMillisecondsSinceEpoch(1758900000000),
      );
      expect(signals, isEmpty);
    });
  });
}