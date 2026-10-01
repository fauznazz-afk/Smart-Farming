import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry_model.dart';

enum _TokenRefreshResult { refreshed, rejected, unavailable }

class _NonRetryableTelemetryException implements Exception {
  const _NonRetryableTelemetryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ThingsBoardApi {
  static const _requestTimeout = Duration(seconds: 15);
  // Ganti sesuai domain lo
  static const String baseUrl = 'https://dashboard.mbkm20262027.tech';

  // Device ID (UUID) — bukan token
  static const String deviceBattery = '9465cf90-b264-11f1-9294-d92385142e6d';
  static const String deviceSensor = '2e1b25c0-af33-11f1-8455-0717167ff6c3';
  static const String devicePzem = 'af9531a0-ac44-11f1-841c-f5914d050259';
  static const String deviceFish = '1c433980-ba25-11f1-b893-9dd5b4b6bde1';

  // Kunci telemetry per device. Sengaja declared di sini dan dipakai bersama oleh
  // polling REST (fetchBatteryData dan friends) dan langganan WebSocket di
  // ThingsBoardRealtimeService.
  //
  // Sebelumnya kedua sisi menulis ulang literalnya masing-masing. Kalau satu
  // ditambah dan yang lain tidak, metriknya tetap masuk lewat polling tapi
  // tidak pernah live-update, dan tidak ada error maupun crash yang menandakan
  // itu. Satu sumber, jadi mustahil lepas.
  static const List<String> batteryKeys = [
    'current',
    'power',
    'soc',
    'voltage',
    'cycles',
    'remain_capacity_ah',
    'full_capacity_ah',
  ];
  static const List<String> pzemKeys = [
    'voltage_ac',
    'voltage_dc',
    'current_ac',
    'current_dc',
    'power_ac',
    'power_dc',
    'energy_ac',
    'energy_dc',
    'frequency_ac',
    'pf_ac',
  ];
  static const List<String> sensorKeys = [
    'humidity_dht',
    'lux',
    'tds_ppm',
    'temp_dht',
    'temp_ds18b20',
  ];

  // Device ikan publishes a sixth key, `turbidity_keruh`, which is a BOOLEAN
  // ("true" when the water is turbid), not a number. It is deliberately absent
  // here. TelemetryPoint.fromJson parses with
  // `double.tryParse(value.toString()) ?? 0.0`, so requesting it would not
  // throw — it would store 0.0, and the card would show a confident `0` that is
  // indistinguishable from a real zero reading while meaning the opposite. The
  // numeric `turbidity_ntu` carries the same fact with a scale, so the boolean
  // adds a wrong value rather than information. Supporting it properly means
  // widening Map<String, double> to Map<String, dynamic> across the cache, the
  // offline split, the chart and the Kotlin alarm parser.
  //
  // `turbidity_voltage` is also absent: it is the sensor's own supply rail
  // (3.3 V), useful for bench diagnosis and noise on a water-quality page.
  static const List<String> fishKeys = [
    // Listed first on purpose: AlarmNotificationService._freshnessKeyFor takes
    // `fishKeys.first` as the key that proves the device is still reporting, so
    // it has to be a key the device always publishes.
    'ph',
    // The one Indonesian key name in the app, because that is what the device
    // publishes. The label shown to the user is still English. Do not
    // "correct" it to `suhu_air` or similar.
    'suhu',
    'turbidity_ntu',
    'water_level_percent',
  ];

  /// Every device the app reads, paired with the keys it publishes.
  ///
  /// This is the canonical list, and it exists because three places used to be
  /// hand-written lists that had to be extended in step: the REST shortcuts, the
  /// WebSocket subscriptions, and the offline cache split. Adding a device to
  /// the constants above but forgetting the split produced the worst kind of
  /// bug — the page polled live, showed correct numbers, and then came up empty
  /// from the offline fallback with nothing in any log. Tests derive from this
  /// map so a fifth device cannot silently drop out of coverage either.
  ///
  /// Note it is keyed by device id, so a duplicated UUID would silently collapse
  /// two devices into one entry here. `thingsboard_api_test.dart` pins the
  /// distinctness separately for that reason.
  static const Map<String, List<String>> deviceKeysById = {
    deviceBattery: batteryKeys,
    devicePzem: pzemKeys,
    deviceSensor: sensorKeys,
    deviceFish: fishKeys,
  };

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _token;
  String? _refreshToken;
  Future<_TokenRefreshResult>? _refreshInFlight;
  // Invalidates a refresh that completes after an explicit logout.
  int _sessionVersion = 0;

  /// Login pakai customer user, simpan token ke secure storage.
  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      if (token is! String || token.isEmpty) return false;
      _sessionVersion++;
      _token = token;
      final refreshToken = data['refreshToken'];
      _refreshToken = refreshToken is String && refreshToken.isNotEmpty
          ? refreshToken
          : null;

      await _secureStorage.write(key: 'tb_token', value: _token);
      if (_refreshToken != null) {
        await _secureStorage.write(
          key: 'tb_refresh_token',
          value: _refreshToken,
        );
      } else {
        await _secureStorage.delete(key: 'tb_refresh_token');
      }
      await _removeLegacyCredentials();

      return true;
    }
    return false; // login gagal (username/password salah)
  }

  /// Load the saved session without discarding it when the network is offline.
  ///
  /// Secure storage can throw, and it does throw in practice: the encryption
  /// key lives in the Android keystore, so an unreadable entry surfaces as a
  /// cipher failure rather than a null. That used to be fatal. loadSavedToken
  /// had no error handling, _SplashRouterState awaited it before deciding which
  /// screen to show, and the app therefore sat on the splash forever with no
  /// error and no way forward short of reinstalling.
  ///
  /// A read failure is treated as "no session", so the user lands on Login and
  /// can sign in again. Legacy SharedPreferences copies are only purged once
  /// secure storage has actually been read, so a transient failure cannot
  /// destroy the last recoverable token.
  Future<bool> loadSavedToken() async {
    final preferences = await SharedPreferences.getInstance();

    String? secureToken;
    String? secureRefreshToken;
    var secureStorageReadable = false;
    try {
      secureToken = await _secureStorage.read(key: 'tb_token');
      secureRefreshToken = await _secureStorage.read(
        key: 'tb_refresh_token',
      );
      secureStorageReadable = true;
    } catch (e) {
      debugPrint('ThingsBoardApi: secure storage unreadable ($e)');
    }

    final legacyToken = preferences.getString('tb_token');
    final legacyRefresh = preferences.getString('tb_refresh_token');

    _token = secureToken ?? legacyToken;
    _refreshToken = secureRefreshToken ?? legacyRefresh;

    if (secureStorageReadable) {
      if (_token != null && secureToken == null) {
        await _secureStorage.write(key: 'tb_token', value: _token);
      }
      if (_refreshToken != null && secureRefreshToken == null) {
        await _secureStorage.write(
          key: 'tb_refresh_token',
          value: _refreshToken,
        );
      }
      // Only now is it safe to drop the plaintext copies.
      await _removeLegacyCredentials(preferences);
    }

    return _token != null && _token!.isNotEmpty;
  }

  Future<void> logout() async {
    _sessionVersion++;
    // A storage failure must not leave the in-memory session alive, so the
    // local state is cleared first and the deletes are best effort after it.
    _token = null;
    _refreshToken = null;
    try {
      await _secureStorage.delete(key: 'tb_token');
      await _secureStorage.delete(key: 'tb_refresh_token');
    } catch (e) {
      debugPrint('ThingsBoardApi: could not clear secure storage ($e)');
    }
    await _removeLegacyCredentials();
    await clearUserCache();
    await clearCachedTelemetry();
  }

  /// Fetches and caches the display name for the logged-in user.
  Future<String> fetchDisplayName() async {
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString('user_display_name');
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final response = await _getWithTokenRefresh(
        Uri.parse('$baseUrl/api/auth/user'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final firstName = data['firstName'] as String? ?? '';
        final email = data['email'] as String? ?? '';
        final name = firstName.isNotEmpty
            ? firstName
            : (email.contains('@') ? email.split('@').first : email);
        final displayName = name.isNotEmpty ? name : 'User';
        await preferences.setString('user_display_name', displayName);
        return displayName;
      }
    } catch (_) {}
    return 'User';
  }

  /// Clears cached user display name.
  Future<void> clearUserCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('user_display_name');
  }

  Future<void> _removeLegacyCredentials([
    SharedPreferences? preferences,
  ]) async {
    final legacyPreferences =
        preferences ?? await SharedPreferences.getInstance();
    await legacyPreferences.remove('tb_token');
    await legacyPreferences.remove('tb_refresh_token');
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  String? get accessToken => _token;

  /// The refresh token, exposed so the background alarm module can be given a
  /// way to renew its own access token.
  ///
  /// The native check polls independently of the app, so without one its copy
  /// would expire mid-session and background alarms would stop arriving with no
  /// way to tell that from a network problem.
  String? get refreshToken => _refreshToken;

  Uri get telemetryWebSocketUri {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '${base.path}/api/ws/plugins/telemetry',
      // ThingsBoard requires the JWT in this WebSocket query parameter.
      // Avoid emitting token= for an unauthenticated connection attempt.
      queryParameters: _token == null || _token!.isEmpty
          ? null
          : {'token': _token!},
    );
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'X-Authorization': 'Bearer $_token',
  };

  Future<http.Response> _getWithTokenRefresh(Uri url, {DateTime? deadline}) async {
    final timeout = _timeoutFor(deadline);
    final response = await http
        .get(url, headers: _authHeaders)
        .timeout(timeout);
    if (response.statusCode != 401) return response;

    final refreshResult = await _refreshAccessToken();
    if (refreshResult == _TokenRefreshResult.unavailable) {
      throw Exception(
        'The saved session could not be refreshed by the server. '
        'Check the connection and try again.',
      );
    }
    if (refreshResult == _TokenRefreshResult.rejected) return response;

    return http.get(url, headers: _authHeaders).timeout(_timeoutFor(deadline));
  }

  /// Compute the timeout for a request, capped by the remaining budget.
  ///
  /// When [deadline] is null, the default [_requestTimeout] is used. When a
  /// deadline is provided, the timeout is the remaining time until that deadline,
  /// but never more than [_requestTimeout]. If the deadline has already passed,
  /// a minimal timeout is returned so the request fails fast rather than hanging.
  Duration _timeoutFor(DateTime? deadline) {
    if (deadline == null) return _requestTimeout;
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) return const Duration(milliseconds: 1);
    return remaining < _requestTimeout ? remaining : _requestTimeout;
  }

  Future<_TokenRefreshResult> _refreshAccessToken() async {
    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _performTokenRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  Future<_TokenRefreshResult> _performTokenRefresh() async {
    final refreshToken = _refreshToken;
    final sessionVersion = _sessionVersion;
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      return _TokenRefreshResult.rejected;
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      return _TokenRefreshResult.unavailable;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await logout();
      return _TokenRefreshResult.rejected;
    }
    if (response.statusCode != 200) return _TokenRefreshResult.unavailable;

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'];
      if (token is! String || token.isEmpty) {
        return _TokenRefreshResult.unavailable;
      }
      // Do not resurrect a session after logout while this request was in
      // flight.
      if (sessionVersion != _sessionVersion || refreshToken != _refreshToken) {
        return _TokenRefreshResult.rejected;
      }
      final nextRefreshToken = data['refreshToken'];
      final refreshedToken =
          nextRefreshToken is String && nextRefreshToken.isNotEmpty
          ? nextRefreshToken
          : refreshToken;
      await _secureStorage.write(key: 'tb_token', value: token);
      await _secureStorage.write(
        key: 'tb_refresh_token',
        value: refreshedToken,
      );
      _token = token;
      _refreshToken = refreshedToken;
      return _TokenRefreshResult.refreshed;
    } catch (_) {
      return _TokenRefreshResult.unavailable;
    }
  }

  /// Fetch nilai telemetry terkini (latest value) untuk satu device.
  ///
  /// Retries with exponential backoff (1s, 2s, 4s) on network/5xx errors.
  /// Does NOT retry on 401 (auth errors).
  ///
  /// This no longer writes the offline cache. It used to, per device, and four
  /// devices fetching inside one `Future.wait` meant four concurrent
  /// read-modify-write cycles against the same `cached_telemetry` key: each read
  /// the same snapshot and each wrote only its own device, so the last writer won
  /// and the other three buckets were lost. Measured at 32-77 ms each on the test
  /// device, all of it inside the poll's critical path. The cache is now written
  /// once per tick by [cacheTelemetrySnapshot] with the merged result.
  Future<DeviceTelemetry> fetchLatestTelemetry(
    String deviceId,
    List<String> keys, {
    DateTime? deadline,
  }) async {
    final keysParam = keys.join(',');
    final url = Uri.parse(
      '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries?keys=$keysParam',
    );

    return _fetchWithRetry(url, deadline: deadline);
  }

  /// Merge one snapshot per device and write the offline cache exactly once.
  ///
  /// Takes the whole tick's readings rather than a single device's, which is the
  /// point: one read, one merge, one write, no interleaving. The caller owns the
  /// loop, so a device that failed simply contributes nothing instead of
  /// overwriting the others with its own stale view.
  Future<void> cacheTelemetrySnapshot(
    Map<String, DeviceTelemetry> byDevice,
  ) async {
    final mergedValues = <String, double>{};
    DateTime? latest;
    for (final telemetry in byDevice.values) {
      mergedValues.addAll(telemetry.latestValues);
      final at = telemetry.lastUpdate;
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    if (mergedValues.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      // **Merged with what is already cached, and this was not doing that.**
      //
      // Two callers write here with different reach. The dashboard's poll has all
      // four devices every tick. The WebSocket service passes only the devices it
      // has actually seen on the socket -- which, for a BMS that reports first and
      // quietly, is often one device for a long while.
      //
      // Replacing the cache meant a single socket frame from one device overwrote
      // the four-device snapshot the poll had just written, so `cached_telemetry`
      // lost `voltage_ac`, `ph`, `turbidity_ntu` and the rest. If the network then
      // dropped, `_applyOfflineFallback` -> `splitCachedTelemetry` produced empty
      // maps for every device the socket had not heard from, and those pages came
      // up blank until a successful poll healed them.
      //
      // The trade is that a key removed server-side lingers in the cache until a
      // poll that no longer reports it overwrites the whole set... which it never
      // does, since the poll writes everything it saw. So the trade is real but
      // small: a stale key can outlive its device in the offline cache. Losing a
      // device outright, on every single socket frame, is a much worse failure and
      // is the one that was happening.
      final previous = _readCachedValues(preferences);
      // The snapshot being written wins per key; the cache only supplies keys it
      // has and this call does not. **The direction matters and the test for it
      // caught this being written backwards first:** `mergedValues.addAll(previous)`
      // let a stale reading in the cache overwrite a live one from the socket,
      // which is the same class of bug as the overwrite this whole change exists
      // to fix, just slower.
      final union = <String, double>{...previous, ...mergedValues};
      await preferences.setString(
        'cached_telemetry',
        jsonEncode(
          DeviceTelemetry(
            latestValues: union,
            lastUpdate: latest,
          ).toJson(),
        ),
      );
      await preferences.setString(
        'cached_telemetry_time',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Best-effort: a failed cache must never fail a successful fetch.
    }
  }

  /// The values already in the offline cache, or empty if there are none.
  ///
  /// Best-effort in the same way the write is: a cache that cannot be read is a
  /// cache that will be replaced wholesale, which is the old behaviour and is not
  /// a failure worth propagating into a successful fetch.
  Map<String, double> _readCachedValues(SharedPreferences preferences) {
    try {
      final raw = preferences.getString('cached_telemetry');
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final values = decoded['latestValues'];
      if (values is! Map) return {};
      return {
        for (final entry in values.entries)
          if (entry.value is num)
            entry.key.toString(): (entry.value as num).toDouble(),
        };
    } catch (_) {
      return {};
    }
  }

  /// Wraps an HTTP GET with exponential-backoff retry.
  ///
  /// - Attempt 1: immediate
  /// - Attempt 2: delay 1s
  /// - Attempt 3: delay 2s
  /// - Attempt 4: delay 4s
  ///
  /// Retries only on network errors and 5xx responses. 401 is NOT retried
  /// (it's an auth error — caller handles it). After all attempts fail,
  /// the last error is rethrown.
  Future<DeviceTelemetry> _fetchWithRetry(Uri url, {DateTime? deadline}) async {
    const maxRetries = 3; // 4 total attempts (initial + 3 retries)
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];

    Object? lastError;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(delays[attempt - 1]);
      }
      try {
        final response = await _getWithTokenRefresh(url, deadline: deadline);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return DeviceTelemetry.fromJson(json);
        } else if (response.statusCode == 401) {
          throw const _NonRetryableTelemetryException(
            'Token expired, please sign in again',
          );
        } else if (response.statusCode >= 500) {
          // Retry on 5xx
          lastError = Exception(
            'Telemetry fetch failed: ${response.statusCode}',
          );
          continue;
        } else {
          // Non-retryable HTTP error (e.g. 403, 404)
          throw _NonRetryableTelemetryException(
            'Telemetry fetch failed: ${response.statusCode}',
          );
        }
      } on Exception catch (e) {
        if (e is _NonRetryableTelemetryException) {
          rethrow;
        }
        // Network error, timeout, or 5xx — retry
        lastError = e;
        continue;
      }
    }

    throw lastError ?? Exception('Telemetry fetch failed after retrying');
  }


  /// Load the last cached telemetry snapshot from SharedPreferences.
  /// Returns `null` if no cache exists.
  Future<DeviceTelemetry?> loadCachedTelemetry() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final jsonStr = preferences.getString('cached_telemetry');
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DeviceTelemetry.fromCacheJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Returns the timestamp when the cache was last written, or `null`.
  Future<DateTime?> getCachedTelemetryTime() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final timeStr = preferences.getString('cached_telemetry_time');
      if (timeStr == null || timeStr.isEmpty) return null;
      return DateTime.tryParse(timeStr);
    } catch (_) {
      return null;
    }
  }

  /// Clear the cached telemetry (called on logout).
  Future<void> clearCachedTelemetry() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('cached_telemetry');
      await preferences.remove('cached_telemetry_time');
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  /// Fetch several telemetry series in one request (useful for chart screens).
  Future<Map<String, List<TelemetryPoint>>> fetchHistoryForKeys(
    String deviceId,
    List<String> keys, {
    required DateTime start,
    required DateTime end,
    int intervalMs = 300000,
    int limit = 2000,
  }) async {
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final url =
        Uri.parse(
          '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries',
        ).replace(
          queryParameters: {
            'keys': keys.join(','),
            'startTs': '$startTs',
            'endTs': '$endTs',
            'interval': '$intervalMs',
            'agg': 'AVG',
            'limit': '$limit',
          },
        );

    final response = await _getWithTokenRefresh(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        for (final key in keys)
          key: (json[key] as List<dynamic>? ?? [])
              .map((e) => TelemetryPoint.fromJson(e as Map<String, dynamic>))
              .toList(),
      };
    } else if (response.statusCode == 401) {
      throw Exception('Token expired, please sign in again');
    } else {
      throw Exception(
        'History fetch failed: ${response.statusCode}',
      );
    }
  }

  // ── Shortcut methods per device, sesuai key yang udah dikonfirmasi ──

  Future<DeviceTelemetry> fetchBatteryData() {
    return fetchLatestTelemetry(deviceBattery, batteryKeys);
  }

  Future<DeviceTelemetry> fetchPzemData() {
    return fetchLatestTelemetry(devicePzem, pzemKeys);
  }

  Future<DeviceTelemetry> fetchSensorData() {
    return fetchLatestTelemetry(deviceSensor, sensorKeys);
  }

  Future<DeviceTelemetry> fetchFishData() {
    return fetchLatestTelemetry(deviceFish, fishKeys);
  }
}
