/// Shared `SharedPreferences` keys for user-configurable app settings.
///
/// These strings are the contract between the Settings screen (writes) and the
/// Dashboard / alarm services (reads), so they are declared in one place to
/// prevent the two sides from drifting apart.
abstract final class SettingsKeys {
  // Monitoring
  static const autoRefresh = 'auto_refresh';
  static const refreshSeconds = 'refresh_seconds';

  // Alerts
  static const energyAlertsEnabled = 'energy_alerts_enabled';
  static const environmentAlertsEnabled = 'environment_alerts_enabled';
  static const lowSocThreshold = 'low_soc_threshold';
  static const staleTelemetryMinutes = 'stale_telemetry_minutes';
  static const offlineTelemetryMinutes = 'offline_telemetry_minutes';
  static const dailyProductionTargetKwh = 'daily_production_target_kwh';

  // Environment alert limits
  static const environmentTempMin = 'environment_temp_min';
  static const environmentTempMax = 'environment_temp_max';
  static const environmentHumidityMin = 'environment_humidity_min';
  static const environmentHumidityMax = 'environment_humidity_max';
  static const environmentTdsMin = 'environment_tds_min';
  static const environmentTdsMax = 'environment_tds_max';

  // Fish tank alert limits
  static const fishAlertsEnabled = 'fish_alerts_enabled';
  static const fishPhMin = 'fish_ph_min';
  static const fishPhMax = 'fish_ph_max';
  static const fishTempMin = 'fish_temp_min';
  static const fishTempMax = 'fish_temp_max';
  static const fishTurbidityMax = 'fish_turbidity_max';
}
