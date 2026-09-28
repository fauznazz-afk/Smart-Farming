import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/services/energy_report_service.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';

/// A fake [ThingsBoardApi] that returns canned history data.
///
/// The real class hits the network, which is not what a unit test should do.
/// This overrides only the method [EnergyReportService] calls.
class _FakeThingsBoardApi extends ThingsBoardApi {
  _FakeThingsBoardApi(this._response);

  final Map<String, List<TelemetryPoint>> _response;
  int callCount = 0;

  @override
  Future<Map<String, List<TelemetryPoint>>> fetchHistoryForKeys(
    String deviceId,
    List<String> keys, {
    required DateTime start,
    required DateTime end,
    int intervalMs = 300000,
    int limit = 2000,
  }) async {
    callCount++;
    return _response;
  }
}

void main() {
  group('EnergyReportService.load', () {
    test('returns hourly buckets for a daily period', () async {
      final start = DateTime(2026, 1, 1, 0);
      final api = _FakeThingsBoardApi({
        'power_dc': [
          TelemetryPoint(timestamp: start, value: 1000),
          TelemetryPoint(timestamp: DateTime(2026, 1, 1, 1), value: 2000),
          TelemetryPoint(timestamp: DateTime(2026, 1, 1, 2), value: 3000),
        ],
        'power_ac': [
          TelemetryPoint(timestamp: start, value: 500),
          TelemetryPoint(timestamp: DateTime(2026, 1, 1, 1), value: 1000),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      expect(data.buckets, isNotEmpty);
      expect(data.sampleCount, greaterThan(0));
      expect(data.firstSample, isNotNull);
      expect(data.lastSample, isNotNull);
      expect(data.pvKwh, greaterThan(0));
      expect(data.acKwh, greaterThan(0));
    });

    test('returns hourly buckets for a monthly period', () async {
      final start = DateTime(2026, 1, 1);
      final api = _FakeThingsBoardApi({
        'power_dc': [
          for (var day = 0; day < 30; day++)
            TelemetryPoint(
              timestamp: start.add(Duration(days: day)),
              value: 5000,
            ),
        ],
        'power_ac': [
          for (var day = 0; day < 30; day++)
            TelemetryPoint(
              timestamp: start.add(Duration(days: day)),
              value: 2500,
            ),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      expect(data.buckets, isNotEmpty);
      expect(data.sampleCount, greaterThan(0));
      expect(data.pvKwh, greaterThan(0));
      expect(data.acKwh, greaterThan(0));
    });

    test('throws when no data is returned', () async {
      final api = _FakeThingsBoardApi({});
      final service = EnergyReportService(api);

      expect(
        () => service.load(referenceDate: DateTime(2026, 1, 1)),
        throwsException,
      );
    });

    test('handles partial data (only DC, no AC)', () async {
      final start = DateTime(2026, 1, 1);
      final api = _FakeThingsBoardApi({
        'power_dc': [
          TelemetryPoint(timestamp: start, value: 1000),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 1)), value: 2000),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      expect(data.buckets, isNotEmpty);
      expect(data.pvKwh, greaterThan(0));
      expect(data.acKwh, 0);
    });

    test('handles partial data (only AC, no DC)', () async {
      final start = DateTime(2026, 1, 1);
      final api = _FakeThingsBoardApi({
        'power_ac': [
          TelemetryPoint(timestamp: start, value: 500),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 1)), value: 1000),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      expect(data.buckets, isNotEmpty);
      expect(data.pvKwh, 0);
      expect(data.acKwh, greaterThan(0));
    });

    test('clamps negative values to zero', () async {
      final start = DateTime(2026, 1, 1);
      final api = _FakeThingsBoardApi({
        'power_dc': [
          TelemetryPoint(timestamp: start, value: -1000),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 1)), value: 2000),
        ],
        'power_ac': [
          TelemetryPoint(timestamp: start, value: 500),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      expect(data.pvKwh, greaterThanOrEqualTo(0));
    });

    test('sorts buckets by hour', () async {
      final start = DateTime(2026, 1, 1);
      final api = _FakeThingsBoardApi({
        'power_dc': [
          TelemetryPoint(timestamp: start.add(const Duration(hours: 5)), value: 1000),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 2)), value: 2000),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 8)), value: 3000),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      for (var i = 1; i < data.buckets.length; i++) {
        expect(
          data.buckets[i].hour.isAfter(data.buckets[i - 1].hour),
          isTrue,
          reason: 'Buckets should be sorted by hour',
        );
      }
    });

    test('returns correct sample count', () async {
      final start = DateTime(2026, 1, 1);
      final api = _FakeThingsBoardApi({
        'power_dc': [
          TelemetryPoint(timestamp: start, value: 1000),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 1)), value: 2000),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 2)), value: 3000),
        ],
        'power_ac': [
          TelemetryPoint(timestamp: start, value: 500),
          TelemetryPoint(timestamp: start.add(const Duration(hours: 1)), value: 1000),
        ],
      });

      final service = EnergyReportService(api);
      final data = await service.load(referenceDate: start);

      expect(data.sampleCount, 15);
    });
  });

  group('EnergyReportData', () {
    test('computes total PV and AC kWh from buckets', () {
      final data = EnergyReportData(
        buckets: [
          EnergyBucket(
            hour: DateTime(2026, 1, 1, 0),
            pvKwh: 1.5,
            acKwh: 0.5,
            sampleCount: 2,
          ),
          EnergyBucket(
            hour: DateTime(2026, 1, 1, 1),
            pvKwh: 2.5,
            acKwh: 1.0,
            sampleCount: 3,
          ),
        ],
        firstSample: DateTime(2026, 1, 1, 0),
        lastSample: DateTime(2026, 1, 1, 1),
        sampleCount: 5,
      );

      expect(data.pvKwh, 4.0);
      expect(data.acKwh, 1.5);
    });
  });
}
