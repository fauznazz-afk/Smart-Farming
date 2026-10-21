import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_specs.dart';
import 'package:plts_monitoring/utils/ai_provider.dart';

/// The keys the meter and the BMS publish, read off a live device on
/// 17 October 2026.
///
/// **Written out here rather than derived, because there is nothing to derive
/// them from** — they arrive as whatever the device's firmware sends and nothing
/// in the app declares them. The pair that *is* declared, `kEnvironmentSpecs` and
/// `kFishSpecs`, is checked against the table by the test below instead.
const _batteryKeys = <String, double>{
  'soc': 49,
  'power': 82.73,
  'voltage': 13.30,
  'current': 6.22,
  'cycles': 13,
  'full_capacity_ah': 100,
  'remain_capacity_ah': 48.77,
};

const _meterKeys = <String, double>{
  'power_dc': 272.50,
  'power_ac': 23.70,
  'current_ac': 0.14,
  'current_dc': 16.29,
  'energy_ac': 11.32,
  'energy_dc': 0.63,
  'frequency_ac': 50,
  'pf_ac': 0.77,
  'voltage_ac': 222.50,
  'voltage_dc': 16.73,
};

void main() {
  group('buildTelemetrySummary units', () {
    /// **The keys here are the ones a device sends, not tidy short names.**
    /// This test originally used `temp`, `humidity`, `tds`, `turbidity`, `energy`,
    /// `frequency` and `pf` — none of which any device in this system publishes —
    /// so it passed while every real reading reached the model bare. A unit test
    /// written from a plausible vocabulary instead of the observed one is worse
    /// than no test, because it reads as coverage.
    test('prints a unit for every key the BMS publishes', () {
      final s = buildTelemetrySummary(devices: {'battery': _batteryKeys});
      expect(s, contains('soc=49 %'));
      expect(s, contains('power=82.73 W'));
      expect(s, contains('voltage=13.30 V'));
      expect(s, contains('current=6.22 A'));
      expect(s, contains('cycles=13'));
      expect(s, contains('full_capacity_ah=100 Ah'));
      expect(s, contains('remain_capacity_ah=48.77 Ah'));
    });

    test('prints a unit for every key the meter publishes', () {
      final s = buildTelemetrySummary(devices: {'meter': _meterKeys});
      expect(s, contains('power_dc=272.50 W'));
      expect(s, contains('power_ac=23.70 W'));
      expect(s, contains('current_ac=0.14 A'));
      expect(s, contains('current_dc=16.29 A'));
      expect(s, contains('energy_ac=11.32 kWh'));
      expect(s, contains('energy_dc=0.63 kWh'));
      expect(s, contains('frequency_ac=50 Hz'));
      // `pf_ac` is a power factor, which is a ratio: dimensionless by definition,
      // so the bare number is correct and inventing a unit here would be wrong.
      expect(s, contains('pf_ac=0.77'));
      expect(s, contains('voltage_ac=222.50 V'));
      expect(s, contains('voltage_dc=16.73 V'));
    });

    /// The one guard that would have caught the bare-numbers bug: every key the
    /// app itself declares has a unit, cross-checked against the app's own table
    /// rather than a second hand-written list of the same names.
    test('every key the app declares is known to the unit table', () {
      for (final spec in [...kEnvironmentSpecs, ...kFishSpecs]) {
        final line = buildTelemetrySummary(
          devices: {
            'sensor': {spec.key: 1},
          },
        );
        // `spec.unit` is what the app prints beside the reading on screen. The
        // summary has to agree with it: two tables for one fact is how `suhu`
        // ended up with no unit while the grid beside it said °C.
        expect(
          line,
          contains(
            spec.unit.isEmpty ? '${spec.key}=1' : '${spec.key}=1 ${spec.unit}',
          ),
          reason:
              'the AI summary and the ${spec.label} grid disagree on the unit '
              'for ${spec.key}',
        );
      }
    });
  });

  group('buildTelemetrySummaryWithHistory new behavior', () {
    test(
      'has as of, sign convention note not required but summary has as of',
      () {
        final s = buildTelemetrySummaryWithHistory(
          devices: const {},
          history: const {},
        );
        expect(s, contains('as of '));
        // A local, second-resolution stamp. `toIso8601String()` printed
        // `...T10:56:18.554791`, six digits of sub-second noise that mean
        // nothing on a ten-second poll.
        expect(s, isNot(contains('.5')));
        expect(
          s,
          matches(RegExp(r'as of \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')),
        );
      },
    );

    test('no key silently dropped; cap shown', () {
      final map = <String, double>{};
      for (var i = 0; i < 15; i++) {
        map['k$i'] = i.toDouble();
      }
      final s = buildTelemetrySummaryWithHistory(
        devices: {'dev': map},
        history: const {},
      );
      expect(s, contains('+'));
    });

    test('active alarms empty says so', () {
      final s = buildTelemetrySummaryWithHistory(
        devices: const {},
        history: const {},
        activeAlarms: [],
      );
      expect(s, contains('active alarms: no active alarms'));
    });

    test('day with no data reported as no data', () {
      final s = buildTelemetrySummaryWithHistory(
        devices: const {},
        history: const {},
      );
      expect(s, contains('no data'));
    });
  });
}
