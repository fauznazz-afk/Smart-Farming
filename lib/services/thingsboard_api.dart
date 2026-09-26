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

  Future<http.Response> _getWithTokenRefresh(Uri url) async {
    final response = await http
        .get(url, headers: _authHeaders)
        .timeout(_requestTimeout);
    if (response.statusCode != 401) return response;

    final refreshResult = await _refreshAccessToken();
    if (refreshResult == _TokenRefreshResult.unavailable) {
      throw Exception(
        'Sesi tersimpan, tetapi server tidak dapat memperbaruinya. '
        'Periksa koneksi lalu coba lagi.',
      );
    }
    if (refreshResult == _TokenRefreshResult.rejected) return response;

    return http.get(url, headers: _authHeaders).timeout(_requestTimeout);
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
  /// Does NOT retry on 401 (auth errors). After a successful fetch, the
  /// result is cached to SharedPreferences for offline fallback.
  Future<DeviceTelemetry> fetchLatestTelemetry(
    String deviceId,
    List<String> keys,
  ) async {
    final keysParam = keys.join(',');
    final url = Uri.parse(
      '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries?keys=$keysParam',
    );

    final telemetry = await _fetchWithRetry(url);

    // Cache the successful result for offline mode.
    await _cacheTelemetry(deviceId, telemetry);

    return telemetry;
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
  Future<DeviceTelemetry> _fetchWithRetry(Uri url) async {
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
        final response = await _getWithTokenRefresh(url);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return DeviceTelemetry.fromJson(json);
        } else if (response.statusCode == 401) {
          throw const _NonRetryableTelemetryException(
            'Token expired, silakan login ulang',
          );
        } else if (response.statusCode >= 500) {
          // Retry on 5xx
          lastError = Exception(
            'Gagal fetch telemetry: ${response.statusCode}',
          );
          continue;
        } else {
          // Non-retryable HTTP error (e.g. 403, 404)
          throw _NonRetryableTelemetryException(
            'Gagal fetch telemetry: ${response.statusCode}',
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

    throw lastError ?? Exception('Gagal fetch telemetry setelah retry');
  }

  /// Save telemetry snapshot to SharedPreferences for offline fallback.
  Future<void> _cacheTelemetry(
    String deviceId,
    DeviceTelemetry telemetry,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final existingJson = preferences.getString('cached_telemetry');
      final existing = existingJson == null || existingJson.isEmpty
          ? null
          : DeviceTelemetry.fromCacheJson(
              jsonDecode(existingJson) as Map<String, dynamic>,
            );
      final mergedValues = <String, double>{
        ...?existing?.latestValues,
        ...telemetry.latestValues,
      };
      final merged = DeviceTelemetry(
        latestValues: mergedValues,
        lastUpdate: telemetry.lastUpdate ?? existing?.lastUpdate,
      );
      await preferences.setString(
        'cached_telemetry',
        jsonEncode(merged.toJson()),
      );
      await preferences.setString(
        'cached_telemetry_time',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Caching is best-effort — don't fail the fetch if storage fails.
    }
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

  /// Fetch histori telemetry (buat chart) dalam rentang waktu tertentu
  Future<List<TelemetryPoint>> fetchHistory(
    String deviceId,
    String key, {
    required DateTime start,
    required DateTime end,
    int intervalMs = 300000, // 5 menit
  }) async {
    final histories = await fetchHistoryForKeys(
      deviceId,
      [key],
      start: start,
      end: end,
      intervalMs: intervalMs,
    );
    return histories[key] ?? <TelemetryPoint>[];
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
      throw Exception('Token expired, silakan login ulang');
    } else {
      throw Exception(
        'Gagal fetch history: ${response.statusCode}',
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
}
