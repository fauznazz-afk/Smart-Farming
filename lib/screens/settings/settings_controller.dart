import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/settings_keys.dart';
import '../../services/alarm_settings.dart';
import '../../services/cctv_url.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme_controller.dart';
import '../../utils/alarm_rules.dart';
import 'utils/settings_validation.dart';

/// Owns every user-configurable setting: text controllers, plain values,
/// validation, and persistence.
///
/// Extracted from `SettingsScreen` so the UI only has to bind controls and the
/// storage contract lives in one place.
class SettingsController extends ChangeNotifier {
  SettingsController({required this.themeController});

  final AppThemeController themeController;

  // ── Text-backed values ──────────────────────────────────────────────────────
  final cctvUrl = TextEditingController(text: defaultAllowedCctvUrl);
  final dailyTarget = TextEditingController();
  final weatherApiKey = TextEditingController();
  final weatherCity = TextEditingController();

  /// Environment alert limits, in display order.
  final List<EnvRangeSetting> envRanges = [
    EnvRangeSetting(
      id: 'temp',
      label: 'Ambient temperature',
      unit: '°C',
      minKey: SettingsKeys.environmentTempMin,
      maxKey: SettingsKeys.environmentTempMax,
      minAllowed: -40,
      maxAllowed: 100,
      defaultMin: AlarmThresholds.defaultTempMin,
      defaultMax: AlarmThresholds.defaultTempMax,
    ),
    EnvRangeSetting(
      id: 'humidity',
      label: 'Humidity',
      unit: '%',
      minKey: SettingsKeys.environmentHumidityMin,
      maxKey: SettingsKeys.environmentHumidityMax,
      minAllowed: 0,
      maxAllowed: 100,
      defaultMin: AlarmThresholds.defaultHumidityMin,
      defaultMax: AlarmThresholds.defaultHumidityMax,
    ),
    // Lower bound only: nutrient solutions run 800-2000 ppm and sea water is
    // ~35000 ppm, so any upper cap low enough to be safe would block real
    // readings.
    EnvRangeSetting(
      id: 'tds',
      label: 'Water TDS',
      unit: 'ppm',
      minKey: SettingsKeys.environmentTdsMin,
      maxKey: SettingsKeys.environmentTdsMax,
      minAllowed: 0,
      defaultMin: AlarmThresholds.defaultTdsMin,
    ),
  ];

  // ── Plain values ────────────────────────────────────────────────────────────
  bool autoRefresh = true;
  int refreshSeconds = 10;
  bool energyAlerts = true;
  bool envAlerts = true;
  int lowSoc = AlarmThresholds.defaultLowSoc;
  int staleMinutes = AlarmThresholds.defaultStaleMinutes;
  int offlineMinutes = AlarmThresholds.defaultOfflineMinutes;
  Color selectedSeed = AppThemeController.defaultSeed;

  // ── Transient status ────────────────────────────────────────────────────────
  bool saving = false;
  String? weatherError;
  String? weatherLocationName;
  double? weatherLatitude;
  double? weatherLongitude;
  bool weatherLoading = false;
  String? appVersion;

