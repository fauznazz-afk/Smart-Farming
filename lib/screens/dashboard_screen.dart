import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_keys.dart';
import '../models/telemetry_model.dart';
import '../services/alarm_bridge.dart';
import '../services/alarm_history_service.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_settings.dart';
import '../services/cctv_url.dart';
import '../services/connection_health_service.dart';
import '../services/energy_forecast_service.dart';
import '../services/thingsboard_api.dart';
import '../services/thingsboard_realtime_service.dart';
import '../theme/app_theme_controller.dart';
import '../utils/alarm_helpers.dart';
import '../utils/alarm_rules.dart';
import '../widgets/energy_summary_card.dart';
import '../widgets/liquid_glass.dart';
import 'alarm_history_screen.dart';
import 'cctv_screen.dart';
import 'dashboard/charts/chart_data.dart';
import 'dashboard/utils/bound.dart';
import 'dashboard/utils/chart_gesture_lock.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/energy_helpers.dart';
import 'dashboard/utils/history_range.dart';
import 'dashboard/utils/telemetry_helpers.dart';
import 'dashboard/widgets/banners.dart';
import 'dashboard/widgets/chart_card.dart';
import 'dashboard/widgets/date_strip.dart';
import 'dashboard/widgets/power_sub_tabs.dart';
import 'dashboard/widgets/system_status_strip.dart';
import 'dashboard/widgets/metric_grid.dart';
import 'dashboard/widgets/metric_specs.dart';
import 'dashboard/widgets/greeting_header.dart';
import 'dashboard/widgets/live_power_card.dart';
import 'dashboard/widgets/nav_bar.dart';
import 'dashboard/widgets/telemetry_card.dart';
import 'energy_report_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Main monitoring dashboard: overview, PV, AC, battery, and CCTV tabs.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.themeController,
  });

  final ThingsBoardApi api;
  final AppThemeController themeController;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // ── Navigation & lifecycle ───────────────────────────────────────────────────
  final _pageController = PageController();
  final ValueNotifier<int> _selectedPage = ValueNotifier(0);
  final ValueNotifier<bool> _navCollapsed = ValueNotifier(false);
  final ValueNotifier<double> _appBarBlurProgress = ValueNotifier(0);
  double _downScrollDistance = 0;
  int _selectedIndex = 0;

  /// Which of PV / AC / Battery the Power tab is showing.
  ///
  /// A notifier rather than plain state so that selecting a sub-view rebuilds only
  /// the Power page. See `_powerPage` for the measurement that motivated it.
  final ValueNotifier<int> _powerSubNotifier = ValueNotifier(0);

  // ── Telemetry ────────────────────────────────────────────────────────────────
  DeviceTelemetry? _battery;
  DeviceTelemetry? _pzem;
  DeviceTelemetry? _sensor;
  DeviceTelemetry? _fish;
  bool _loading = true;
  bool _telemetryRequestInFlight = false;
  String? _error;
  bool _isOfflineMode = false;
  DateTime? _cachedTelemetryTime;
  DateTime? _lastSuccessfulTelemetryAt;
  bool _realtimeConnected = false;
  late final ThingsBoardRealtimeService _realtimeService =
      ThingsBoardRealtimeService(
        api: widget.api,
        onTelemetry: _handleRealtimeTelemetry,
        onConnectionChanged: _handleRealtimeConnection,
      );

  // ── History & charts ─────────────────────────────────────────────────────────
  final Map<String, List<TelemetryPoint>> _history = {};
  final Map<String, List<FlSpot>> _chartSpots = {};
  final Map<String, SeriesStats?> _chartStats = {};
  final Map<String, ChartBounds> _chartBounds = {};
  bool _chartLoading = true;
  final _historyRequestInFlight = <String>{};

  /// Bumped when a history request starts or finishes, so the chart header can
  /// show that it is updating. The set itself changing is not observable.
  final ValueNotifier<int> _historyBusyNotifier = ValueNotifier(0);
  final _historyRequestDate = <String, String>{};
  final _historyPendingRefresh = <String>{};
  final _historyLoaded = <String>{};

  // ── Date selection ───────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedRangeStart;
  DateTime? _selectedRangeEnd;

  // ── Energy summary ───────────────────────────────────────────────────────────
  final Map<String, List<TelemetryPoint>> _energyHistory = {};
  bool _energyLoading = true;
  bool _energyRequestInFlight = false;
  String? _energyError;
  bool _weeklyEnergySummary = false;
  DateTime? _energyUpdatedAt;
  double _solarKwh = 0;
  double _previousSolarKwh = 0;
  double _loadKwh = 0;
  double _previousLoadKwh = 0;
  double? _dailyProductionTargetKwh;
  static const _energyForecastService = EnergyForecastService();

  // ── Refresh & preferences ────────────────────────────────────────────────────
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  Timer? _refreshTimer;
  final _connectionHealth = ConnectionHealthService();
  late final Listenable _connectionChromeListenable = Listenable.merge([
    _liveRevision,
    _connectionHealth,
  ]);

  // ── Alerts ───────────────────────────────────────────────────────────────────
  final _alarmHistoryService = AlarmHistoryService();
  final ValueNotifier<List<String>> _alertMessages = ValueNotifier(const []);

  /// Alarms currently raised, and the subset of them already reported.
  ///
  /// Seeded from the native alarm module so an alarm the background check
  /// already notified about is not notified about again here, and published
  /// back to it so the reverse also holds.
  Set<String> _activeAlertIds = {};

  /// Thresholds for every alert rule, resolved from settings in one place.
  ///
  /// Replaces eight separate fields whose defaults were previously repeated in
  /// the settings controller, the dashboard and the background service, which is
  /// how the same setting came to default to different values in different
  /// readers.
  AlarmThresholds _thresholds = AlarmThresholds.defaults;

  /// The rule list, rebuilt only when the thresholds change.
  ///
  /// This was a getter, so every read rebuilt the whole list from scratch —
  /// roughly fifteen `AlarmRule` objects plus nine short-lived helper instances.
  /// `_evaluateEnergyAlerts` reads it on every telemetry frame the socket
  /// delivers, and does so *before* its own `if (!changed) return` bail-out, so
  /// the common case of nothing having changed still paid for a fresh rule list.
  /// The thresholds only move in `_setThresholds`, which is the only writer.
  late List<AlarmRule> _alarmRules = buildAlarmRules(_thresholds);

  void _setThresholds(AlarmThresholds value) {
    if (identical(value, _thresholds)) return;
    _thresholds = value;
    _alarmRules = buildAlarmRules(value);
  }

  int get _staleTelemetryMinutes => _thresholds.staleMinutes;

  // ── Misc ─────────────────────────────────────────────────────────────────────
  String _displayName = '';
  String _cctvUrl = defaultAllowedCctvUrl;
  String _cctvUrlFish = defaultAllowedFishCctvUrl;
  final ValueNotifier<int> _cctvKeepAlive = ValueNotifier(0);
  final ValueNotifier<int> _liveRevision = ValueNotifier(0);
  // One counter per ThingsBoard device, for the cards that read exactly one
  // device each.
  //
  // `_liveRevision` has to stay wide: the status strip, both banners and the hero
  // card read state spread across all four devices, so any change has to reach
  // them. But the PV/AC/Battery cards and the two `MetricGrid`s read one device
  // and nothing else, and the socket delivers frames two or three times a second,
  // so a frame from the BMS was rebuilding a greenhouse card that could not have
  // drawn anything different. Each counter below is bumped only when its own
  // device's values differ, by the same `sameTelemetry` test the wide path
  // already uses, so a device that publishes unchanged values now costs nothing.
  //
  // Safe to be narrower because each consumer's builder reads only the device
  // named here; the theme, seed colour, performance mode and alarm thresholds it
  // also reads are already part of `_visualToken`, which rebuilds it on change.
  final ValueNotifier<int> _batteryRevision = ValueNotifier(0);
  final ValueNotifier<int> _pzemRevision = ValueNotifier(0);
  final ValueNotifier<int> _sensorRevision = ValueNotifier(0);
  final ValueNotifier<int> _fishRevision = ValueNotifier(0);
  final ValueNotifier<int> _energyRevision = ValueNotifier(0);
  final ValueNotifier<int> _chartRevision = ValueNotifier(0);
  final ValueNotifier<bool> _chartPointerActiveNotifier = ValueNotifier(false);

  bool get _performanceMode => widget.themeController.performanceMode;

  Color get _seedColor => widget.themeController.seedColor;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.themeController.addListener(_onThemeChanged);
    _fetchAll();
    unawaited(_realtimeService.start());
    _fetchEnergyHistory();
    _loadPreferences();
    _loadDisplayName();
    // The screen is already on screen at this point, so the background check
    // has to stand down before its next tick rather than at the first resume
    // callback, which may not arrive for a while.
    unawaited(AlarmBridge.instance.setForeground(true));
    // If the app was launched by tapping an alarm notification, navigate to the
    // alarm history screen so the user can see what fired.
    unawaited(_checkLaunchAlarm());
  }

  Future<void> _checkLaunchAlarm() async {
    final alarmId = await AlarmBridge.instance.launchAlarmId();
    if (alarmId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AlarmHistoryScreen()),
      );
    }
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _selectedPage.dispose();
    _powerSubNotifier.dispose();
    _historyBusyNotifier.dispose();
    _navCollapsed.dispose();
    _appBarBlurProgress.dispose();
    _chartPointerActiveNotifier.dispose();
    _liveRevision.dispose();
    _batteryRevision.dispose();
    _pzemRevision.dispose();
    _sensorRevision.dispose();
    _fishRevision.dispose();
    _energyRevision.dispose();
    _chartRevision.dispose();
    _alertMessages.dispose();
    _cctvKeepAlive.dispose();
    _refreshTimer?.cancel();
    // Nothing is evaluating alarms once this screen is gone, so the background
    // check has to be allowed to run again.
    unawaited(AlarmBridge.instance.setForeground(false));
    unawaited(_realtimeService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartRefreshTimer();
      // Tells the background check to stand down: the dashboard polls every ten
      // seconds and evaluates the same rules, so a background tick on top of that
      // is duplicate work against the same ThingsBoard instance.
      unawaited(AlarmBridge.instance.setForeground(true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
      unawaited(AlarmBridge.instance.setForeground(false));
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  // ── Scroll-driven chrome ─────────────────────────────────────────────────────
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _downScrollDistance = 0;
      } else if (notification.direction == ScrollDirection.forward) {
        _downScrollDistance = 0;
        _navCollapsed.value = false;
      } else if (notification.metrics.pixels <= 0) {
        _downScrollDistance = 0;
        _navCollapsed.value = false;
      }
    } else if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != null &&
        notification.scrollDelta! > 0) {
      _downScrollDistance += notification.scrollDelta!;
      if (_downScrollDistance >= 12 && !_navCollapsed.value) {
        _navCollapsed.value = true;
      }
    }
    final progress = ((notification.metrics.pixels - 4) / 44)
        .clamp(0.0, 1.0)
        .toDouble();
    if (progress == 0.0 || progress == 1.0) {
      if (_appBarBlurProgress.value != progress) {
        _appBarBlurProgress.value = progress;
      }
    } else if ((progress - _appBarBlurProgress.value).abs() >= 0.015) {
      _appBarBlurProgress.value = progress;
    }
    return false;
  }

  // ── Preferences ──────────────────────────────────────────────────────────────
  Future<void> _loadDisplayName() async {
    final name = await widget.api.fetchDisplayName();
    if (mounted) setState(() => _displayName = name);
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final cctvUrl = await loadCctvUrl();
    if (!mounted) return;
    final fishCctvUrl = await loadFishCctvUrl();
    if (!mounted) return;
    final thresholds = readAlarmThresholds(preferences);
    setState(() {
      _autoRefresh = preferences.getBool(SettingsKeys.autoRefresh) ?? true;
      _refreshSeconds =
          preferences.getInt(SettingsKeys.refreshSeconds) ?? 10;
      _setThresholds(thresholds);
      _dailyProductionTargetKwh = _readDouble(
        preferences,
        SettingsKeys.dailyProductionTargetKwh,
      );
      _cctvUrl = cctvUrl;
      _cctvUrlFish = fishCctvUrl;
    });
    _restartRefreshTimer();
    // Must precede the first evaluation, otherwise every alarm looks new to a
    // fresh process and gets announced again on top of the background's.
    await _primeActiveAlerts();
    if (!mounted) return;
    _evaluateEnergyAlerts();
    // The background check evaluates the same rules, so it has to be told when
    // the thresholds change. A threshold raised above the current SOC would
    // otherwise keep notifying from the background for up to a quarter of an
    // hour after the user turned it off.
    unawaited(AlarmNotificationService.sync(api: widget.api));
  }

  static double? _readDouble(SharedPreferences preferences, String key) =>
      double.tryParse(preferences.getString(key) ?? '');

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    if (!_autoRefresh) {
      _connectionHealth.markDisconnected(ConnectionTransport.polling);
      return;
    }
    _connectionHealth.markConnected(ConnectionTransport.polling);
    _refreshTimer = Timer.periodic(Duration(seconds: _refreshSeconds), (_) async {
      final started = DateTime.now();
      await _fetchAll();
      if (_error == null) {
        _connectionHealth.markSuccess(
          ConnectionTransport.polling,
          latency: DateTime.now().difference(started),
        );
      } else {
        _connectionHealth.markError(
          ConnectionTransport.polling,
          degraded: true,
        );
      }
    });
  }

  // ── Telemetry fetching ───────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    if (_telemetryRequestInFlight) return;
    _telemetryRequestInFlight = true;
    final started = DateTime.now();
    // No `markConnecting(ConnectionTransport.rest)` here, deliberately.
    //
    // It fired a real `notifyListeners()` on every single poll, because
    // `connecting != connected` and the following `markSuccess` produced no
    // notification of its own: the status went to `connected` and stayed there.
    // The strip rebuilds its banner switcher to draw that, and none of its four
    // branches render a connecting state. Nothing else reads the status either —
    // `statusMessage` only reaches the screen through a banner that is showing a
    // fetch failure or a stale device, and both of those override the label; the
    // in-flight state is `_telemetryRequestInFlight` above, not this.
    try {
      final results = await Future.wait([
        widget.api.fetchBatteryData(),
        widget.api.fetchPzemData(),
        widget.api.fetchSensorData(),
        widget.api.fetchFishData(),
      ]);
      if (!mounted) return;
      final now = DateTime.now();
      final wasLoading = _loading;
      // Per device rather than one `changed`, because each card is now rebuilt by
      // the counter for the device it reads. A tick that moved the BMS and
      // nothing else must not announce itself to the greenhouse grid.
      final batteryChanged = !sameTelemetry(_battery, results[0]);
      final pzemChanged = !sameTelemetry(_pzem, results[1]);
      final sensorChanged = !sameTelemetry(_sensor, results[2]);
      final fishChanged = !sameTelemetry(_fish, results[3]);
      final changed =
          _loading ||
          _error != null ||
          batteryChanged ||
          pzemChanged ||
          sensorChanged ||
          fishChanged;
      final timestampChanged =
          _lastSuccessfulTelemetryAt == null ||
          now.difference(_lastSuccessfulTelemetryAt!).inMinutes >= 1;
      _battery = results[0];
      _pzem = results[1];
      _sensor = results[2];
      _fish = results[3];
      // One merged cache write for the whole tick, and not awaited.
      //
      // This used to happen per device inside each fetch, so one poll meant four
      // concurrent read-modify-write cycles against the same key: each read the
      // same snapshot and each wrote only its own device, so three of the four
      // buckets were discarded by whichever write landed last. Measured on the
      // test device at 32-77 ms per write, all of it on the poll's critical path
      // because `Future.wait` could not complete until the slowest write finished.
      //
      // Fire-and-forget because it is a best-effort offline fallback: the values
      // are already in memory and on screen, and nothing should wait on storage.
      unawaited(
        widget.api.cacheTelemetrySnapshot({
          ThingsBoardApi.deviceBattery: results[0],
          ThingsBoardApi.devicePzem: results[1],
          ThingsBoardApi.deviceSensor: results[2],
          ThingsBoardApi.deviceFish: results[3],
        }),
      );
      _lastSuccessfulTelemetryAt = now;
      _loading = false;
      _error = null;
      _isOfflineMode = false;
      _connectionHealth.markSuccess(
        ConnectionTransport.rest,
        latency: DateTime.now().difference(started),
        updatedAt: now,
      );
      _notifyLive(wasLoading: wasLoading, changed: changed || timestampChanged);
      _notifyDeviceRevisions(
        battery: batteryChanged,
        pzem: pzemChanged,
        sensor: sensorChanged,
        fish: fishChanged,
        // Once a minute, whichever device moved.
        //
        // `MetricGrid` decides its own "Stale data" tag at build time, from
        // `DateTime.now()` against that device's `lastUpdate`, so a grid that is
        // never rebuilt goes on claiming freshness for a sensor that has died.
        // The wide counter used to hide that by rebuilding it several times a
        // second as a side effect; a per-minute bump to four small widgets does
        // the same job without the cost.
        all: timestampChanged,
      );
      _evaluateEnergyAlerts();
      final lastEnergyUpdate = _energyUpdatedAt;
      if (lastEnergyUpdate == null ||
          DateTime.now().difference(lastEnergyUpdate).inMinutes >= 15) {
        unawaited(_fetchEnergyHistory());
      }
    } catch (error) {
      _connectionHealth.markError(ConnectionTransport.rest, degraded: true);
      if (!mounted) return;
      if (error.toString().contains('Token expired')) {
        // Same as an explicit logout: the session is over, so the background
        // check has to stop too.
        unawaited(AlarmNotificationService.disable());
        await widget.api.logout();
        if (!mounted) return;
        _goToLogin();
        return;
      }
      await _applyOfflineFallback();
      final message = error.toString();
      if (_error != message || _loading) {
        final wasLoading = _loading;
        _error = message;
        _loading = false;
        _notifyLive(wasLoading: wasLoading, changed: wasLoading || _battery == null);
      }
    } finally {
      _telemetryRequestInFlight = false;
    }
  }

  /// Rebuilds either via setState (first paint) or via a cheap notifier bump.
  void _notifyLive({required bool wasLoading, required bool changed}) {
    if (!changed) return;
    if (wasLoading) {
      if (mounted) setState(() {});
    } else {
      _liveRevision.value++;
    }
  }

  /// Announces a telemetry change to the one card per device that reads it.
  ///
  /// Each flag is the result of `sameTelemetry` for that device alone, so a card
  /// is only ever rebuilt for a difference it could actually draw. [all] bumps
  /// all four at once, for the once-a-minute refresh described at the call site.
  ///
  /// Called on the first paint as well, where `_notifyLive` only calls
  /// `setState`. That is not redundant: `Bound` caches its child, and its
  /// `didUpdateWidget` does not re-run the builder when the listenable and the
  /// token are both unchanged, so a plain `setState` leaves any `Bound` that was
  /// built before the data arrived still showing no data.
  void _notifyDeviceRevisions({
    bool battery = false,
    bool pzem = false,
    bool sensor = false,
    bool fish = false,
    bool all = false,
  }) {
    if (all || battery) _batteryRevision.value++;
    if (all || pzem) _pzemRevision.value++;
    if (all || sensor) _sensorRevision.value++;
    if (all || fish) _fishRevision.value++;
  }

  /// Falls back to cached telemetry when every live device fetch failed.
  Future<void> _applyOfflineFallback() async {
    if (_battery != null || _pzem != null || _sensor != null) {
      _isOfflineMode = true;
      return;
    }
    final cached = await widget.api.loadCachedTelemetry();
    final cacheTime = await widget.api.getCachedTelemetryTime();
    if (cached == null || !mounted) return;
    final split = splitCachedTelemetry(cached.latestValues);
    _isOfflineMode = true;
    _cachedTelemetryTime = cacheTime;
    _battery = DeviceTelemetry(
      latestValues: split.battery,
      lastUpdate: cached.lastUpdate,
    );
    _pzem = DeviceTelemetry(
      latestValues: split.pzem,
      lastUpdate: cached.lastUpdate,
    );
    _sensor = DeviceTelemetry(
      latestValues: split.sensor,
      lastUpdate: cached.lastUpdate,
    );
    _fish = DeviceTelemetry(
      latestValues: split.fish,
      lastUpdate: cached.lastUpdate,
    );
    // The four slots were just filled from cache where they were null, so each
    // card needs its rebuild. `_fetchAll` may only `setState` on this path.
    _notifyDeviceRevisions(all: true);
  }

  void _handleRealtimeConnection(bool connected) {
    if (!mounted || _realtimeConnected == connected) return;
    setState(() => _realtimeConnected = connected);
    if (connected) {
      _connectionHealth.markConnected(ConnectionTransport.webSocket);
    } else {
      _connectionHealth.markDisconnected(ConnectionTransport.webSocket);
    }
  }

  void _handleRealtimeTelemetry(
    String deviceId,
    Map<String, TelemetryPoint> values,
  ) {
    if (!mounted || values.isEmpty) return;
    final slot = switch (deviceId) {
      ThingsBoardApi.deviceBattery => _battery,
      ThingsBoardApi.devicePzem => _pzem,
      ThingsBoardApi.deviceSensor => _sensor,
      ThingsBoardApi.deviceFish => _fish,
      _ => null,
    };
    if (slot == null && !_isKnownDevice(deviceId)) return;

    final mergedValues = <String, double>{
      ...?slot?.latestValues,
      for (final entry in values.entries) entry.key: entry.value.value,
    };
    var latest = slot?.lastUpdate;
    for (final point in values.values) {
      if (latest == null || point.timestamp.isAfter(latest)) {
        latest = point.timestamp;
      }
    }
    final updated = DeviceTelemetry(
      latestValues: mergedValues,
      lastUpdate: latest,
    );
    switch (deviceId) {
      case ThingsBoardApi.deviceBattery:
        _battery = updated;
      case ThingsBoardApi.devicePzem:
        _pzem = updated;
      case ThingsBoardApi.deviceSensor:
        _sensor = updated;
      case ThingsBoardApi.deviceFish:
        _fish = updated;
    }

    final wasLoading = _loading;
    // Gate the rebuild on the values actually differing, exactly as the poll path
    // does. This used to pass `changed: true` unconditionally, which meant every
    // telemetry frame the socket delivered announced itself as a change: the PZEM
    // and the BMS publish around 1 Hz each, so the revision counter went up two or
    // three times a second, roughly thirty times more often than the ten-second
    // poll it was designed around, and every Bound in the tree rebuilt with it.
    //
    // The socket can also deliver a frame whose values are identical to what is
    // already on screen, which is the common case for a device that reports on a
    // slow cycle. Those frames used to be indistinguishable from real changes.
    final changed =
        wasLoading ||
        _error != null ||
        !sameTelemetry(slot, updated);
    _connectionHealth.markSuccess(
      ConnectionTransport.webSocket,
      latency: DateTime.now().difference(values.values.first.timestamp),
      updatedAt: latest,
    );
    _isOfflineMode = false;
    _lastSuccessfulTelemetryAt = DateTime.now();
    _error = null;
    _loading = false;
    _notifyLive(wasLoading: wasLoading, changed: changed);
    // One frame, one device, one card. The same `sameTelemetry` gate above
    // decides it, so a frame whose values are already on screen rebuilds
    // nothing at all now, not the whole tree.
    switch (deviceId) {
      case ThingsBoardApi.deviceBattery:
        _notifyDeviceRevisions(battery: changed);
      case ThingsBoardApi.devicePzem:
        _notifyDeviceRevisions(pzem: changed);
      case ThingsBoardApi.deviceSensor:
        _notifyDeviceRevisions(sensor: changed);
      case ThingsBoardApi.deviceFish:
        _notifyDeviceRevisions(fish: changed);
    }
    _evaluateEnergyAlerts();
  }

  static bool _isKnownDevice(String deviceId) =>
      deviceId == ThingsBoardApi.deviceBattery ||
      deviceId == ThingsBoardApi.devicePzem ||
      deviceId == ThingsBoardApi.deviceSensor ||
      deviceId == ThingsBoardApi.deviceFish;

  Future<void> _refreshCurrentPage() async {
    await _fetchAll();
    if (_selectedIndex == 0) await _fetchEnergyHistory();
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix == null) return;
    _historyLoaded.remove(prefix);
    await _fetchHistoryFor(prefix);
  }

  // ── Alerts ───────────────────────────────────────────────────────────────────
  void _evaluateEnergyAlerts() {
    final now = DateTime.now();
    final signals = evaluateAlarmRules(
      rules: _alarmRules,
      readings: _alarmReadings,
      now: now,
    );    final alerts = {for (final signal in signals) signal.id: signal.message};

    final newSignals = newlyActiveSignals(
      signals: signals,
      alreadyActive: _activeAlertIds,
    );
    final nextMessages = signals.map((signal) => signal.message).toList();
    final changed =
        alerts.length != _activeAlertIds.length ||
        !alerts.keys.every(_activeAlertIds.contains) ||
        !sameStrings(nextMessages, _alertMessages.value);
    if (!changed) return;
    _activeAlertIds = alerts.keys.toSet();
    _alertMessages.value = nextMessages;
    unawaited(AlarmBridge.instance.setActiveAlerts(_activeAlertIds));

    // Nothing is announced until the background module's active set has been
    // read. Before that read completes every alarm looks new, because a fresh
    // process starts with an empty set, and the first evaluation would report
    // alarms the background had already reported. The banner still updates, so
    // the user sees the state immediately either way.
    if (_activeAlertsPrimed && newSignals.isNotEmpty) {
      for (final signal in newSignals) {
        _persistAlarm(signal, now);
      }
    }
    // No SnackBar here, deliberately. The same messages already render in
    // `EnergyAlertBanner` at the top of the list, above the greeting, so the
    // SnackBar was the same sentence twice — once where the user was already
    // looking and once over the bottom of the screen, where it covered the
    // energy card and the navigation bar. Worse, it re-fired on every message
    // change rather than on every new alarm, so a reading drifting in and out
    // of range popped a bar every few seconds while the banner just sat there.
    // The banner is persistent, non-modal, and does not obscure content; that
    // is the right shape for a condition that is still true.
  }

  /// The devices the rules read, in the shape the evaluator expects.
  ///
  /// A device missing from this list cannot raise anything at all: the evaluator
  /// skips any rule whose device has no reading, because a device that was never
  /// read is not the same as a device that stopped reporting. The fish device is
  /// here so that `stale_fish` and `offline_fish` can actually fire.
  List<AlarmReading> get _alarmReadings => [
    if (_battery != null)
      AlarmReading(
        device: AlarmDevice.battery,
        values: _battery!.latestValues,
        lastUpdate: _battery!.lastUpdate,
      ),
    if (_pzem != null)
      AlarmReading(
        device: AlarmDevice.pzem,
        values: _pzem!.latestValues,
        lastUpdate: _pzem!.lastUpdate,
      ),
    if (_sensor != null)
      AlarmReading(
        device: AlarmDevice.sensor,
        values: _sensor!.latestValues,
        lastUpdate: _sensor!.lastUpdate,
      ),
    if (_fish != null)
      AlarmReading(
        device: AlarmDevice.fish,
        values: _fish!.latestValues,
        lastUpdate: _fish!.lastUpdate,
      ),
  ];

  /// Whether the background module's active set has been read yet.
  bool _activeAlertsPrimed = false;

  /// Reads the set of alarms the background check has already reported.
  ///
  /// Awaited during startup, before anything is allowed to announce an alarm.
  /// Doing it lazily inside the evaluation was the earlier mistake: the read is
  /// asynchronous, so the first evaluation always saw an empty set and reported
  /// alarms that the background had already reported, which is exactly the
  /// duplicate the shared set exists to prevent.
  Future<void> _primeActiveAlerts() async {
    if (_activeAlertsPrimed) return;
    _activeAlertsPrimed = true;
    final background = await AlarmBridge.instance.activeAlerts();
    if (!mounted || background.isEmpty) return;
    _activeAlertIds = {..._activeAlertIds, ...background};
  }

  void _persistAlarm(AlarmSignal signal, DateTime now) {
    unawaited(
      _alarmHistoryService.addAlarm(
        AlarmRecord(
          id: '${now.millisecondsSinceEpoch}_${signal.id}',
          timestamp: now,
          type: signal.type,
          severity: signal.severity,
          message: signal.message,
          value: signal.value,
        ),
      ),
    );
    unawaited(
      AlarmNotificationService.notifyAlarm(
        id: signal.id,
        title: signal.isCritical
            ? 'EnerGrow: Critical alarm'
            : 'EnerGrow: Warning alarm',
        message: signal.message,
        critical: signal.isCritical,
      ),
    );
  }

  // ── Energy summary ───────────────────────────────────────────────────────────
  Future<void> _fetchEnergyHistory() async {
    if (_energyRequestInFlight) return;
    _energyRequestInFlight = true;
    if (mounted && _energyHistory.isEmpty) {
      _energyLoading = true;
      _notifyEnergy();
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      final histories = await widget.api.fetchHistoryForKeys(
        ThingsBoardApi.devicePzem,
        const ['power_dc', 'power_ac'],
        start: today.subtract(const Duration(days: 13, minutes: 15)),
        end: now,
        intervalMs: 30 * 60 * 1000,
        limit: 1500,
      );
      if (!mounted) return;
      final hasHistory = histories.values.any((points) => points.isNotEmpty);
      _energyHistory
        ..clear()
        ..addAll({
          for (final entry in histories.entries)
            entry.key: List<TelemetryPoint>.of(entry.value)
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        });
      _updateMemoizedEnergy();
      _energyLoading = false;
      _energyError = hasHistory
          ? null
          : 'ThingsBoard has no power_dc/power_ac history in the last 14 days.';
      _energyUpdatedAt = now;
      _notifyEnergy();
    } catch (error) {
      if (!mounted) return;
      debugPrint('Energy summary history request failed: $error');
      _energyLoading = false;
      _energyError =
          'Power history could not be loaded. Pull down to retry.';
      _notifyEnergy();
    } finally {
      _energyRequestInFlight = false;
    }
  }

  void _setWeeklyEnergySummary(bool weekly) {
    if (_weeklyEnergySummary == weekly) return;
    _weeklyEnergySummary = weekly;
    _updateMemoizedEnergy();
    _notifyEnergy();
  }

  void _notifyEnergy() {
    if (mounted) _energyRevision.value++;
  }

  void _notifyCharts() {
    if (mounted) _chartRevision.value++;
  }

  void _updateMemoizedEnergy() {
    final solar = energyComparison(
      history: _energyHistory,
      key: 'power_dc',
      weekly: _weeklyEnergySummary,
    );
    final load = energyComparison(
      history: _energyHistory,
      key: 'power_ac',
      weekly: _weeklyEnergySummary,
    );
    _solarKwh = solar.current;
    _previousSolarKwh = solar.previous;
    _loadKwh = load.current;
    _previousLoadKwh = load.previous;
  }

  // ── Per-page history ─────────────────────────────────────────────────────────
  Future<void> _fetchHistoryFor(String prefix) async {
    final now = DateTime.now();
    final rangeStart = _selectedRangeStart ?? startOfDay(_selectedDate);
    final selectionKey = historySelectionKey(
      rangeStart: rangeStart,
      rangeEnd: _selectedRangeEnd,
    );
    // Always refetch, even when this view's data is already in hand.
    //
    // This used to return early on a cache hit, on the reasoning that a switch
    // should be instant. It is, but the numbers it showed were whatever was there
    // when that view was last opened, which for "Last 24 hours" on a live system
    // is not what anyone means by looking at it again.
    //
    // Refreshing unconditionally does not make the switch feel slower, because
    // nothing waits: `_chartLoading` is only raised when this prefix has no data at
    // all, so the already-loaded chart stays on screen and the fresh series
    // replaces it when the request lands. Stale-while-revalidate, not a spinner.
    if (_historyRequestInFlight.contains(prefix)) {
      if (_historyRequestDate[prefix] != selectionKey) {
        _historyPendingRefresh.add(prefix);
      }
      return;
    }
    _historyRequestInFlight.add(prefix);
    _historyRequestDate[prefix] = selectionKey;
    _historyBusyNotifier.value++;
    if (mounted && !_historyLoaded.contains(prefix)) {
      _chartLoading = true;
      _notifyCharts();
    }

    final window = historyWindowFor(
      prefix: prefix,
      rangeStart: rangeStart,
      rangeEnd: _selectedRangeEnd,
      now: now,
    );
    Map<String, List<TelemetryPoint>> histories;
    try {
      histories = await widget.api.fetchHistoryForKeys(
        window.deviceId,
        [window.keys.voltage, window.keys.current, window.keys.power],
        start: window.start,
        end: window.end,
        intervalMs: window.intervalMs,
      );
    } catch (_) {
      histories = const {};
    }

    // Drop the result if the user changed the selection while it was loading.
    final currentKey = historySelectionKey(
      rangeStart: _selectedRangeStart ?? startOfDay(_selectedDate),
      rangeEnd: _selectedRangeEnd,
    );
    if (mounted && currentKey == selectionKey) {
      _storeHistory(prefix, window.keys, histories);
      _chartLoading = false;
      _notifyCharts();
    }
    _historyRequestInFlight.remove(prefix);
    _historyRequestDate.remove(prefix);
    _historyBusyNotifier.value++;
    if (_historyPendingRefresh.remove(prefix) &&
        _prefixForPage(_selectedIndex) == prefix) {
      unawaited(_fetchHistoryFor(prefix));
    }
  }

  void _storeHistory(
    String prefix,
    HistoryKeys keys,
    Map<String, List<TelemetryPoint>> histories,
  ) {
    for (final (metric, key) in [
      ('voltage', keys.voltage),
      ('current', keys.current),
      ('power', keys.power),
    ]) {
      final points = histories[key] ?? [];
      _history['${prefix}_$metric'] = points;
      _chartSpots['${prefix}_$metric'] = processSpots(points);
      _chartStats['${prefix}_$metric'] = SeriesStats.fromPoints(points);
    }
    _chartBounds.remove(prefix);
    _historyLoaded.add(prefix);
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  // PV, AC and Battery share one tab, selected by a segmented control inside the
  // page rather than by three tabs of their own.
  //
  // The reason is arithmetic, and it is not close. Material 2 documents 80 dp as
  // the minimum width of a bottom-navigation destination in portrait, and this
  // phone is 380 dp wide, so a six-tab bar needed 480 dp — a hundred dp short of
  // fitting, and "Hydroponics" measured 62 dp in a 60 dp slot at the smallest
  // type size Material has. Material 3 states the limit and the symptom together:
  // "the elements may collide and there likely won't be enough space for
  // translated text."
  //
  // Four tabs need 320 dp, which fits with 60 dp to spare, and leaves one slot
  // free for a seventh destination later. The grouping is also the honest one:
  // PV, AC and Battery are three views of a single electrical system, all of it
  // from the PZEM and BMS devices, whereas Hydroponics and Fish are separate
  // subsystems that fail differently. Material asks for destinations "of equal
  // importance", and six peers was never the right description of what this app
  // has — it is a cluster of three plus an overview plus two singletons.
  //
  // Hydroponics and Fish deliberately have no prefix: they have no history chart.
  // TelemetryChartCard plots voltage/current/power under the names
  // `${prefix}_voltage`, `${prefix}_current` and `${prefix}_power`, so pH and
  // turbidity cannot be charted without generalising that widget. A null prefix
  // also means no history request is fired for those pages.
  //
  // Only the Power page has a prefix, and which one depends on the sub-tab the
  // user has selected inside it, so this cannot be a plain lookup any more. Four
  // callers depend on it agreeing with what is actually on screen: the history
  // fetch, pull-to-refresh, the date-change reload and the pending-refresh check.
  String? _prefixForPage(int index) =>
      index == 1 ? kPowerSubTabs[_powerSubNotifier.value].prefix : null;

  /// The status strip's battery cell is a shortcut to the battery readings, which
  /// are now a view inside the Power tab rather than a tab. Both halves have to
  /// happen, and the order matters: selecting the sub-view first means the page
  /// builds with the right content already in place instead of flashing PV.
  void _openBatteryFromStrip() {
    final batteryIndex = kPowerSubTabs.indexWhere(
      (tab) => tab.prefix == 'battery',
    );
    if (batteryIndex != _powerSubNotifier.value) {
      _powerSubNotifier.value = batteryIndex;
    }
    if (_selectedIndex != 1) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
      );
    }
    // Fetched by prefix rather than through _reloadHistoryForCurrentPage, which
    // reads _selectedIndex — and that is only updated by onPageChanged once the
    // animation above has finished. Relying on it here would fetch whatever page
    // the user was on, not the one they were sent to.
    _historyLoaded.remove('battery');
    unawaited(_fetchHistoryFor('battery'));
  }

  void _selectPage(int index) {
    if (_selectedPage.value == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
    );
  }

  void _setChartPointerActive(bool active) {
    if (_chartPointerActiveNotifier.value == active) return;
    _chartPointerActiveNotifier.value = active;
  }

  // ── Date selection ───────────────────────────────────────────────────────────
  List<DateTime> get _stripDays {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  void _clearHistoryCache() {
    _historyLoaded.clear();
    _chartBounds.clear();
    _chartSpots.clear();
    _chartStats.clear();
  }

  void _selectDate(DateTime date) {
    if (startOfDay(date) == startOfDay(_selectedDate)) return;
    setState(() {
      _selectedDate = date;
      _selectedRangeStart = null;
      _selectedRangeEnd = null;
      _clearHistoryCache();
    });
    _reloadHistoryForCurrentPage();
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final today = startOfDay(now);
    final firstDate = today.subtract(const Duration(days: 90));
    DateTime clamp(DateTime value) => value.isBefore(firstDate)
        ? firstDate
        : value.isAfter(today)
        ? today
        : value;
    final initialStart = clamp(startOfDay(_selectedRangeStart ?? _selectedDate));
    final initialEnd = clamp(startOfDay(_selectedRangeEnd ?? _selectedDate));
    final safeEnd = initialEnd.isBefore(initialStart)
        ? initialStart
        : initialEnd;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: safeEnd),
      firstDate: firstDate,
      lastDate: today,
      // The picker's own chrome is localised from this, not from the strings
      // passed in. Leaving it on Indonesian meant the day headers and month
      // names stayed Indonesian inside an otherwise English dialog, which was
      // the last Indonesian surface in the app.
      locale: const Locale('en', 'US'),
      helpText: 'Select a telemetry date range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = startOfDay(picked.start);
      _selectedRangeStart = startOfDay(picked.start);
      _selectedRangeEnd = startOfDay(picked.end);
      _clearHistoryCache();
    });
    _reloadHistoryForCurrentPage();
  }

  void _reloadHistoryForCurrentPage() {
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
  }

  // ── Screen routing ───────────────────────────────────────────────────────────
  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(themeController: widget.themeController),
      ),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    // Stop the background check before the session goes away. Otherwise the
    // native side keeps its own copy of the token and polls with it after the
    // user has signed out.
    unawaited(AlarmNotificationService.disable());
    await widget.api.logout();
    // Clear the CCTV URL so the next user on this device does not inherit
    // the previous user's stream URL.
    await clearCctvUrl();
    if (!mounted) return;
    _goToLogin();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController,
          onLogout: _logout,
        ),
      ),
    );
    if (changed == true) {
      _loadPreferences();
    }
  }

  void _openAlarmHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlarmHistoryScreen()),
    );
  }

  void _openEnergyReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EnergyReportScreen(api: widget.api)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(isDark),
      body: AmbientBackground(
        isDark: isDark,
        child: _buildBody(isDark),
      ),
      extendBody: true,
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _selectedPage,
        builder: (context, _, _) => GlassNavBar(
          selectedIndex: _selectedIndex,
          isDark: isDark,
          seedColor: _seedColor,
          collapsed: _navCollapsed,
          onSelect: _selectPage,
          onExpand: () => _navCollapsed.value = false,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      flexibleSpace: ValueListenableBuilder<double>(
        valueListenable: _appBarBlurProgress,
        builder: (context, progress, _) {
          if (progress == 0) return const SizedBox.expand();
          final baseColor = isDark
              ? const Color(0xFF101412)
              : const Color(0xFFF6F8F7);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.86 * progress),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.08 * progress,
                  ),
                ),
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
      leading: IconButton(
        tooltip: 'Reload data',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _loading ? null : _fetchAll,
      ),
      title: const Text(
        'EnerGrow',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Alarm History',
          icon: const Icon(Icons.history_outlined),
          onPressed: _openAlarmHistory,
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _battery == null) {
      return TelemetryErrorView(message: _error!, onRetry: _fetchAll);
    }
    // No ValueListenableBuilder here any more. The physics reads the pointer flag
    // at gesture time, so touching a chart no longer rebuilds the PageView — and
    // because the chart fills most of the PV, AC and Battery pages, that rebuild
    // used to fire twice for nearly every scroll on those pages.
    return PageView.builder(
      controller: _pageController,
      physics: ChartGestureLockPhysics(
        basePhysics: const PageScrollPhysics(),
        isLocked: () => _chartPointerActiveNotifier.value,
      ),
      itemCount: 4,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) => _buildPage(index, isDark),
    );
  }

  void _onPageChanged(int index) {
    _selectedIndex = index;
    _selectedPage.value = index;
    final prefix = _prefixForPage(index);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
    // Entering the Power tab warms all three of its sub-views.
    //
    // The symptom this fixes: switching between PV, AC and Battery left the
    // incoming card showing the previous fetch's numbers for as long as the
    // request took, which on a slow ThingsBoard is a second or two. It read as the
    // card being stuck rather than as a refresh, because nothing on screen said
    // anything was happening. There are only three views, so fetching all of them
    // on entry costs three requests once and makes every later switch land on data
    // that is already there. Each switch still refreshes in the background, so this
    // changes when the data arrives, not whether it is current.
    if (index == 1) _warmPowerSubViews();
  }

  void _warmPowerSubViews() {
    for (final tab in kPowerSubTabs) {
      unawaited(_fetchHistoryFor(tab.prefix));
    }
  }

  Widget _buildPage(int index, bool isDark) {
    // One status strip, not three. They used to stack, and a phone in offline
    // mode showed a green "polling active" line directly above an orange
    // "offline" line, which is two opposite claims about the same connection
    // stacked on top of each other before any content appeared.
    //
    // The alarm banner is Overview-only. A threshold breach is a fact about the
    // greenhouse, not about the page being looked at, so repeating it above the
    // PV, AC, Battery, Hydroponics and Fish pages pushed lines the user had
    // already read above the content they opened a tab to see. It still reaches
    // them where it matters: a notification, and the alarm count in the status
    // strip, which is present on every page.
    //
    // Connection state is different and stays everywhere, because a page of
    // numbers that cannot be trusted needs to say so wherever it is displayed.
    final items = <Widget Function()>[
      () => _statusStripBuilder(isDark, showAlerts: index == 0),
      ..._pageContentFor(index, isDark),
    ];
    return RepaintBoundary(
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          strokeWidth: 2.5,
          displacement: 58,
          edgeOffset:
              MediaQuery.paddingOf(context).top + kToolbarHeight,
          onRefresh: _refreshCurrentPage,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + kToolbarHeight - 6,
              16,
              MediaQuery.paddingOf(context).bottom + 76,
            ),
            itemCount: items.length,
            itemBuilder: (context, itemIndex) => items[itemIndex](),
          ),
        ),
      ),
    );
  }

  List<Widget Function()> _pageContentFor(int index, bool isDark) {
    // The `_ =>` arm renders Overview, so a page index added to the PageView
    // without an arm here shows the Overview page twice with no error anywhere.
    return switch (index) {
      1 => _powerPage(isDark),
      2 => _hydroponicsPage(isDark),
      3 => _fishPage(isDark),
      _ => _overviewPage(isDark),
    };
  }

  // ── Banners ──────────────────────────────────────────────────────────────────
  Object get _visualToken => Object.hash(
    _seedColor,
    _performanceMode,
    _selectedDate,
    _displayName,
    // The thresholds belong here. Bound only rebuilds when the listenable fires or
    // this token changes, and _loadPreferences changes the thresholds with a plain
    // setState — so without this, saving a new limit left the environment grid
    // captioning its old range and the status strip judging against the old
    // low-SOC threshold, until the next telemetry change happened to rescue it.
    _thresholds,
    // Which power sub-view is selected. PV, AC and Battery are three closure
    // lists spliced into the same Column, so their Bound widgets sit at the same
    // tree position and reuse each other's State. Bound keeps its cached child
    // when the token is unchanged, so without this the symptom was: tapping AC
    // then PV left the AC card and the AC chart on screen under the "PV Status"
    // header until the next revision bump — up to ten seconds for the telemetry
    // card, because that is the poll interval. The header is a plain widget and
    // updated immediately, which made the stale card below it read as the wrong
    // page rather than as a slow refresh.
    _powerSubNotifier.value,
  );

  Widget _bindRevision(
    Listenable listenable,
    bool isDark,
    Widget Function() builder,
  ) {
    return Bound(
      listenable: listenable,
      token: Object.hash(_visualToken, isDark),
      builder: builder,
    );
  }

  /// One status line for everything the user needs to know about liveness.
  ///
  /// Replaces three stacked banners with strict precedence: a fetch failure
  /// beats offline mode, which beats an active alarm, which beats stale devices.
  /// Only the most important thing is ever shown, so the strip cannot contradict
  /// itself and does not push the page content off screen.
  Widget _statusStripBuilder(bool isDark, {required bool showAlerts}) {
    return _bindRevision(
      _connectionChromeListenable,
      isDark,
      () {
        final failed = _error != null;
        final offline = _isOfflineMode;
        final alerts = _alertMessages.value;
        final stale = _staleDeviceNames();

        // Each branch is wrapped in a BannerSwitcher rather than returned
        // conditionally, so a banner that goes away collapses instead of
        // vanishing in one frame. The alert banner is the case that matters
        // most: a reading returning to range used to drop the whole Overview
        // down a card-height with no transition, which reads as a glitch.
        if (failed) {
          return ConnectionStatusBannerSwitcher(
            failed: true,
            staleNames: stale,
            health: _connectionHealth.health,
            lastSuccessfulAt: _lastSuccessfulTelemetryAt,
            errorMessage: _error,
            isDark: isDark,
            visible: true,
            onRetry: _fetchAll,
          );
        }
        if (offline) {
          return _bindRevision(
            _liveRevision,
            isDark,
            () => BannerSwitcher(
              visible: true,
              identity: 'offline:${_cachedTelemetryTime ?? ''}',
              bottomSpacing: 8,
              builder: () => OfflineBanner(
                cacheTime: _cachedTelemetryTime,
                onRetry: _fetchAll,
              ),
            ),
          );
        }
        if (showAlerts) {
          return _bindRevision(
            _alertMessages,
            isDark,
            () => BannerSwitcher(
              visible: alerts.isNotEmpty,
              // The identity is the set of messages, so a *change* of alarm
              // cross-fades the text rather than only resizing the box.
              identity: alerts.join('|'),
              builder: () => EnergyAlertBanner(messages: alerts),
            ),
          );
        }
        if (stale.isNotEmpty) {
          return ConnectionStatusBannerSwitcher(
            failed: false,
            staleNames: stale,
            health: _connectionHealth.health,
            lastSuccessfulAt: _lastSuccessfulTelemetryAt,
            errorMessage: null,
            isDark: isDark,
            visible: true,
            onRetry: _fetchAll,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Feeds the same readings the rule engine uses, so the banner and the alarms
  /// can never disagree about which devices stopped reporting.
  List<String> _staleDeviceNames() => staleDeviceNames(
    readings: _alarmReadings,
    staleMinutes: _staleTelemetryMinutes,
  );



  // ── Overview page ────────────────────────────────────────────────────────────
  List<Widget Function()> _overviewPage(bool isDark) {
    return [
      () => GreetingHeader(displayName: _displayName, isDark: isDark),
      () => const SizedBox(height: 8),
      () => _dateStrip(isDark),
      () => const SizedBox(height: 8),
      () => _bindRevision(_liveRevision, isDark, () => _heroCard(isDark)),
      () => const SizedBox(height: 8),
      () => _bindRevision(_energyRevision, isDark, () => _energySummaryCard(isDark)),
      () => const SizedBox(height: 8),
      () => _bindRevision(_liveRevision, isDark, () => _dualCards(isDark)),
      // The environment grid used to sit here. It moved to the Hydroponics page,
      // where it belongs with the camera looking at the same greenhouse, and
      // Overview is now only what the power system is doing. The readings did not
      // change and the limits did not change, so the alarms are unaffected.
    ];
  }

  Widget _dateStrip(bool isDark) {
    return DateStrip(
      days: _stripDays,
      selectedDate: _selectedDate,
      rangeStart: _selectedRangeStart,
      rangeEnd: _selectedRangeEnd,
      isDark: isDark,
      accentColor: strongMetricColor(
        seedColor: _seedColor,
        index: 0,
        isDark: isDark,
      ),
      performanceMode: _performanceMode,
      onSelectDate: _selectDate,
      onPickRange: _pickDateFromCalendar,
    );
  }

  Widget _heroCard(bool isDark) {
    return LivePowerCard(
      pvPower: _pzem?.latestValues['power_dc'],
      acPower: _pzem?.latestValues['power_ac'] ?? 0.0,
      // Read from the BMS's own `power` key, not multiplied out from voltage and
      // current. The device reports all three, and deriving it produced two
      // separate wrong answers: the product collapses to 0 whenever current reads
      // 0.00 A, which the BMS does report while idle, and it drifts from the
      // reported figure whenever the pack is not at its nominal voltage.
      //
      // Passed through raw, sign and all, so the figure matches the Battery page
      // one tab away. Negating it here to make the hero read "Charging 12 W" was
      // tried and reverted: two screens reporting different numbers for one
      // measurement is worse than an odd-looking minus, because the reader has to
      // work out that a minus became a plus.
      //
      // Which sign means which direction is decided by the observed state-of-charge
      // trend, not by this comment, and it has been opposite twice on two BMSes.
      // `batteryChargeState` owns it and is pinned by a test; see
      // `lib/utils/battery_sign.dart`. `energy_forecast_service.dart` documents the
      // same vendor disagreement behind a warning to use `.abs()` where only the
      // magnitude matters.
      batteryPower: _battery?.latestValues['power'] ?? 0.0,
      soc: _battery?.latestValues['soc'] ?? 0.0,
      pzemStale: _pzem?.isStale(minutes: _staleTelemetryMinutes) ?? true,
      pzemAgeLabel: _pzem?.ageLabel,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
    );
  }

  Widget _energySummaryCard(bool isDark) {
    return EnergySummaryCard(
      seedColor: _seedColor,
      isDark: isDark,
      performanceMode: _performanceMode,
      weekly: _weeklyEnergySummary,
      loading: _energyLoading,
      hasData:
          (_energyHistory['power_dc']?.isNotEmpty ?? false) ||
          (_energyHistory['power_ac']?.isNotEmpty ?? false),
      errorMessage: _energyError,
      solarKwh: _solarKwh,
      previousSolarKwh: _previousSolarKwh,
      loadKwh: _loadKwh,
      previousLoadKwh: _previousLoadKwh,
      forecast: _energyForecastService.calculate(
        history: _energyHistory,
        latest: {...?_battery?.latestValues, ...?_pzem?.latestValues},
        dailyProductionTargetKwh: _dailyProductionTargetKwh,
        referenceDate: DateTime.now(),
      ),
      onRangeChanged: _setWeeklyEnergySummary,
      onOpenReport: _openEnergyReport,
    );
  }

  Widget _dualCards(bool isDark) {
    return SystemStatusStrip(
      lowSocThreshold: _thresholds.lowSoc,
      activeAlerts: _activeAlertIds.length,
      battery: (
        soc: _battery?.latestValues['soc'] ?? 0.0,
        voltage: _battery?.latestValues['voltage'] ?? 0.0,
        current: _battery?.latestValues['current'] ?? 0.0,
        // The same key the hero card reads, so the two cannot disagree about
        // which way the pack is moving.
        power: _battery?.latestValues['power'] ?? 0.0,
      ),
      ac: (
        voltage: _pzem?.latestValues['voltage_ac'] ?? 0.0,
        current: _pzem?.latestValues['current_ac'] ?? 0.0,
        power: _pzem?.latestValues['power_ac'] ?? 0.0,
        frequency: _pzem?.latestValues['frequency_ac'] ?? 0.0,
      ),
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
      onOpenBattery: _openBatteryFromStrip,
    );
  }

  Widget _environmentGrid(bool isDark) {
    return MetricGrid(
      title: 'Environment',
      specs: kEnvironmentSpecs,
      values: _sensor?.latestValues,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
      // The grid grades each reading against the same thresholds the alarms use,
      // so a number on screen always has something to be read against.
      thresholds: _thresholds,
      limitLabelFor: (spec) => environmentLimitLabel(spec, _thresholds),
      staleMinutes: _staleTelemetryMinutes,
      lastUpdate: _sensor?.lastUpdate,
      // The alerts toggle governs the grid's warning colours too, not just the
      // background rules — a limit the user switched off must stop colouring the
      // page, or Settings and the dashboard contradict each other.
      showGridColors: _thresholds.environmentAlerts,
    );
  }

  Widget _fishGrid(bool isDark) {
    return MetricGrid(
      title: 'Water Quality',
      specs: kFishSpecs,
      values: _fish?.latestValues,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
      // Fish thresholds now exist (pH, water temperature, turbidity), so the
      // grid grades these readings against them exactly as the environment grid
      // does — the background alarm and the page the reading lives on must not
      // disagree about what the limit is.
      thresholds: _thresholds,
      limitLabelFor: (spec) => environmentLimitLabel(spec, _thresholds),
      showGridColors: _thresholds.fishAlerts,
      // The readings still get the stale tag, so a dead sensor cannot present a
      // page of plausible numbers as current.
      staleMinutes: _staleTelemetryMinutes,
      lastUpdate: _fish?.lastUpdate,
      // Two columns, so four readings land as 2 + 2. Three would leave the fourth
      // stranded beside a gap.
      columns: 2,
    );
  }

  // ── Detail pages ─────────────────────────────────────────────────────────────
  // ── Power page ───────────────────────────────────────────────────────────────
  /// PV, AC and Battery behind one tab, chosen with a segmented control.
  ///
  /// The selector is a `ValueListenableBuilder` over [_powerSubNotifier] rather
  /// than screen `setState`, and that is the whole reason the switch feels
  /// immediate. Measured on the device: a screen-level `setState` here cost
  /// 14-20 ms to the next frame against an 8.33 ms budget at 120 Hz, because
  /// rebuilding the screen repaints `AmbientBackground` and the blurred app bar
  /// and re-runs every cached page's closure list — none of which have anything to
  /// do with which sub-view is selected. Same pattern the nav bar already uses for
  /// [_selectedPage].
  List<Widget Function()> _powerPage(bool isDark) {
    return [
      () => ValueListenableBuilder<int>(
        valueListenable: _powerSubNotifier,
        builder: (context, sub, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _powerSelector(isDark, sub),
            const SizedBox(height: 12),
            // The page builders hand back lazily-invoked closures so the outer
            // ListView only realises visible items. Inside this one Column they
            // are invoked instead, which costs nothing measurable: the expensive
            // child is the chart, and that is a `Bound` whose child is cached and
            // only rebuilt when the chart revision actually bumps.
            ...switch (sub) {
              0 => _pvPage(isDark),
              1 => _acPage(isDark),
              _ => _batteryPage(isDark),
            }.map((make) => make()),
          ],
        ),
      ),
    ];
  }

  Widget _powerSelector(bool isDark, int selected) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: [
          for (final tab in kPowerSubTabs)
            ButtonSegment<int>(
              value: kPowerSubTabs.indexOf(tab),
              icon: Icon(tab.icon, size: 16),
              label: Text(tab.label),
            ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => _selectPowerSub(selection.first),
      ),
    );
  }

  void _selectPowerSub(int index) {
    if (index == _powerSubNotifier.value) return;
    _powerSubNotifier.value = index;
    // No cache invalidation. An earlier version removed the incoming prefix from
    // `_historyLoaded` to force a refetch, which had the opposite of the intended
    // effect: every tap re-requested the history and blanked the chart while it was
    // in flight. `_fetchHistoryFor` returns early when it already holds this
    // selection's data, and a date change still clears everything.
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix == null) return;
    unawaited(_fetchHistoryFor(prefix));
  }

  List<Widget Function()> _pvPage(bool isDark) => [
    () => GlassPageHeader(
      title: 'PV Status',
      icon: Icons.wb_sunny,
      accent: strongMetricColor(
        seedColor: _seedColor,
        index: 0,
        isDark: isDark,
      ),
      isDark: isDark,
    ),
    () => const SizedBox(height: 10),
    () => _bindRevision(
      _pzemRevision,
      isDark,
      () => _telemetryCard(
        _pzem,
        isDark,
        const [
          MetricDef('voltage_dc', 'Voltage DC', 'V', Icons.bolt),
          MetricDef('current_dc', 'Current DC', 'A', Icons.swap_horiz),
          MetricDef('power_dc', 'Power DC', 'W', Icons.wb_sunny),
          MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
        ],
      ),
    ),
    () => const SizedBox(height: 16),
    () => _chartSectionHeader('PV', 'pv', isDark),
    () => const SizedBox(height: 8),
    () => _bindRevision(
      _chartRevision,
      isDark,
      () => _chartCard('pv', isDark),
    ),
  ];

  List<Widget Function()> _acPage(bool isDark) => [
    () => GlassPageHeader(
      title: 'AC Status',
      icon: Icons.power,
      accent: strongMetricColor(
        seedColor: _seedColor,
        index: 1,
        isDark: isDark,
      ),
      isDark: isDark,
    ),
    () => const SizedBox(height: 10),
    () => _bindRevision(
      _pzemRevision,
      isDark,
      () => _telemetryCard(
        _pzem,
        isDark,
        const [
          MetricDef('voltage_ac', 'Voltage AC', 'V', Icons.bolt),
          MetricDef('current_ac', 'Current AC', 'A', Icons.swap_horiz),
          MetricDef('power_ac', 'Power AC', 'W', Icons.power, decimals: 1),
          MetricDef('frequency_ac', 'Frequency', 'Hz', Icons.graphic_eq, decimals: 1),
          MetricDef('energy_ac', 'Energy', 'kWh', Icons.bar_chart),
          MetricDef('pf_ac', 'Power Factor', '', Icons.electric_meter),
        ],
      ),
    ),
    () => const SizedBox(height: 16),
    () => _chartSectionHeader('AC', 'ac', isDark),
    () => const SizedBox(height: 8),
    () => _bindRevision(
      _chartRevision,
      isDark,
      () => _chartCard('ac', isDark),
    ),
  ];

  List<Widget Function()> _batteryPage(bool isDark) => [
    () => GlassPageHeader(
      title: 'Battery Status',
      icon: Icons.battery_charging_full,
      accent: strongMetricColor(
        seedColor: _seedColor,
        index: 2,
        isDark: isDark,
      ),
      isDark: isDark,
    ),
    () => const SizedBox(height: 10),
    () => _bindRevision(
      _batteryRevision,
      isDark,
      () => _telemetryCard(
        _battery,
        isDark,
        const [
          MetricDef('voltage', 'Voltage', 'V', Icons.bolt),
          MetricDef('current', 'Current', 'A', Icons.swap_horiz),
          MetricDef('power', 'Power', 'W', Icons.bolt_outlined, decimals: 1),
          MetricDef('soc', 'State of Charge', '%', Icons.battery_charging_full, decimals: 0),
          MetricDef('cycles', 'Cycles', '', Icons.refresh, decimals: 0),
          MetricDef(
            'remain_capacity_ah',
            'Remaining Capacity',
            'Ah',
            Icons.battery_3_bar,
            decimals: 1,
          ),
          // The full capacity was already being fetched and displayed nowhere.
          // A remaining charge with no reference to the original size is just a
          // number, so the pack size goes next to it.
          MetricDef('full_capacity_ah', 'Full Capacity', 'Ah', Icons.battery_full, decimals: 0),
        ],
      ),
    ),
    () => const SizedBox(height: 16),
    () => _chartSectionHeader('Battery', 'battery', isDark),
    () => const SizedBox(height: 8),
    () => _bindRevision(
      _chartRevision,
      isDark,
      () => _chartCard('battery', isDark),
    ),
  ];

  // ── Hydroponics page ──────────────────────────────────────────────────────────
  /// The greenhouse sensors plus the camera that was previously a tab of its own.
  ///
  /// No chart: `_prefixForPage` returns null for this page, so no history request
  /// is made and the chart section is absent entirely rather than empty. Adding
  /// one later means generalising TelemetryChartCard off its fixed
  /// voltage/current/power series, not just adding a case here.
  List<Widget Function()> _hydroponicsPage(bool isDark) {
    return [
      () => GlassPageHeader(
        title: 'Hydroponics',
        icon: Icons.eco,
        accent: strongMetricColor(
          seedColor: _seedColor,
          index: 0,
          isDark: isDark,
        ),
        isDark: isDark,
      ),
      () => const SizedBox(height: 10),
      () => _bindRevision(
        _sensorRevision,
        isDark,
        () => _environmentGrid(isDark),
      ),
      () => const SizedBox(height: 8),
      () => Bound(
        listenable: _cctvKeepAlive,
        token: _cctvUrl,
        builder: () => CctvScreen(streamUrl: _cctvUrl),
      ),
    ];
  }

  // ── Fish page ─────────────────────────────────────────────────────────────────
  /// Water quality for the fish tank, plus the second camera.
  ///
  /// The metric list mirrors ThingsBoardApi.fishKeys exactly. `turbidity_keruh`
  /// and `turbidity_voltage` are intentionally not here: the first is a boolean
  /// the numeric parser would flatten to a confident 0, the second is the
  /// sensor's own supply rail.
  List<Widget Function()> _fishPage(bool isDark) {
    return [
      () => GlassPageHeader(
        title: 'Fish Tank',
        icon: Icons.set_meal,
        accent: strongMetricColor(
          seedColor: _seedColor,
          index: 0,
          isDark: isDark,
        ),
        isDark: isDark,
      ),
      () => const SizedBox(height: 10),
      () => _bindRevision(_fishRevision, isDark, () => _fishGrid(isDark)),
      () => const SizedBox(height: 8),
      () => Bound(
        listenable: _cctvKeepAlive,
        token: _cctvUrlFish,
        builder: () => CctvScreen(streamUrl: _cctvUrlFish),
      ),
    ];
  }

  Widget _telemetryCard(
    DeviceTelemetry? data,
    bool isDark,
    List<MetricDef> metrics,
  ) {
    return TelemetryCard(
      data: data,
      metrics: metrics,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
      staleMinutes: _staleTelemetryMinutes,
    );
  }

  Widget _chartSectionHeader(String title, String prefix, bool isDark) {
    // A notifier rather than reading the set directly: adding or removing a prefix
    // from `_historyRequestInFlight` mutates a plain Set, which rebuilds nothing.
    return ValueListenableBuilder<int>(
      valueListenable: _historyBusyNotifier,
      builder: (context, _, _) => ChartSectionHeader(
        title: title,
        isDark: isDark,
        selectedDate: _selectedDate,
        rangeStart: _selectedRangeStart,
        rangeEnd: _selectedRangeEnd,
        realtimeConnected: _realtimeConnected,
        seedColor: _seedColor,
        onPickRange: _pickDateFromCalendar,
        refreshing: _historyRequestInFlight.contains(prefix),
      ),
    );
  }

  Widget _chartCard(String prefix, bool isDark) {
    return TelemetryChartCard(
      prefix: prefix,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
      points: _history,
      spots: _chartSpots,
      stats: _chartStats,
      boundsCache: _chartBounds,
      loading: _chartLoading,
      selectedDate: _selectedDate,
      rangeStart: _selectedRangeStart,
      rangeEnd: _selectedRangeEnd,
      onPointerActive: _setChartPointerActive,
    );
  }
}
