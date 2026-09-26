import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/dashboard/utils/energy_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/history_range.dart';
import 'package:plts_monitoring/screens/dashboard/utils/telemetry_helpers.dart';

void main() {
  group('historyKeysForPrefix', () {
    test('maps pv/ac/battery to their telemetry keys', () {
      expect(historyKeysForPrefix('pv').voltage, 'voltage_dc');
      expect(historyKeysForPrefix('pv').power, 'power_dc');
      expect(historyKeysForPrefix('ac').voltage, 'voltage_ac');
      expect(historyKeysForPrefix('ac').power, 'power_ac');
      expect(historyKeysForPrefix('battery').voltage, 'voltage');
      expect(historyKeysForPrefix('battery').power, 'power');
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

  group('splitCachedTelemetry', () {
    test('partitions a flat cache map per device', () {
      final split = splitCachedTelemetry({
        'soc': 80,
        'voltage': 48.1,
        'power_ac': 210,
        'temp_dht': 27.5,
        'unknown_key': 1,
      });
      expect(split.battery, {'soc': 80, 'voltage': 48.1});
      expect(split.pzem, {'power_ac': 210});
      expect(split.sensor, {'temp_dht': 27.5});
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
      expect(describeCacheAge(null), 'beberapa waktu lalu');
      expect(describeCacheAge(DateTime.now()), 'baru saja');
      expect(
        describeCacheAge(DateTime.now().subtract(const Duration(minutes: 5))),
        '5 menit lalu',
      );
      expect(
        describeCacheAge(DateTime.now().subtract(const Duration(hours: 3))),
        '3 jam lalu',
      );
      expect(
        describeCacheAge(DateTime.now().subtract(const Duration(days: 2))),
        '2 hari lalu',
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
