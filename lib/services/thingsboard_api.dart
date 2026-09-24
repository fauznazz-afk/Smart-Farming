import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telemetry_model.dart';

enum _TokenRefreshResult { refreshed, rejected, unavailable }

class ThingsBoardApi {
  static const _requestTimeout = Duration(seconds: 15);
  // Ganti sesuai domain lo
  static const String baseUrl = 'https://dashboard.mbkm20262027.tech';

  // Device ID (UUID) — bukan token
  static const String deviceBattery = '9465cf90-b264-11f1-9294-d92385142e6d';
  static const String deviceSensor = '2e1b25c0-af33-11f1-8455-0717167ff6c3';
  static const String devicePzem = 'af9531a0-ac44-11f1-841c-f5914d050259';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _token;
  String? _refreshToken;
  Future<_TokenRefreshResult>? _refreshInFlight;

  /// Login pakai customer user, simpan token ke secure storage.
  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      if (token is! String || token.isEmpty) return false;
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
  Future<bool> loadSavedToken() async {
    final preferences = await SharedPreferences.getInstance();
    final secureToken = await _secureStorage.read(key: 'tb_token');
    final secureRefreshToken =
        await _secureStorage.read(key: 'tb_refresh_token');
    _token = secureToken ?? preferences.getString('tb_token');
    _refreshToken =
        secureRefreshToken ?? preferences.getString('tb_refresh_token');
    if (_token != null &&
        secureToken == null) {
      await _secureStorage.write(key: 'tb_token', value: _token);
    }
    if (_refreshToken != null && secureRefreshToken == null) {
      await _secureStorage.write(
        key: 'tb_refresh_token',
        value: _refreshToken,
      );
    }
    await _removeLegacyCredentials(preferences);
    return _token != null && _token!.isNotEmpty;
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'tb_token');
    await _secureStorage.delete(key: 'tb_refresh_token');
    await _removeLegacyCredentials();
    await clearUserCache();
    _token = null;
    _refreshToken = null;
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

  bool get isLoggedIn => _token != null;

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
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      return _TokenRefreshResult.rejected;
    }

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/api/auth/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(_requestTimeout);
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
      final nextRefreshToken = data['refreshToken'];
      final refreshedToken = nextRefreshToken is String &&
              nextRefreshToken.isNotEmpty
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

  /// Fetch nilai telemetry terkini (latest value) untuk satu device
  Future<DeviceTelemetry> fetchLatestTelemetry(
    String deviceId,
    List<String> keys,
  ) async {
    final keysParam = keys.join(',');
    final url = Uri.parse(
      '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries?keys=$keysParam',
    );

    final response = await _getWithTokenRefresh(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DeviceTelemetry.fromJson(json);
    } else if (response.statusCode == 401) {
      throw Exception('Token expired, silakan login ulang');
    } else {
      throw Exception('Gagal fetch telemetry: ${response.statusCode}');
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

    final url = Uri.parse(
      '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries',
    ).replace(queryParameters: {
      'keys': keys.join(','),
      'startTs': '$startTs',
      'endTs': '$endTs',
      'interval': '$intervalMs',
      'agg': 'AVG',
      'limit': '$limit',
    });

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
      final detail = response.body.trim();
      final message = detail.length > 400 ? '${detail.substring(0, 400)}…' : detail;
      throw Exception(
        'Gagal fetch history: ${response.statusCode}'
        '${message.isEmpty ? '' : ' — $message'}',
      );
    }
  }

  // ── Shortcut methods per device, sesuai key yang udah dikonfirmasi ──

  Future<DeviceTelemetry> fetchBatteryData() {
    return fetchLatestTelemetry(deviceBattery, [
      'current',
      'power',
      'soc',
      'voltage',
      'cycles',
      'remain_capacity_ah',
      'full_capacity_ah',
    ]);
  }

  Future<DeviceTelemetry> fetchPzemData() {
    return fetchLatestTelemetry(devicePzem, [
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
    ]);
  }

  Future<DeviceTelemetry> fetchSensorData() {
    return fetchLatestTelemetry(deviceSensor, [
      'humidity_dht',
      'lux',
      'tds_ppm',
      'temp_dht',
      'temp_ds18b20',
    ]);
  }
}
