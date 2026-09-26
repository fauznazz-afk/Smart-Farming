import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';
import 'package:plts_monitoring/services/thingsboard_realtime_service.dart';

class _FakeApi extends ThingsBoardApi {
  _FakeApi({this.token});

  final String? token;

  @override
  String? get accessToken => token;

  @override
  Uri get telemetryWebSocketUri {
    final base = Uri.parse('https://example.com');
    return base.replace(
      scheme: 'wss',
      path: '${base.path}/api/ws/plugins/telemetry',
      queryParameters: token == null ? null : {'token': token!},
    );
  }
}

void main() {
  group('ThingsBoardRealtimeService', () {
    test('isConnected is false before start', () {
      final api = _FakeApi();
      final service = ThingsBoardRealtimeService(
        api: api,
        onTelemetry: (_, _) {},
      );
      expect(service.isConnected, isFalse);
    });

    test('does not connect without a token', () async {
      final api = _FakeApi(token: null);
      var connectionChanges = 0;
      final service = ThingsBoardRealtimeService(
        api: api,
        onTelemetry: (_, _) {},
        onConnectionChanged: (_) => connectionChanges++,
      );

      await service.start();

      expect(service.isConnected, isFalse);
      expect(connectionChanges, 0);

      await service.stop();
    });

    test('does not connect with an empty token', () async {
      final api = _FakeApi(token: '');
      var connectionChanges = 0;
      final service = ThingsBoardRealtimeService(
        api: api,
        onTelemetry: (_, _) {},
        onConnectionChanged: (_) => connectionChanges++,
      );

      await service.start();

      expect(service.isConnected, isFalse);
      expect(connectionChanges, 0);

      await service.stop();
    });

    test('start is idempotent', () async {
      final api = _FakeApi(token: null);
      final service = ThingsBoardRealtimeService(
        api: api,
        onTelemetry: (_, _) {},
      );

      await service.start();
      await service.start();

      expect(service.isConnected, isFalse);

      await service.stop();
    });

    test('stop without start is safe', () async {
      final api = _FakeApi(token: 'some-token');
      final service = ThingsBoardRealtimeService(
        api: api,
        onTelemetry: (_, _) {},
      );

      await service.stop();
      expect(service.isConnected, isFalse);
    });
  });

  group('ThingsBoardApi device configuration', () {
    test('device IDs are distinct UUIDs', () {
      expect(ThingsBoardApi.deviceBattery, isNot(equals(ThingsBoardApi.devicePzem)));
      expect(ThingsBoardApi.deviceBattery, isNot(equals(ThingsBoardApi.deviceSensor)));
      expect(ThingsBoardApi.devicePzem, isNot(equals(ThingsBoardApi.deviceSensor)));
    });

    test('battery keys are non-empty and unique', () {
      expect(ThingsBoardApi.batteryKeys, isNotEmpty);
      expect(ThingsBoardApi.batteryKeys.length,
          equals(ThingsBoardApi.batteryKeys.toSet().length));
    });

    test('pzem keys are non-empty and unique', () {
      expect(ThingsBoardApi.pzemKeys, isNotEmpty);
      expect(ThingsBoardApi.pzemKeys.length,
          equals(ThingsBoardApi.pzemKeys.toSet().length));
    });

    test('sensor keys are non-empty and unique', () {
      expect(ThingsBoardApi.sensorKeys, isNotEmpty);
      expect(ThingsBoardApi.sensorKeys.length,
          equals(ThingsBoardApi.sensorKeys.toSet().length));
    });

    test('no key overlap between devices', () {
      final batterySet = ThingsBoardApi.batteryKeys.toSet();
      final pzemSet = ThingsBoardApi.pzemKeys.toSet();
      final sensorSet = ThingsBoardApi.sensorKeys.toSet();

      expect(batterySet.intersection(pzemSet), isEmpty);
      expect(batterySet.intersection(sensorSet), isEmpty);
      expect(pzemSet.intersection(sensorSet), isEmpty);
    });
  });

  group('TelemetryPoint', () {
    test('fromJson parses ThingsBoard timeseries format', () {
      final json = {
        'ts': 1700000000000,
        'value': '12.5',
      };
      final point = TelemetryPoint.fromJson(json);
      expect(point.timestamp, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(point.value, 12.5);
    });

    test('fromJson handles non-numeric value', () {
      final json = {
        'ts': 1700000000000,
        'value': 'invalid',
      };
      final point = TelemetryPoint.fromJson(json);
      expect(point.value, 0.0);
    });

    test('toJson round-trips', () {
      final point = TelemetryPoint(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        value: 42.0,
      );
      final json = point.toJson();
      expect(json['ts'], 1700000000000);
      expect(json['value'], '42.0');

      final restored = TelemetryPoint.fromJson(json);
      expect(restored.timestamp, point.timestamp);
      expect(restored.value, point.value);
    });
  });

  group('DeviceTelemetry', () {
    test('fromJson parses latest values correctly', () {
      final json = {
        'power': [
          {'ts': 1700000000000, 'value': '100.0'}
        ],
        'soc': [
          {'ts': 1700000000000, 'value': '75.0'}
        ],
      };
      final data = DeviceTelemetry.fromJson(json);
      expect(data.latestValues['power'], 100.0);
      expect(data.latestValues['soc'], 75.0);
      expect(data.lastUpdate, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('fromJson handles empty lists', () {
      final json = {
        'power': <Map<String, dynamic>>[],
      };
      final data = DeviceTelemetry.fromJson(json);
      expect(data.latestValues, isEmpty);
      expect(data.lastUpdate, isNull);
    });

    test('isStale returns true when last update is old', () {
      final old = DateTime.now().subtract(const Duration(minutes: 30));
      final data = DeviceTelemetry(
        latestValues: {'power': 100.0},
        lastUpdate: old,
      );
      expect(data.isStale(minutes: 10), isTrue);
    });

    test('isStale returns false when last update is recent', () {
      final recent = DateTime.now().subtract(const Duration(minutes: 2));
      final data = DeviceTelemetry(
        latestValues: {'power': 100.0},
        lastUpdate: recent,
      );
      expect(data.isStale(minutes: 10), isFalse);
    });

    test('isStale returns true when lastUpdate is null', () {
      final data = DeviceTelemetry(latestValues: {'power': 100.0});
      expect(data.isStale(minutes: 10), isTrue);
    });

    test('ageLabel describes recent updates', () {
      final recent = DateTime.now().subtract(const Duration(minutes: 2));
      final data = DeviceTelemetry(
        latestValues: {},
        lastUpdate: recent,
      );
      expect(data.ageLabel, contains('2 min ago'));
    });

    test('ageLabel describes old updates', () {
      final old = DateTime.now().subtract(const Duration(hours: 3));
      final data = DeviceTelemetry(
        latestValues: {},
        lastUpdate: old,
      );
      expect(data.ageLabel, contains('3 hr ago'));
    });

    test('toJson and fromCacheJson round-trip', () {
      final original = DeviceTelemetry(
        latestValues: {'power': 100.0, 'soc': 75.0},
        lastUpdate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final json = original.toJson();
      final restored = DeviceTelemetry.fromCacheJson(json);
      expect(restored.latestValues, original.latestValues);
      expect(restored.lastUpdate, original.lastUpdate);
    });
  });
}
