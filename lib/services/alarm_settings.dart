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
        preferences.getBool(SettingsKeys.environmentAlertsEnabled) ?? true,
    lowSoc: (preferences.getInt(SettingsKeys.lowSocThreshold) ??
            AlarmThresholds.defaultLowSoc)
        .toDouble(),
    staleMinutes: preferences.getInt(SettingsKeys.staleTelemetryMinutes) ??
        AlarmThresholds.defaultStaleMinutes,
    offlineMinutes: preferences.getInt(SettingsKeys.offlineTelemetryMinutes) ??
        AlarmThresholds.defaultOfflineMinutes,
    tempMin: _readLimit(
      preferences,
      SettingsKeys.environmentTempMin,
      AlarmThresholds.defaultTempMin,
    ),
    tempMax: _readLimit(
      preferences,
      SettingsKeys.environmentTempMax,
      AlarmThresholds.defaultTempMax,
    ),
    humidityMin: _readLimit(
      preferences,
      SettingsKeys.environmentHumidityMin,
      AlarmThresholds.defaultHumidityMin,
    ),
    humidityMax: _readLimit(
      preferences,
      SettingsKeys.environmentHumidityMax,
      AlarmThresholds.defaultHumidityMax,
    ),
    tdsMin: _readLimit(
      preferences,
      SettingsKeys.environmentTdsMin,
      AlarmThresholds.defaultTdsMin,
    ),
    // Never defaulted, and never given an upper bound. See
    // AlarmThresholds.defaultTdsMin for why.
    tdsMax: _readLimit(preferences, SettingsKeys.environmentTdsMax, null),
  );
}

/// Reads an environment limit, which is stored as text so a decimal can be
/// typed freely.
///
/// A blank or unparseable value falls back to [fallback]. A `null` fallback
/// means the limit is not monitored, which is what Settings means by leaving a
/// field empty.
double? _readLimit(
  SharedPreferences preferences,
  String key,
  double? fallback,
) {
  final raw = preferences.getString(key)?.trim();
  if (raw == null || raw.isEmpty) return fallback;
  return double.tryParse(raw) ?? fallback;
}
