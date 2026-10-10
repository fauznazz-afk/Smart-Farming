import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/settings_keys.dart';
import '../../services/alarm_settings.dart';
import '../../services/cctv_url.dart';
import '../../utils/alarm_rules.dart';
import 'utils/settings_validation.dart';

/// Owns every user-configurable setting: text controllers, plain values,
/// validation, and persistence.
///
/// Extracted from `SettingsScreen` so the UI only has to bind controls and the
/// storage contract lives in one place.
class SettingsController extends ChangeNotifier {
  SettingsController();

  // ── Text-backed values ──────────────────────────────────────────────────────
  final cctvUrl = TextEditingController(text: defaultAllowedCctvUrl);
  final fishCctvUrl = TextEditingController(text: defaultAllowedFishCctvUrl);
  final dailyTarget = TextEditingController();

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

  /// Fish tank alert limits, in display order.
  final List<EnvRangeSetting> fishRanges = [
    EnvRangeSetting(
      id: 'ph',
      label: 'pH',
      unit: '',
      minKey: SettingsKeys.fishPhMin,
      maxKey: SettingsKeys.fishPhMax,
      minAllowed: 0,
      maxAllowed: 14,
      defaultMin: AlarmThresholds.defaultFishPhMin,
      defaultMax: AlarmThresholds.defaultFishPhMax,
    ),
    EnvRangeSetting(
      id: 'water_temp',
      label: 'Water temperature',
      unit: '°C',
      minKey: SettingsKeys.fishTempMin,
      maxKey: SettingsKeys.fishTempMax,
      minAllowed: 0,
      maxAllowed: 50,
      defaultMin: AlarmThresholds.defaultFishTempMin,
      defaultMax: AlarmThresholds.defaultFishTempMax,
    ),
    // Upper bound only: turbidity has no meaningful lower limit, so `minKey` is
    // null and the lower `minAllowed: 0` only exists to reject a negative
    // reading, which cannot be real.
    //
    // No upper cap, for the same reason TDS has none: the sensor on the test
    // device reads 2396 NTU and later 2993.5, so a cap low enough to look safe
    // is crossed by every real reading and the turbidity alert becomes
    // impossible to configure against reality. 1000 NTU was such a cap.
    //
    // And no default either, so the field starts empty rather than prefilled.
    // See the comment on `AlarmThresholds.defaultFishTurbidityMax` for why there
    // is no number that could honestly be one. An empty field plus the section's
    // own "Blank limits are not monitored" is honest; a prefill of 100 NTU is
    // an alarm waiting to fire forever.
    EnvRangeSetting(
      id: 'turbidity',
      label: 'Turbidity',
      unit: 'NTU',
      minKey: null,
      maxKey: SettingsKeys.fishTurbidityMax,
      minAllowed: 0,
      defaultMax: AlarmThresholds.defaultFishTurbidityMax,
    ),
  ];

  // ── Plain values ────────────────────────────────────────────────────────────
  bool autoRefresh = true;
  int refreshSeconds = 10;
  bool energyAlerts = true;
  bool envAlerts = true;
  bool fishAlerts = true;
  int lowSoc = AlarmThresholds.defaultLowSoc;
  int staleMinutes = AlarmThresholds.defaultStaleMinutes;
  int offlineMinutes = AlarmThresholds.defaultOfflineMinutes;

