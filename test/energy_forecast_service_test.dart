import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/services/energy_forecast_service.dart';

void main() {
  test(
    'forecast keeps the full sample range without a combined history sort',
    () {
      final start = DateTime(2026, 1, 1, 8);
      final result = const EnergyForecastService().calculate(
        referenceDate: DateTime(2026, 1, 1),
        history: {
          'power_dc': [
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 9), value: 1000),
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 8), value: 1000),
          ],
          'power_ac': [
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 10), value: 200),
          ],
        },
      );

      expect(result.sampleStart, start);
      expect(result.sampleEnd, DateTime(2026, 1, 1, 10));
      expect(result.peakUsageWatts, 200);
      expect(result.peakUsageAt, DateTime(2026, 1, 1, 10));
    },
  );

  test('daily estimate extrapolates today actual production to 24 hours', () {
    final result = const EnergyForecastService().calculate(
      referenceDate: DateTime(2026, 1, 1, 14),
      history: {
        'power_dc': [
          TelemetryPoint(timestamp: DateTime(2026, 1, 1, 8), value: 333.33),
          TelemetryPoint(timestamp: DateTime(2026, 1, 1, 11), value: 333.33),
          TelemetryPoint(timestamp: DateTime(2026, 1, 1, 14), value: 333.33),
        ],
      },
    );

    expect(result.observedProductionKwh, closeTo(2.0, 0.01));
    expect(result.dailyProductionEstimateKwh, closeTo(8.0, 0.01));
  });

  group('estimateBatteryDischargeWatts', () {
    TelemetryPoint at(int hour, double value) =>
        TelemetryPoint(timestamp: DateTime(2026, 1, 1, hour), value: value);

    test('prefers the battery\'s own reported power', () {
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {'power': 30},
          solar: [at(12, 200)],
          usage: [at(20, 16)],
        ),
        30,
      );
    });

    test('ignores the sign convention a Bluetooth BMS uses for power', () {
      // Vendors disagree: some report power positive while discharging, others
      // positive while charging. Only the magnitude may be used.
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {'power': -30},
          solar: [at(12, 200)],
          usage: [at(20, 16)],
        ),
        30,
      );
    });

    test('falls back to voltage times current, by magnitude', () {
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {'voltage': 48, 'current': -0.625},
          solar: [at(12, 200)],
          usage: [at(20, 16)],
        ),
        closeTo(30, 1e-9),
      );
    });

    test('ignores a non-positive reported power, as when idle', () {
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {'power': 0, 'voltage': 48, 'current': 0.6},
          solar: [at(12, 200)],
          usage: [at(20, 16)],
        ),
        closeTo(28.8, 1e-9),
        reason: 'should fall through to voltage x current',
      );
    });

    test('falls back to voltage times current', () {
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {'voltage': 48, 'current': 0.625},
          solar: [at(12, 200)],
          usage: [at(20, 16)],
        ),
        closeTo(30, 1e-9),
      );
    });

    test('averages the load across dark hours, not the daily peak', () {
      // A 60 W spike at noon happened while PV was covering the load, so the
      // battery was not discharging then. Only the night samples count.
      final estimate = EnergyForecastService.estimateBatteryDischargeWatts(
        latest: const {},
        solar: [at(12, 200), at(20, 0), at(21, 0)],
        usage: [at(12, 60), at(20, 30), at(21, 20)],
      );
      expect(estimate, closeTo(25, 1e-9));
    });

    test('does not treat a cloudy dip as night', () {
      // Hour 15 dips to zero for one sample but is otherwise producing, so it
      // must stay out of the dark set and its 70 W load must be ignored.
      final estimate = EnergyForecastService.estimateBatteryDischargeWatts(
        latest: const {},
        solar: [at(15, 180), at(15, 0), at(15, 160), at(20, 0)],
        usage: [at(15, 70), at(20, 24)],
      );
      expect(estimate, closeTo(24, 1e-9));
    });

    test('falls back to the AC peak only as a last resort', () {
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {},
          solar: const [],
          usage: [at(12, 60), at(20, 30)],
        ),
        60,
      );
    });

    test('returns null when there is nothing to estimate from', () {
      expect(
        EnergyForecastService.estimateBatteryDischargeWatts(
          latest: const {},
          solar: const [],
          usage: const [],
        ),
        isNull,
      );
    });
  });

  group('battery runtime projection', () {
    test('uses the battery discharge, not the AC peak', () {
      // 30 Ah remaining at 48 V is 1.44 kWh. At 94% SOC that is 1.3536 kWh.
      // Dividing by a 30 W discharge gives ~45 h; using the 16 W AC peak would
      // have claimed ~85 h.
      final result = const EnergyForecastService().calculate(
        referenceDate: DateTime(2026, 1, 1, 21),
        history: {
          'soc': [TelemetryPoint(timestamp: DateTime(2026, 1, 1, 21), value: 94)],
          'power': [
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 21), value: 30),
          ],
          'power_ac': [
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 21), value: 16),
          ],
        },
        latest: const {
          'soc': 94,
          'power': 30,
          'voltage': 48,
          'current': 0.625,
          'remain_capacity_ah': 30,
        },
      );

      expect(result.batteryDepletionHours, closeTo(45.1, 0.5));
      expect(result.peakUsageWatts, 16, reason: 'peak usage is a separate stat');
    });

    test('gives no estimate when the battery draw is unknown', () {
      final result = const EnergyForecastService().calculate(
        referenceDate: DateTime(2026, 1, 1, 21),
        history: {
          'soc': [TelemetryPoint(timestamp: DateTime(2026, 1, 1, 21), value: 94)],
        },
        latest: const {
          'soc': 94,
          'voltage': 48,
          'remain_capacity_ah': 30,
        },
      );

      expect(result.batteryDepletionHours, isNull);
    });
  });
}