  // ── Loading ─────────────────────────────────────────────────────────────────
  /// Applies a mutation to plain settings and notifies listeners, so widgets can
  /// bind directly to controller fields without owning their own state.
  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final savedCctvUrl = await loadCctvUrl();
    autoRefresh = p.getBool(SettingsKeys.autoRefresh) ?? true;
    refreshSeconds = p.getInt(SettingsKeys.refreshSeconds) ?? 10;
    // One reader for the alert defaults. This used to repeat the same five
    // lookups and fallbacks that readAlarmThresholds does, which is how a
    // setting ended up defaulting one way for the settings screen and another
    // way for the dashboard.
    final thresholds = readAlarmThresholds(p);
    energyAlerts = thresholds.energyAlerts;
    envAlerts = thresholds.environmentAlerts;
    lowSoc = thresholds.lowSoc.round();
    staleMinutes = thresholds.staleMinutes;
    offlineMinutes = thresholds.offlineMinutes;
    dailyTarget.text = p.getString(SettingsKeys.dailyProductionTargetKwh) ?? '';
    weatherApiKey.text = p.getString(SettingsKeys.weatherApiKey) ?? '';
    weatherLocationName = p.getString(SettingsKeys.weatherLocationName);
    weatherCity.text = weatherLocationName ?? '';
    weatherLatitude = p.getDouble(SettingsKeys.weatherLocationLat);
    weatherLongitude = p.getDouble(SettingsKeys.weatherLocationLon);
    cctvUrl.text = savedCctvUrl;
    for (final range in envRanges) {
      range.min.text = p.getString(range.minKey!) ?? range.min.text;
      range.max.text = p.getString(range.maxKey!) ?? range.max.text;
    }
    selectedSeed = themeController.seedColor;
    notifyListeners();
  }

  Future<void> loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    appVersion = '${info.version}+${info.buildNumber}';
    notifyListeners();
  }

  // ── Validation ──────────────────────────────────────────────────────────────
  /// Returns the first validation error, or null when the form is valid.
  String? validate() {
    for (final (range, label) in [
      (envRanges[0], 'suhu'),
      (envRanges[1], 'kelembapan'),
      (envRanges[2], 'TDS'),
    ]) {
      final error = validateEnvRange(range, errorLabel: label);
      if (error != null) return error;
    }
    final targetError = validateDailyTargetError(dailyTarget.text);
    if (targetError != null) return targetError;
    final alertsError = validateEnvironmentAlertsEnabled(
      enabled: envAlerts,
      ranges: envRanges,
    );
    if (alertsError != null) return alertsError;
    if (parseAllowedCctvUrl(cctvUrl.text) == null) {
      return 'CCTV URL harus HTTPS dan memakai host resmi';
    }
    return null;
  }

  // ── Saving ──────────────────────────────────────────────────────────────────
  /// Persists every setting. Returns an error message on failure, or null when
  /// the settings were written successfully.
  Future<String?> save() async {
    if (saving) return null;
    final error = validate();
    if (error != null) return error;

    saving = true;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(SettingsKeys.autoRefresh, autoRefresh);
      await p.setInt(SettingsKeys.refreshSeconds, refreshSeconds);
      await p.setBool(SettingsKeys.energyAlertsEnabled, energyAlerts);
      await p.setBool(SettingsKeys.environmentAlertsEnabled, envAlerts);
      await p.setInt(SettingsKeys.lowSocThreshold, lowSoc);
      await p.setInt(SettingsKeys.staleTelemetryMinutes, staleMinutes);
    await p.setInt(SettingsKeys.offlineTelemetryMinutes, offlineMinutes);
      await p.setString(SettingsKeys.weatherApiKey, weatherApiKey.text.trim());
      await p.setString(
        SettingsKeys.weatherLocationName,
        weatherCity.text.trim(),
      );
      await _saveDailyTarget(p);
      for (final range in envRanges) {
        await _saveIfNotEmpty(p, range.minKey!, range.min.text);
        await _saveIfNotEmpty(p, range.maxKey!, range.max.text);
      }
      // The dashboard reads the stream URL from secure storage, not prefs.
      await saveCctvUrl(cctvUrl.text.trim());
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _saveDailyTarget(SharedPreferences p) async {
    final text = dailyTarget.text.trim();
    if (text.isEmpty) {
      await p.remove(SettingsKeys.dailyProductionTargetKwh);
    } else {
      await p.setString(SettingsKeys.dailyProductionTargetKwh, text);
    }
  }

  Future<void> _saveIfNotEmpty(
    SharedPreferences p,
    String key,
    String raw,
  ) async {
    final value = raw.trim();
    if (value.isEmpty) {
      await p.remove(key);
    } else {
      await p.setString(key, value);
    }
  }

  // ── Weather ─────────────────────────────────────────────────────────────────
  /// Fetches weather once to verify the API key and location, then caches the
  /// resolved coordinates so the dashboard can reuse them.
  Future<void> testWeatherConnection() async {
    weatherLoading = true;
    weatherError = null;
    notifyListeners();

    final service = WeatherService();
    await service.initialize();
    await service.setApiKey(weatherApiKey.text.trim());
    final city = weatherCity.text.trim();

    try {
      final weather = city.isEmpty
          ? await service.getCurrentWeather()
          : await service.getWeatherByCity(city);
      if (weather == null) {
        weatherError =
            'Failed to fetch weather data. Check your API key and location.';
      } else {
        weatherLocationName = weather.locationName;
        weatherLatitude = weather.latitude;
        weatherLongitude = weather.longitude;
        weatherCity.text = weather.locationName;
      }
    } catch (error) {
      weatherError = _cleanError(error.toString());
    } finally {
      weatherLoading = false;
      notifyListeners();
    }
  }

  static String _cleanError(String message) => message.startsWith('Exception: ')
      ? message.substring('Exception: '.length)
      : message;

  @override
  void dispose() {
    cctvUrl.dispose();
    dailyTarget.dispose();
    weatherApiKey.dispose();
    weatherCity.dispose();
    for (final range in envRanges) {
      range.dispose();
    }
    super.dispose();
  }
}