  // ── Transient status ────────────────────────────────────────────────────────
  bool saving = false;
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
    final savedFishCctvUrl = await loadFishCctvUrl();
    // Every one of the writes below touches a TextEditingController this class
    // owns and disposes, so continuing after dispose is a use-after-dispose on
    // all of them at once. See [_abandoned].
    if (_abandoned) return;
    autoRefresh = p.getBool(SettingsKeys.autoRefresh) ?? true;
    refreshSeconds = p.getInt(SettingsKeys.refreshSeconds) ?? 10;
    // One reader for the alert defaults. This used to repeat the same five
    // lookups and fallbacks that readAlarmThresholds does, which is how a
    // setting ended up defaulting one way for the settings screen and another
    // way for the dashboard.
    final thresholds = readAlarmThresholds(p);
    energyAlerts = thresholds.energyAlerts;
    envAlerts = thresholds.environmentAlerts;
    fishAlerts = thresholds.fishAlerts;
    lowSoc = thresholds.lowSoc.round();
    staleMinutes = thresholds.staleMinutes;
    offlineMinutes = thresholds.offlineMinutes;
    dailyTarget.text = p.getString(SettingsKeys.dailyProductionTargetKwh) ?? '';
    cctvUrl.text = savedCctvUrl;
    fishCctvUrl.text = savedFishCctvUrl;
    // Every environment range has both keys today, but the fish list proved
    // that a one-sided range is a real shape: an unguarded `minKey!` there
    // threw, so the same guard is kept on both loops.
    //
    // A key that is present clears the prefill flag; a key that is missing
    // leaves it set, because the field is then still showing the shipped default
    // and no rule is enforcing it. Keeping the prefill text in that case is
    // deliberate — it is what the user would type anyway — but it used to be
    // indistinguishable from a stored limit, which is how a "Max 100 NTU" could
    // sit in the field while nothing monitored turbidity.
    for (final range in [...envRanges, ...fishRanges]) {
      if (range.minKey != null) {
        final stored = p.getString(range.minKey!);
        if (stored != null) {
          range.min.text = stored;
          range.minIsPrefill = false;
        }
      }
      if (range.maxKey != null) {
        final stored = p.getString(range.maxKey!);
        if (stored != null) {
          range.max.text = stored;
          range.maxIsPrefill = false;
        }
      }
    }
    notifyListeners();
  }

  Future<void> loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    // Same reason as [load]: launched unawaited from initState, and
    // notifying a disposed ChangeNotifier asserts in debug.
    if (_abandoned) return;
    appVersion = '${info.version}+${info.buildNumber}';
    notifyListeners();
  }

  // ── Validation ──────────────────────────────────────────────────────────────
  /// Returns the first validation error, or null when the form is valid.
  String? validate() {
    for (final (range, label) in [
      (envRanges[0], 'Temperature'),
      (envRanges[1], 'Humidity'),
      (envRanges[2], 'TDS'),
    ]) {
      final error = validateEnvRange(range, errorLabel: label);
      if (error != null) return error;
    }
    for (final (range, label) in [
      (fishRanges[0], 'pH'),
      (fishRanges[1], 'Water temperature'),
      (fishRanges[2], 'Turbidity'),
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
    final fishAlertsError = validateEnvironmentAlertsEnabled(
      enabled: fishAlerts,
      ranges: fishRanges,
    );
    if (fishAlertsError != null) return fishAlertsError;
    if (parseAllowedCctvUrl(cctvUrl.text) == null) {
      return 'The CCTV URL must be HTTPS and use an approved host';
    }
    if (parseAllowedCctvUrl(fishCctvUrl.text) == null) {
      return 'The fish camera URL must be HTTPS and use an approved host';
    }
    return null;
  }

  // ── Saving ──────────────────────────────────────────────────────────────────
  /// Persists every setting. Returns an error message when [validate] rejects
  /// the current values, or null when they were written successfully.
  ///
  /// Validation failures are returned because they are meant to be read: the
  /// caller shows the message and the user fixes the field. Unexpected I/O
  /// failures still throw, and the caller is responsible for surfacing them —
  /// `SettingsScreen._save` catches and shows a SnackBar, because an exception
  /// escaping here used to become an unhandled async error and the Save button
  /// simply did nothing.
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
      await p.setBool(SettingsKeys.fishAlertsEnabled, fishAlerts);
      await p.setInt(SettingsKeys.lowSocThreshold, lowSoc);
      await p.setInt(SettingsKeys.staleTelemetryMinutes, staleMinutes);
      await p.setInt(SettingsKeys.offlineTelemetryMinutes, offlineMinutes);
      await _saveDailyTarget(p);
      // A range may be missing a key on one side (turbidity is upper bound
      // only), so that side is skipped. `range.minKey!` used to throw right
      // here: after the environment values were written, before the CCTV URLs,
      // and with nothing on screen to say the save had failed.
      for (final range in envRanges) {
        if (range.minKey != null) {
          await _saveIfNotEmpty(p, range.minKey!, range.min.text);
        }
        if (range.maxKey != null) {
          await _saveIfNotEmpty(p, range.maxKey!, range.max.text);
        }
      }
      for (final range in fishRanges) {
        if (range.minKey != null) {
          await _saveIfNotEmpty(p, range.minKey!, range.min.text);
        }
        if (range.maxKey != null) {
          await _saveIfNotEmpty(p, range.maxKey!, range.max.text);
        }
      }
      // The dashboard reads the stream URLs from secure storage, not prefs.
      await saveCctvUrl(cctvUrl.text.trim());
      await saveFishCctvUrl(fishCctvUrl.text.trim());
      // Everything on screen has just been written, so no field is still
      // showing an unsaved default. Cleared here rather than on the next load
      // so the marker disappears the moment the save succeeds.
      for (final range in [...envRanges, ...fishRanges]) {
        range.markSaved();
      }
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

  /// True once [dispose] has run, so an in-flight [load] or [save] can stop.
  ///
  /// **This exists because those two methods are launched unawaited and both
  /// contain real I/O.** `SettingsScreen` calls `_settings..load()..loadAppVersion()`
  /// in `initState` and disposes the controller in its own `dispose`, and the back
  /// gesture is the first thing on screen. `load()` awaits
  /// `SharedPreferences.getInstance()` and two reads through `flutter_secure_storage`
  /// — platform channels, tens of milliseconds — so backing out inside that window
  /// is ordinary, not a race anyone has to try hard to reach.
  ///
  /// Without the guard the continuations write `.text` on disposed
  /// `TextEditingController`s and call `notifyListeners()` on a disposed
  /// `ChangeNotifier`. Because the future is unawaited that surfaces as an
  /// unhandled async error and a red screen in debug, and as silent mutation of
  /// disposed controllers in release.
  ///
  /// `mounted` was not an option: `SettingsController` is a `ChangeNotifier`, not a
  /// `State`, so it has no `mounted` of its own.
  bool _disposed = false;

  /// Stops an in-flight continuation from touching a disposed controller.
  ///
  /// Called after every `await` in [load], [loadAppVersion] and [save]. Returns
  /// true when the caller should bail out.
  bool get _abandoned => _disposed;

  @override
  void dispose() {
    _disposed = true;
    cctvUrl.dispose();
    fishCctvUrl.dispose();
    dailyTarget.dispose();
    for (final range in envRanges) {
      range.dispose();
    }
    for (final range in fishRanges) {
      range.dispose();
    }
    super.dispose();
  }
}
