import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telemetry_model.dart';

class ThingsBoardApi {
  // Ganti sesuai domain lo
  static const String baseUrl = 'https://dashboard.mbkm20262027.tech';

  // Device ID (UUID) — bukan token
  static const String deviceBattery = '9465cf90-b264-11f1-9294-d92385142e6d';
  static const String deviceSensor = '2e1b25c0-af33-11f1-8455-0717167ff6c3';
  static const String devicePzem = 'af9531a0-ac44-11f1-841c-f5914d050259';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _token;

  /// Login pakai customer user, simpan token ke secure storage.
  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];

      await _secureStorage.write(key: 'tb_token', value: _token);
      final refreshToken = data['refreshToken'] as String?;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: 'tb_refresh_token',
          value: refreshToken,
        );
      }
      await _removeLegacyCredentials();

      return true;
    }
    return false; // login gagal (username/password salah)
  }

  /// Load token yang sudah tersimpan agar tidak perlu login ulang tiap buka app.
  Future<bool> loadSavedToken() async {
    final preferences = await SharedPreferences.getInstance();
    _token = await _secureStorage.read(key: 'tb_token') ??
        preferences.getString('tb_token');
    if (_token != null &&
        await _secureStorage.read(key: 'tb_token') == null) {
      await _secureStorage.write(key: 'tb_token', value: _token);
      final legacyRefreshToken = preferences.getString('tb_refresh_token');
      if (legacyRefreshToken != null && legacyRefreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: 'tb_refresh_token',
          value: legacyRefreshToken,
        );
      }
    }
    await _removeLegacyCredentials(preferences);
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/user'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) return true;
    } catch (_) {}

    await logout();
    return false;
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'tb_token');
    await _secureStorage.delete(key: 'tb_refresh_token');
    await _removeLegacyCredentials();
    await clearUserCache();
    _token = null;
  }

  /// Fetches and caches the display name for the logged-in user.
  Future<String> fetchDisplayName() async {
    final preferences = await SharedPreferences.getInstance();
    final cached = preferences.getString('user_display_name');
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/user'),
        headers: _authHeaders,
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

  /// Fetch nilai telemetry terkini (latest value) untuk satu device
  Future<DeviceTelemetry> fetchLatestTelemetry(
    String deviceId,
    List<String> keys,
  ) async {
    final keysParam = keys.join(',');
    final url = Uri.parse(
      '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries?keys=$keysParam',
    );

    final response = await http.get(url, headers: _authHeaders);

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
    final startTs = start.millisecondsSinceEpoch;
    final endTs = end.millisecondsSinceEpoch;

    final url = Uri.parse(
      '$baseUrl/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries'
      '?keys=$key&startTs=$startTs&endTs=$endTs&interval=$intervalMs&agg=AVG',
    );

    final response = await http.get(url, headers: _authHeaders);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json[key] as List<dynamic>? ?? [];
      return list
          .map((e) => TelemetryPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 401) {
      throw Exception('Token expired, silakan login ulang');
    } else {
      throw Exception('Gagal fetch history: ${response.statusCode}');
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
