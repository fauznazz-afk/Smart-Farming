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
    // All environment limits are nullable: a blank field means "no limit on
    // this side", not the default. The settings screen subtitle says "Blank
    // limits are not monitored" — this makes that true.
    tempMin: _readLimit(preferences, SettingsKeys.environmentTempMin, null),
    tempMax: _readLimit(preferences, SettingsKeys.environmentTempMax, null),
    humidityMin: _readLimit(
      preferences,
      SettingsKeys.environmentHumidityMin,
      null,
    ),
    humidityMax: _readLimit(
      preferences,
      SettingsKeys.environmentHumidityMax,
      null,
    ),
    tdsMin: _readLimit(preferences, SettingsKeys.environmentTdsMin, null),
    // Never given an upper bound. See AlarmThresholds.defaultTdsMin for why.
    tdsMax: _readLimit(preferences, SettingsKeys.environmentTdsMax, null),
    // Fish limits are nullable for the same reason the environment limits are.
    // They used to fall back to `AlarmThresholds.defaultFish*`, which meant a
    // pH field the user cleared was removed from preferences by Settings and
    // then re-armed at 6.5 on the next load — the fish section's own subtitle
    // promises "Blank limits are not monitored", so the alarm fired for a limit
    // the user had deliberately taken away. A missing key and a cleared field
    // are the same value in storage (Settings removes the key rather than
    // writing an empty string), so both have to mean "not monitored". The
    // defaults still live in `AlarmThresholds.defaults` and in the prefilled
    // Settings fields; they arm on the first save, exactly like the
    // environment limits do.
    fishAlerts: preferences.getBool(SettingsKeys.fishAlertsEnabled) ?? true,
    fishPhMin: _readLimit(preferences, SettingsKeys.fishPhMin, null),
    fishPhMax: _readLimit(preferences, SettingsKeys.fishPhMax, null),
    fishTempMin: _readLimit(preferences, SettingsKeys.fishTempMin, null),
    fishTempMax: _readLimit(preferences, SettingsKeys.fishTempMax, null),
    fishTurbidityMax: _readLimit(
      preferences,
      SettingsKeys.fishTurbidityMax,
      null,
    ),
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
