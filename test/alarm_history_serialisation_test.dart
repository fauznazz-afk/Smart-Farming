/// Tests for the alarm-history write path.
///
/// **What this file does and does not prove, because the difference matters.**
///
/// `addAlarm` was an unserialised read-modify-write against one
/// `SharedPreferences` key, and `dashboard_screen._persistAlarm` calls it
/// `unawaited` once per newly-active signal from a single synchronous loop. Four
/// simultaneous alarms therefore ran four overlapping cycles, all reading the same
/// snapshot, and only the last `setStringList` survived.
///
/// Nothing about that was visible: no exception, no log line, and the dashboard
/// banner showed all four alarms while the history the user opened to find out
/// what had happened showed one. It is the same shape as a defect this repo has
/// already fixed twice.
///
/// **These tests do not reproduce that race, and they were checked for it.** With
/// the serialiser removed, the assertions below still passed. The reason is
/// mechanical: `SharedPreferences.setMockInitialValues` is an in-memory store whose
/// `getInstance()` completes immediately, so there is no I/O between the read and
/// the write of a cycle, and four overlapping cycles never actually interleave.
/// Reproducing the bug needs a store with latency, which means injecting one -- a
/// change to the service's constructor for the sake of a test.
///
/// So what is pinned here is narrower, and stated as such: four simultaneous writes
/// leave four records, and the cooldown still de-duplicates. That is worth
/// keeping -- the cooldown guard and the serialiser are adjacent code, and a change
/// to either should be visible here -- but it is **not** evidence that the race
/// cannot recur.
///
/// **The fix is justified by reading the call path, not by this file.** See the
/// note on `_writeChain` in the service. Do not read a green run of this file as
/// proof the race is fixed. `FEATURE.md` 18.0e records the same mistake elsewhere:
/// a test that passed while the bug it was written for was still present.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plts_monitoring/services/alarm_history_service.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = AlarmHistoryService();

  AlarmRecord record(String id, String message) => AlarmRecord(
        id: id,
        timestamp: DateTime(2026, 10, 1, 12),
        type: AlarmType.staleTelemetry,
        severity: AlarmSeverity.warning,
        message: message,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('simultaneous alarms are all recorded', () {
    test('four unawaited writes leave four records, not one', () async {
      // The realistic trigger is the obvious one: the MQTT socket drops, so
      // `stale_pzem`, `stale_sensor`, `stale_battery` and `stale_fish` all go
      // active in the same evaluation.
      //
      // Deliberately not awaited, because that is what the caller does.
      final pending = <Future<void>>[
        service.addAlarm(record('a', 'No fresh data from PZEM')),
        service.addAlarm(record('b', 'No fresh data from Sensor')),
        service.addAlarm(record('c', 'No fresh data from BMS')),
        service.addAlarm(record('d', 'No fresh data from Fish tank')),
      ];

      // `addAlarm` returns the *next* write rather than this one, so awaiting
      // everything and then settling is what drains the whole chain.
      await Future.wait(pending);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final messages = (await service.getAlarms()).map((a) => a.message).toSet();
      expect(
        messages,
        containsAll(<String>[
          'No fresh data from PZEM',
          'No fresh data from Sensor',
          'No fresh data from BMS',
          'No fresh data from Fish tank',
        ]),
        reason: 'three of four records were being discarded by whichever write '
            'landed last',
      );
    });

    test('sequential writes all land too', () async {
      await service.addAlarm(record('a', 'first'));
      await service.addAlarm(record('b', 'second'));
      await service.addAlarm(record('c', 'third'));

      expect((await service.getAlarms()).length, 3);
    });

    test('the cooldown still de-duplicates a repeated alarm', () async {
      // Serialisation must not have broken the de-duplication it was racing with:
      // same type and message inside the cooldown window is one record.
      await service.addAlarm(record('a', 'No fresh data from PZEM'));
      await service.addAlarm(record('a2', 'No fresh data from PZEM'));

      expect((await service.getAlarms()).length, 1);
    });

    test('a different message inside the cooldown is a separate record', () async {
      // The de-duplication keys on type *and* message, so this is the case that
      // shows the two guards above are not the same guard.
      await service.addAlarm(record('a', 'Humidity too high: 84.3 %'));
      await service.addAlarm(record('b', 'Temperature too high: 31.2 C'));

      expect((await service.getAlarms()).length, 2);
    });
  });
}
