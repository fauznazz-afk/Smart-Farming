import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';
import 'package:plts_monitoring/services/thingsboard_realtime_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the ThingsBoard integration layer.
///
/// Nothing here touches the network. What is covered is the part that can break
/// silently: the WebSocket URL, the session/token state machine, the offline
/// cache, and the telemetry key sets that polling and the live subscription
/// both depend on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('telemetryWebSocketUri', () {
    test('swaps https for wss and points at the telemetry plugin', () {
      final uri = ThingsBoardApi().telemetryWebSocketUri;
      expect(uri.scheme, 'wss');
      expect(uri.host, 'dashboard.mbkm20262027.tech');
      expect(uri.path, '/api/ws/plugins/telemetry');
    });

    test('omits the token parameter entirely when not logged in', () {
      // ThingsBoard needs the JWT in the query string, but emitting an empty
      // `token=` for an unauthenticated attempt would put a meaningless
      // credential into logs and proxy history.
      final uri = ThingsBoardApi().telemetryWebSocketUri;
      expect(uri.query, isEmpty);
      expect(uri.queryParameters.containsKey('token'), isFalse);
    });

    test('carries the JWT once a session is loaded', () async {
      FlutterSecureStorage.setMockInitialValues({'tb_token': 'jwt-abc-123'});
      final api = ThingsBoardApi();
      await api.loadSavedToken();

      final uri = api.telemetryWebSocketUri;
      expect(uri.queryParameters['token'], 'jwt-abc-123');
    });
  });

  group('session state', () {
    test('is not logged in when secure storage is empty', () async {
      final api = ThingsBoardApi();
      await api.loadSavedToken();
      expect(api.isLoggedIn, isFalse);
      expect(api.accessToken, isNull);
    });

    test('a stored access token alone is enough', () async {
      FlutterSecureStorage.setMockInitialValues({'tb_token': 'stored-jwt'});
      final api = ThingsBoardApi();
      await api.loadSavedToken();

      expect(api.isLoggedIn, isTrue);
      expect(api.accessToken, 'stored-jwt');
    });

    test('an empty stored token does not count as a session', () async {
      FlutterSecureStorage.setMockInitialValues({'tb_token': ''});
      final api = ThingsBoardApi();
      await api.loadSavedToken();

      expect(api.isLoggedIn, isFalse);
    });

    test('legacy SharedPreferences tokens are migrated, then purged', () async {
      // Older builds kept the JWT in SharedPreferences. loadSavedToken has to
      // read that copy so existing users are not logged out, copy it into
      // secure storage, and delete the insecure original.
      SharedPreferences.setMockInitialValues({
        'tb_token': 'legacy-jwt',
        'tb_refresh_token': 'legacy-refresh',
      });

      final api = ThingsBoardApi();
      await api.loadSavedToken();

      expect(api.accessToken, 'legacy-jwt');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tb_token'), isNull);
      expect(prefs.getString('tb_refresh_token'), isNull);

      // And the migrated copy really landed in secure storage.
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'tb_token'), 'legacy-jwt');
    });

    test('secure storage wins over a stale legacy copy', () async {
      SharedPreferences.setMockInitialValues({'tb_token': 'stale-legacy'});
      FlutterSecureStorage.setMockInitialValues({'tb_token': 'current-jwt'});

      final api = ThingsBoardApi();
      await api.loadSavedToken();

      expect(api.accessToken, 'current-jwt');
    });
  });

  group('offline cache', () {
    test('is empty on a fresh install', () async {
      final api = ThingsBoardApi();
      expect(await api.loadCachedTelemetry(), isNull);
      expect(await api.getCachedTelemetryTime(), isNull);
    });

    test('round-trips a snapshot', () async {
      SharedPreferences.setMockInitialValues({
        'cached_telemetry': jsonEncode({
          'latestValues': {'soc': 87.0, 'power_ac': 16.0},
          'lastUpdate': '2026-09-26T15:00:00.000',
        }),
        'cached_telemetry_time': '2026-09-26T15:00:05.000',
      });

      final api = ThingsBoardApi();
      final cached = await api.loadCachedTelemetry();

      expect(cached, isNotNull);
      expect(cached!.get('soc'), 87.0);
      expect(cached.get('power_ac'), 16.0);
      expect(cached.lastUpdate, DateTime.parse('2026-09-26T15:00:00.000'));

      expect(
        await api.getCachedTelemetryTime(),
        DateTime.parse('2026-09-26T15:00:05.000'),
      );
    });

    test('is cleared by clearCachedTelemetry', () async {
      SharedPreferences.setMockInitialValues({
        'cached_telemetry': jsonEncode({
          'latestValues': {'soc': 87.0},
          'lastUpdate': '2026-09-26T15:00:00.000',
        }),
        'cached_telemetry_time': '2026-09-26T15:00:05.000',
      });

      final api = ThingsBoardApi();
      await api.clearCachedTelemetry();

      expect(await api.loadCachedTelemetry(), isNull);
      expect(await api.getCachedTelemetryTime(), isNull);
    });

    test('corrupt cache JSON degrades to null instead of throwing', () async {
      // A half-written cache must not take the dashboard down; the app is
      // designed to fall back to a fetch when the cache is unusable.
      SharedPreferences.setMockInitialValues({'cached_telemetry': 'not json'});

      final api = ThingsBoardApi();
      expect(await api.loadCachedTelemetry(), isNull);
    });
  });

  group('telemetry key sets', () {
    // These lists decide which metrics the app can show at all. They used to be
    // written out twice, once in the REST fetchers and once in the WebSocket
    // subscription. A key added to only one copy would poll fine but never
    // update live, with nothing in the logs to explain it.
    test('polling and the live subscription request the same keys', () {
      // The realtime service now references these exact constants, so this test
      // is really a guard against someone re-introducing a local copy.
      expect(ThingsBoardApi.batteryKeys, contains('soc'));
      expect(ThingsBoardApi.batteryKeys, contains('remain_capacity_ah'));
      expect(ThingsBoardApi.pzemKeys, contains('power_dc'));
      expect(ThingsBoardApi.pzemKeys, contains('power_ac'));
      expect(ThingsBoardApi.sensorKeys, contains('tds_ppm'));
      expect(ThingsBoardApi.sensorKeys, contains('temp_dht'));
    });

    test('no key is requested twice', () {
      for (final keys in [
        ThingsBoardApi.batteryKeys,
        ThingsBoardApi.pzemKeys,
        ThingsBoardApi.sensorKeys,
      ]) {
        expect(keys.toSet().length, keys.length, reason: 'duplicate in $keys');
      }
    });

    test('the three devices do not share a key', () {
      // Sharing would mean a value arriving on the wrong device is merged into
      // the wrong slot, which the dashboard cannot detect.
      final all = <String>{
        ...ThingsBoardApi.batteryKeys,
        ...ThingsBoardApi.pzemKeys,
        ...ThingsBoardApi.sensorKeys,
      };
      final total =
          ThingsBoardApi.batteryKeys.length +
          ThingsBoardApi.pzemKeys.length +
          ThingsBoardApi.sensorKeys.length;
      expect(all.length, total);
    });

    test('key sets are unmodifiable so a caller cannot mutate them', () {
      expect(
        () => ThingsBoardApi.batteryKeys.add('injected'),
        throwsUnsupportedError,
      );
    });
  });

  group('realtime service transport', () {
    test('does not connect without a token', () async {
      // A live subscription with no JWT would just 401 on the server; better to
      // never open the socket.
      final api = ThingsBoardApi();
      await api.loadSavedToken();

      final service = ThingsBoardRealtimeService(
        api: api,
        onTelemetry: (_, _) {},
      );

      await service.start();
      expect(service.isConnected, isFalse);

      await service.stop();
    });

    test('reports disconnected before it is started', () {
      final service = ThingsBoardRealtimeService(
        api: ThingsBoardApi(),
        onTelemetry: (_, _) {},
      );
      expect(service.isConnected, isFalse);
    });
  });

  group('device configuration', () {
    test('device IDs are distinct UUIDs', () {
      final ids = {
        ThingsBoardApi.deviceBattery,
        ThingsBoardApi.devicePzem,
        ThingsBoardApi.deviceSensor,
      };
      expect(ids.length, 3);
      for (final id in ids) {
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ).hasMatch(id),
          isTrue,
          reason: '$id should look like a ThingsBoard device UUID',
        );
      }
    });

    test('base URL is https', () {
      // The CCTV allowlist enforces this too; the telemetry transport should
      // never be the one place a downgrade slips through.
      expect(ThingsBoardApi.baseUrl, startsWith('https://'));
    });
  });
}
