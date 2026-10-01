import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';

/// The offline cache must not shrink when a narrower writer touches it.
///
/// Two writers share `cached_telemetry`, and they do not have the same reach:
///
///  * the dashboard's REST poll has all four devices, every tick;
///  * the WebSocket service passes only the devices it has actually seen on the
///    socket, which for a BMS that reports first and quietly is often one device
///    for a long while.
///
/// `cacheTelemetrySnapshot` replaced the whole cache. So a single socket frame from
/// one device erased the other three, and if the network then dropped,
/// `_applyOfflineFallback` produced empty maps for every device the socket had
/// not heard from -- so those pages came up blank until a successful poll healed
/// them.
///
/// Unlike the alarm-history race this one is a plain assertion about data shape,
/// not an interleaving, so it reproduces exactly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cacheKey = 'cached_telemetry';

  DeviceTelemetry device(Map<String, double> values) =>
      DeviceTelemetry(latestValues: values, lastUpdate: DateTime(2026, 10, 1));

  Future<Map<String, double>> cachedValues() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final values = decoded['latestValues'] as Map<String, dynamic>;
    return {
      for (final entry in values.entries)
        entry.key: (entry.value as num).toDouble(),
    };
  }

  final api = ThingsBoardApi();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('the offline cache only ever grows', () {
    test('a socket frame for one device keeps the other three', () async {
      // The poll writes all four.
      await api.cacheTelemetrySnapshot({
        'pzem': device({'voltage_ac': 231.0, 'frequency_ac': 50.0}),
        'sensor': device({'temp_dht': 26.5, 'humidity_dht': 61.0}),
        'battery': device({'soc': 88.0, 'power': -18.0}),
        'fish': device({'ph': 7.2, 'turbidity_ntu': 12.0}),
      });
      expect((await cachedValues()).length, 8);

      // Then one socket frame from one device. Before the merge this left a single
      // key in the cache and nothing else.
      await api.cacheTelemetrySnapshot({
        'battery': device({'soc': 87.0, 'power': -19.0, 'voltage': 52.1}),
      });

      final values = await cachedValues();
      expect(
        values['soc'],
        87.0,
        reason: 'the newer socket reading must win for the device it names',
      );
      expect(
        values['voltage_ac'],
        231.0,
        reason: 'the meter is not on the socket and must not be forgotten',
      );
      expect(values['frequency_ac'], 50.0);
      expect(values['temp_dht'], 26.5);
      expect(values['ph'], 7.2);
    });

    test('an empty snapshot writes nothing at all', () async {
      await api.cacheTelemetrySnapshot({
        'battery': device({'soc': 88.0}),
      });
      // The WebSocket service skips the write when a frame carries no keys, but the
      // guard here is the second line of defence and it must not flush the cache
      // either.
      await api.cacheTelemetrySnapshot({});

      expect((await cachedValues()).length, 1);
    });

    test('a poll after a socket frame still restores everything', () async {
      // The healing path, so the fix cannot have broken the case that motivated it.
      await api.cacheTelemetrySnapshot({
        'battery': device({'soc': 87.0}),
      });
      await api.cacheTelemetrySnapshot({
        'pzem': device({'voltage_ac': 230.0}),
        'sensor': device({'temp_dht': 26.0}),
        'battery': device({'soc': 88.0}),
        'fish': device({'ph': 7.1}),
      });

      final values = await cachedValues();
      expect(values['soc'], 88.0);
      expect(values['voltage_ac'], 230.0);
      expect(values['temp_dht'], 26.0);
      expect(values['ph'], 7.1);
    });

    test('an unreadable cache is replaced rather than thrown on', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: 'not json at all',
      });
      // Best-effort in both directions: a cache that cannot be read must not fail a
      // successful fetch, so the write proceeds and overwrites it.
      await api.cacheTelemetrySnapshot({
        'battery': device({'soc': 50.0}),
      });
      expect((await cachedValues())['soc'], 50.0);
    });
  });
}