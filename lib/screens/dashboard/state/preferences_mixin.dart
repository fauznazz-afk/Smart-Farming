import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/settings_keys.dart';
import '../../../services/alarm_notification_service.dart';
import '../../../services/cctv_url.dart';
import '../../../services/connection_health_service.dart';
import '../../../services/alarm_settings.dart';
import '../../../services/thingsboard_api.dart';
import '../../../utils/alarm_rules.dart';
import '../../../utils/poll_interval.dart';
import 'alarms_mixin.dart';

/// The preference and refresh-timer half of the dashboard.
///
/// A mixin rather than a controller because every field here is written by
/// `_loadPreferences` on resume and read directly by the page builders and the
/// `Bound` token. Passing them through a service would mean copying them back
/// into this `State` on every change, which is the same state with an extra hop.
///
/// Depends on [DashboardAlarms]: the thresholds a preferences read produces are
/// fed straight into `setThresholds`, and a threshold change has to reach both
/// the banner and the native background module in the same pass.
mixin DashboardPreferences<T extends StatefulWidget>
    on State<T>, DashboardAlarms<T> {
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  Timer? _refreshTimer;
  final connectionHealth = ConnectionHealthService();

  String displayName = '';
  String cctvUrl = defaultAllowedCctvUrl;
  String cctvUrlFish = defaultAllowedFishCctvUrl;

  /// Rupiah per kWh, and the array's nameplate in watts. Both null until the
  /// user supplies them — the cost card hides rather than showing zeros.
  double? dailyProductionTargetKwh;
  double? electricityTariffPerKwh;
  double? pvInstalledWp;

  /// Whether the WebSocket is carrying telemetry, which decides the poll floor.
  bool get realtimeConnected;

  /// One telemetry pass, for the timer to call.
  Future<void> fetchAll();

  /// The last fetch's failure, or null when it succeeded.
  Object? get lastError;

  ThingsBoardApi get preferencesApi;

  Future<void> loadDisplayName() async {
    final name = await preferencesApi.fetchDisplayName();
    if (mounted) setState(() => displayName = name);
  }

  Future<void> loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final loadedCctvUrl = await loadCctvUrl();
    if (!mounted) return;
    final fishCctvUrl = await loadFishCctvUrl();
    if (!mounted) return;
    final loadedThresholds = readAlarmThresholds(preferences);
    setState(() {
      _autoRefresh = preferences.getBool(SettingsKeys.autoRefresh) ?? true;
      _refreshSeconds = preferences.getInt(SettingsKeys.refreshSeconds) ?? 10;
      setThresholds(loadedThresholds);
      dailyProductionTargetKwh = readPreferenceDouble(
        preferences,
        SettingsKeys.dailyProductionTargetKwh,
      );
      electricityTariffPerKwh = readPreferenceDouble(
        preferences,
        SettingsKeys.electricityTariffPerKwh,
      );
      pvInstalledWp = readPreferenceDouble(
        preferences,
        SettingsKeys.pvInstalledWp,
      );
      cctvUrl = loadedCctvUrl;
      cctvUrlFish = fishCctvUrl;
    });
    restartRefreshTimer();
    // Must precede the first evaluation, otherwise every alarm looks new to a
    // fresh process and gets announced again on top of the background's.
    await primeActiveAlerts();
    if (!mounted) return;
    evaluateEnergyAlerts();
    // The background check evaluates the same rules, so it has to be told when
    // the thresholds change. A threshold raised above the current SOC would
    // otherwise keep notifying from the background for up to a quarter of an
    // hour after the user turned it off.
    unawaited(AlarmNotificationService.sync(api: preferencesApi));
  }

  static double? readPreferenceDouble(
    SharedPreferences preferences,
    String key,
  ) => double.tryParse(preferences.getString(key) ?? '');

  void restartRefreshTimer() {
    _refreshTimer?.cancel();
    if (!_autoRefresh) {
      connectionHealth.markDisconnected(ConnectionTransport.polling);
      return;
    }
    connectionHealth.markConnected(ConnectionTransport.polling);
    // **The interval depends on whether the WebSocket is carrying telemetry.**
    //
    // A 10 s REST re-read fetches values the socket already pushed into these
    // slots, for three devices, for as long as the app stays open. The floor is
    // 60 s and the poll still runs, because the socket sends no ping and a
    // dead-but-open connection is only noticed by a re-read. See
    // `utils/poll_interval.dart`.
    final interval = effectivePollIntervalSeconds(
      requestedSeconds: _refreshSeconds,
      realtimeConnected: realtimeConnected,
    );
    _refreshTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      final started = DateTime.now();
      await fetchAll();
      if (lastError == null) {
        connectionHealth.markSuccess(
          ConnectionTransport.polling,
          latency: DateTime.now().difference(started),
        );
      } else {
        connectionHealth.markError(
          ConnectionTransport.polling,
          degraded: true,
        );
      }
    });
  }

  /// Stops the timer without deciding whether polling is on.
  void cancelRefreshTimer() => _refreshTimer?.cancel();

  AlarmThresholds get alarmThresholds => thresholds;
}
