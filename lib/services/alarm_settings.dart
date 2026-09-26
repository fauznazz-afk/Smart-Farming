import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_keys.dart';
import '../utils/alarm_rules.dart';

/// Resolves the alarm thresholds out of `SharedPreferences`.
///
/// This exists so the dashboard, the background sync and the settings defaults
/// cannot disagree. The fallback values were previously written out in three
/// places, which is how `energy_alerts_enabled` ended up defaulting to `true`
/// in one reader and `false` in another.
///
/// A pure function of the preferences handle, so the dashboard can call it
/// inside its existing `setState` without a second await.
AlarmThresholds readAlarmThresholds(SharedPreferences preferences) {
  return AlarmThresholds(
    energyAlerts: preferences.getBool(SettingsKeys.energyAlertsEnabled) ?? true,
    environmentAlerts:
        preferences.getBool(SettingsKeys.environmentAlertsEnabled) ?? false,
    lowSoc: (preferences.getInt(SettingsKeys.lowSocThreshold) ?? 20).toDouble(),
    staleMinutes: preferences.getInt(SettingsKeys.staleTelemetryMinutes) ?? 10,
    tempMin: _readLimit(preferences, SettingsKeys.environmentTempMin),
    tempMax: _readLimit(preferences, SettingsKeys.environmentTempMax),
    humidityMin: _readLimit(preferences, SettingsKeys.environmentHumidityMin),
    humidityMax: _readLimit(preferences, SettingsKeys.environmentHumidityMax),
    tdsMin: _readLimit(preferences, SettingsKeys.environmentTdsMin),
    tdsMax: _readLimit(preferences, SettingsKeys.environmentTdsMax),
  );
}

/// Environment limits are stored as text, so a decimal can be typed freely.
///
/// A blank or unparseable value is treated as absent, which is what Settings
/// means by leaving a field empty: that limit is not monitored.
double? _readLimit(SharedPreferences preferences, String key) =>
    double.tryParse(preferences.getString(key)?.trim() ?? '');
