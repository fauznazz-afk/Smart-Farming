import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/dashboard/utils/energy_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/history_range.dart';
import 'package:plts_monitoring/screens/dashboard/utils/telemetry_helpers.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';

void main() {
  group('historyKeysForPrefix', () {
    // These used to be asserted through named getters on a three-field record.
    // The record is a list now, because a page's charts are no longer a fixed
    // trio -- and the reason they are a list is that greenhouse and fish
    // readings could not be charted at all while the fields were fixed.
    test('maps pv/ac/battery to their telemetry keys', () {
      expect(
        historyKeysForPrefix('pv'),
        containsAll(<String>['voltage_dc', 'current_dc', 'power_dc']),
      );
      expect(historyKeysForPrefix('ac'), contains('voltage_ac'));
      expect(historyKeysForPrefix('ac'), contains('power_ac'));
      expect(historyKeysForPrefix('battery'), contains('voltage'));
      expect(historyKeysForPrefix('battery'), contains('power'));
    });

    test('asks the greenhouse device for the keys its charts plot', () {
      final keys = historyKeysForPrefix('env');
      expect(
        keys,
        containsAll(<String>[
          'temp_dht',
          'temp_ds18b20',
          'humidity_dht',
          'lux',
          'tds_ppm',
        ]),
      );
      // Nothing extra: a key no chart plots is a request the user pays for and
      // nobody reads.
      expect(keys, hasLength(5));
    });

    test('asks the fish device for the keys its charts plot', () {
      expect(
        historyKeysForPrefix('fish'),
        containsAll(<String>['ph', 'suhu', 'turbidity_ntu']),
      );
      expect(historyKeysForPrefix('fish'), hasLength(3));
    });

    test('an unknown prefix requests nothing', () {
      expect(historyKeysForPrefix('nope'), isEmpty);
    });
  });

  group('historyDeviceForPrefix', () {
    test('routes each page to the device that actually publishes its keys', () {
      // This is the second reason the greenhouse was never chartable: everything
      // that was not the battery was sent to the PZEM meter, so a request for
      // `ph` would have gone to a device that does not publish it.
      expect(historyDeviceForPrefix('pv'), ThingsBoardApi.devicePzem);
      expect(historyDeviceForPrefix('ac'), ThingsBoardApi.devicePzem);
      expect(historyDeviceForPrefix('battery'), ThingsBoardApi.deviceBattery);
      expect(historyDeviceForPrefix('env'), ThingsBoardApi.deviceSensor);
      expect(historyDeviceForPrefix('fish'), ThingsBoardApi.deviceFish);
    });
  });

  group('historyTimeWindow', () {
    final now = DateTime(2026, 3, 10, 14, 30);

    test('uses a rolling 24h window for today', () {
      final window = historyTimeWindow(
        rangeStart: DateTime(2026, 3, 10),
        rangeEnd: null,
        now: now,
      );
      expect(window.start, now.subtract(const Duration(hours: 24)));
      expect(window.end, now);
    });

    test('covers the whole day for a past date', () {
      final window = historyTimeWindow(
        rangeStart: DateTime(2026, 3, 5),
        rangeEnd: null,
        now: now,
      );
      expect(window.start, DateTime(2026, 3, 5));
      expect(window.end, DateTime(2026, 3, 5, 23, 59, 59));
    });

    test('a custom range wins and ends at the last millisecond', () {
      final window = historyTimeWindow(
        rangeStart: DateTime(2026, 3, 1),
        rangeEnd: DateTime(2026, 3, 3),
        now: now,
      );
      expect(window.start, DateTime(2026, 3, 1));
      expect(window.end, DateTime(2026, 3, 3, 23, 59, 59, 999));
    });
  });

  group('historyIntervalFor', () {
    test('coarsens the interval as the span grows', () {
      expect(historyIntervalFor(const Duration(hours: 12)), 300000);
      expect(historyIntervalFor(const Duration(days: 3)), 1800000);
      expect(historyIntervalFor(const Duration(days: 10)), 7200000);
      expect(historyIntervalFor(const Duration(days: 60)), 21600000);
    });
  });

  group('historySelectionKey', () {
    test('changes when the range end changes', () {
      final start = DateTime(2026, 3, 1);
      expect(
        historySelectionKey(rangeStart: start),
        historySelectionKey(rangeStart: start, rangeEnd: null),
      );
      expect(
        historySelectionKey(rangeStart: start),
        isNot(historySelectionKey(rangeStart: start, rangeEnd: DateTime(2026, 3, 2))),
      );
    });
  });

  group('energyForPeriod', () {
    final points = [
      TelemetryPoint(timestamp: DateTime(2026, 3, 10, 0), value: 0),
      TelemetryPoint(timestamp: DateTime(2026, 3, 10, 1), value: 1000),
    ];
    test('integrates a linear ramp in kWh', () {
      // Average power 500 W over one hour = 0.5 kWh.
      final kwh = energyForPeriod(
        points,
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 10, 1),
      );
      expect(kwh, closeTo(0.5, 1e-9));
    });

    test('skips gaps longer than one hour', () {
      final gapped = [
        TelemetryPoint(timestamp: DateTime(2026, 3, 10, 0), value: 0),
        TelemetryPoint(timestamp: DateTime(2026, 3, 10, 3), value: 1000),
      ];
      expect(
        energyForPeriod(gapped, DateTime(2026, 3, 10), DateTime(2026, 3, 11)),
        0,
      );
    });

    test('never reports negative energy', () {
      final falling = [
        TelemetryPoint(timestamp: DateTime(2026, 3, 10, 0), value: 0),
        TelemetryPoint(timestamp: DateTime(2026, 3, 10, 1), value: -500),
      ];
      expect(
        energyForPeriod(
          falling,
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 10, 1),
        ),
        0,
      );
    });
  });

  group('energyComparison', () {
    test('splits energy into the current and preceding window', () {
      final now = DateTime(2026, 3, 10, 12);
      final history = {
        'power_dc': [
          TelemetryPoint(timestamp: DateTime(2026, 3, 10, 11), value: 0),
          TelemetryPoint(timestamp: now, value: 1000),
        ],
      };
      final result = energyComparison(
        history: history,
        key: 'power_dc',
        weekly: false,
        now: now,
      );
      // Average 500 W over the final hour.
      expect(result.current, closeTo(0.5, 1e-9));
      expect(result.previous, 0);
    });

    test('missing key yields zero on both sides', () {
      final result = energyComparison(
        history: const {},
        key: 'power_dc',
        weekly: false,
      );
      expect(result.current, 0);
      expect(result.previous, 0);
    });
  });

  group('describeHistoryRange', () {
    final now = DateTime(2026, 3, 10, 14, 30);

    test('describes a custom range', () {
      expect(
        describeHistoryRange(
          selectedDate: DateTime(2026, 3, 1),
          rangeStart: DateTime(2026, 3, 1),
          rangeEnd: DateTime(2026, 3, 5),
          now: now,
        ),
        '1/3/2026 – 5/3/2026',
      );
    });

    test('describes today as the rolling 24 hour window', () {
      expect(
        describeHistoryRange(
          selectedDate: DateTime(2026, 3, 10, 9),
          now: now,
        ),
        'Last 24 hours',
      );
    });

    test('describes a selected past day instead of the last 24 hours', () {
      expect(
        describeHistoryRange(
          selectedDate: DateTime(2026, 3, 5, 17, 45),
          now: now,
        ),
        '5/3/2026',
      );
    });

    test('a custom range wins over the selected day', () {
      expect(
        describeHistoryRange(
          selectedDate: DateTime(2026, 3, 10),
          rangeStart: DateTime(2026, 3, 2),
          rangeEnd: DateTime(2026, 3, 4),
          now: now,
        ),
        '2/3/2026 – 4/3/2026',
      );
    });

    test('ignores the time component of the selected day', () {
      final morning = describeHistoryRange(
        selectedDate: DateTime(2026, 3, 10, 0, 1),
        now: DateTime(2026, 3, 10, 0, 2),
      );
      final night = describeHistoryRange(
        selectedDate: DateTime(2026, 3, 10, 23, 59),
        now: DateTime(2026, 3, 10, 23, 59),
      );
      expect(morning, 'Last 24 hours');
      expect(night, 'Last 24 hours');
    });

    test('label agrees with the window that was actually requested', () {
      for (final day in [DateTime(2026, 3, 1), DateTime(2026, 3, 10)]) {
        final label = describeHistoryRange(selectedDate: day, now: now);
        final window = historyTimeWindow(
          rangeStart: startOfDay(day),
          rangeEnd: null,
          now: now,
        );
        final isToday = startOfDay(day) == startOfDay(now);
        expect(
          isToday ? label == 'Last 24 hours' : label != 'Last 24 hours',
          isTrue,
          reason: 'label "$label" disagrees with the fetched window',
        );
        expect(window.end.isAfter(window.start), isTrue);
      }
    });
  });

  group('splitCachedTelemetry', () {
    test('partitions a flat cache map per device', () {
      final split = splitCachedTelemetry({
        'soc': 80,
        'voltage': 48.1,
        'power_ac': 210,
        'temp_dht': 27.5,
        'ph': 6.24,
        'unknown_key': 1,
      });
      expect(split.battery, {'soc': 80, 'voltage': 48.1});
      expect(split.pzem, {'power_ac': 210});
      expect(split.sensor, {'temp_dht': 27.5});
      expect(split.fish, {'ph': 6.24});
    });

    test('a key in no device list is dropped, not guessed at', () {
      // Deliberate: the flat cache has thrown away which device each value came
      // from, so membership in the key lists is the only routing signal there is.
      final split = splitCachedTelemetry({'unknown_key': 1});
      expect(split.battery, isEmpty);
      expect(split.pzem, isEmpty);
      expect(split.sensor, isEmpty);
      expect(split.fish, isEmpty);
    });
  });

  group('sameTelemetry', () {
    test('detects value changes and length changes', () {
      final base = DeviceTelemetry(
        latestValues: {'soc': 80},
        lastUpdate: DateTime(2026, 3, 10),
      );
      expect(
        sameTelemetry(
          base,
          DeviceTelemetry(
            latestValues: {'soc': 80},
            lastUpdate: DateTime(2026, 3, 10, 1),
          ),
        ),
        isTrue,
      );
      expect(
        sameTelemetry(
          base,
          DeviceTelemetry(
            latestValues: {'soc': 79},
            lastUpdate: DateTime(2026, 3, 10),
          ),
        ),
        isFalse,
      );
      expect(
        sameTelemetry(
          base,
          DeviceTelemetry(
            latestValues: {'soc': 80, 'current': 1},
            lastUpdate: DateTime(2026, 3, 10),
          ),
        ),
        isFalse,
      );
      expect(sameTelemetry(null, base), isFalse);
    });
  });

  group('formatClock', () {
    test('zero-pads to HH:MM', () {
      expect(formatClock(DateTime(2026, 3, 10, 7, 5)), '07:05');
      expect(formatClock(DateTime(2026, 3, 10, 23, 59)), '23:59');
    });
  });

  group('describeCacheAge', () {
    test('describes recent and older cache times', () {
      expect(describeCacheAge(null), 'a while ago');
      expect(describeCacheAge(DateTime.now()), 'just now');
      expect(
        describeCacheAge(DateTime.now().subtract(const Duration(minutes: 5))),
        '5 minutes ago',
      );
      expect(
        describeCacheAge(DateTime.now().subtract(const Duration(hours: 3))),
        '3 hours ago',
      );
      expect(
        describeCacheAge(DateTime.now().subtract(const Duration(days: 2))),
        '2 days ago',
      );
    });
  });

  group('sameStrings', () {
    test('is order sensitive', () {
      expect(sameStrings(['a', 'b'], ['a', 'b']), isTrue);
      expect(sameStrings(['a', 'b'], ['b', 'a']), isFalse);
      expect(sameStrings(['a'], ['a', 'b']), isFalse);
    });
  });
}
