import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_keys.dart';
import '../models/telemetry_model.dart';
import '../services/alarm_history_service.dart';
import '../services/alarm_notification_service.dart';
import '../services/cctv_url.dart';
import '../services/connection_health_service.dart';
import '../services/energy_forecast_service.dart';
import '../services/thingsboard_api.dart';
import '../services/thingsboard_realtime_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/energy_summary_card.dart';
import '../widgets/liquid_glass.dart';
import 'alarm_history_screen.dart';
import 'cctv_screen.dart';
import 'dashboard/charts/chart_data.dart';
import 'dashboard/utils/alarm_helpers.dart';
import 'dashboard/utils/bound.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/energy_helpers.dart';
import 'dashboard/utils/history_range.dart';
import 'dashboard/utils/telemetry_helpers.dart';
import 'dashboard/widgets/banners.dart';
import 'dashboard/widgets/chart_card.dart';
import 'dashboard/widgets/date_strip.dart';
import 'dashboard/widgets/dual_status_cards.dart';
import 'dashboard/widgets/environment_grid.dart';
import 'dashboard/widgets/greeting_header.dart';
import 'dashboard/widgets/live_power_card.dart';
import 'dashboard/widgets/nav_bar.dart';
import 'dashboard/widgets/telemetry_card.dart';
import 'dashboard/widgets/weather_card.dart';
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

  // ── Telemetry ────────────────────────────────────────────────────────────────
  DeviceTelemetry? _battery;
  DeviceTelemetry? _pzem;
  DeviceTelemetry? _sensor;
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
  bool _connectionStatusInitialized = false;
  final ValueNotifier<bool> _connectionStatusVisible = ValueNotifier(false);
  Timer? _connectionStatusTimer;
  late final Listenable _connectionChromeListenable = Listenable.merge([
    _liveRevision,
    _connectionStatusVisible,
    _connectionHealth,
  ]);

  // ── Alerts ───────────────────────────────────────────────────────────────────
  final _alarmHistoryService = AlarmHistoryService();
  final ValueNotifier<List<String>> _alertMessages = ValueNotifier(const []);
  Set<String> _activeAlertIds = {};
  bool _energyAlertsEnabled = true;
  bool _environmentAlertsEnabled = false;
  int _lowSocThreshold = 20;
  int _staleTelemetryMinutes = 10;
  double? _environmentTempMin;
  double? _environmentTempMax;
  double? _environmentHumidityMin;
  double? _environmentHumidityMax;
  double? _environmentTdsMin;
  double? _environmentTdsMax;

  // ── Misc ─────────────────────────────────────────────────────────────────────
  String _displayName = '';
  String _cctvUrl = defaultAllowedCctvUrl;
  final ValueNotifier<int> _cctvKeepAlive = ValueNotifier(0);
  final ValueNotifier<int> _liveRevision = ValueNotifier(0);
  final ValueNotifier<int> _energyRevision = ValueNotifier(0);
  final ValueNotifier<int> _chartRevision = ValueNotifier(0);
  final ValueNotifier<bool> _chartPointerActiveNotifier = ValueNotifier(false);

  // ── Weather ──────────────────────────────────────────────────────────────────
  final _weatherService = WeatherService();
  WeatherData? _currentWeather;
  WeatherForecast? _weatherForecast;
  bool _weatherLoading = false;
  String? _weatherError;

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
    _initializeWeatherService();
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _selectedPage.dispose();
    _navCollapsed.dispose();
    _appBarBlurProgress.dispose();
    _chartPointerActiveNotifier.dispose();
    _liveRevision.dispose();
    _energyRevision.dispose();
    _chartRevision.dispose();
    _connectionStatusVisible.dispose();
    _alertMessages.dispose();
    _cctvKeepAlive.dispose();
    _refreshTimer?.cancel();
    _connectionStatusTimer?.cancel();
    unawaited(_realtimeService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartRefreshTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
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
    setState(() {
      _autoRefresh =
          preferences.getBool(SettingsKeys.autoRefresh) ?? true;
      _refreshSeconds =
          preferences.getInt(SettingsKeys.refreshSeconds) ?? 10;
      _energyAlertsEnabled =
          preferences.getBool(SettingsKeys.energyAlertsEnabled) ?? true;
      _environmentAlertsEnabled =
          preferences.getBool(SettingsKeys.environmentAlertsEnabled) ?? false;
      _lowSocThreshold =
          preferences.getInt(SettingsKeys.lowSocThreshold) ?? 20;
      _staleTelemetryMinutes =
          preferences.getInt(SettingsKeys.staleTelemetryMinutes) ?? 10;
      _environmentTempMin = _readDouble(
        preferences,
        SettingsKeys.environmentTempMin,
      );
      _environmentTempMax = _readDouble(
        preferences,
        SettingsKeys.environmentTempMax,
      );
      _environmentHumidityMin = _readDouble(
        preferences,
        SettingsKeys.environmentHumidityMin,
      );
      _environmentHumidityMax = _readDouble(
        preferences,
        SettingsKeys.environmentHumidityMax,
      );
      _environmentTdsMin = _readDouble(
        preferences,
        SettingsKeys.environmentTdsMin,
      );
      _environmentTdsMax = _readDouble(
        preferences,
        SettingsKeys.environmentTdsMax,
      );
      _dailyProductionTargetKwh = _readDouble(
        preferences,
        SettingsKeys.dailyProductionTargetKwh,
      );
      _cctvUrl = cctvUrl;
    });
    _restartRefreshTimer();
    _evaluateEnergyAlerts();
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
    _connectionHealth.markConnecting(ConnectionTransport.rest);
    try {
      final results = await Future.wait([
        widget.api.fetchBatteryData(),
        widget.api.fetchPzemData(),
        widget.api.fetchSensorData(),
      ]);
      if (!mounted) return;
      final now = DateTime.now();
      final statusChanged = !_connectionStatusInitialized || _error != null;
      _connectionStatusInitialized = true;
      if (statusChanged) _showConnectionStatus();
      final wasLoading = _loading;
      final changed =
          _loading ||
          _error != null ||
          !sameTelemetry(_battery, results[0]) ||
          !sameTelemetry(_pzem, results[1]) ||
          !sameTelemetry(_sensor, results[2]);
      final timestampChanged =
          _lastSuccessfulTelemetryAt == null ||
          now.difference(_lastSuccessfulTelemetryAt!).inMinutes >= 1;
      _battery = results[0];
      _pzem = results[1];
      _sensor = results[2];
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
        await widget.api.logout();
        if (!mounted) return;
        _goToLogin();
        return;
      }
      await _applyOfflineFallback();
      final message = error.toString();
      final statusChanged = !_connectionStatusInitialized || _error == null;
      _connectionStatusInitialized = true;
      if (statusChanged) _showConnectionStatus();
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
    }

    final wasLoading = _loading;
    _connectionHealth.markSuccess(
      ConnectionTransport.webSocket,
      latency: DateTime.now().difference(values.values.first.timestamp),
      updatedAt: latest,
    );
    _isOfflineMode = false;
    _lastSuccessfulTelemetryAt = DateTime.now();
    _error = null;
    _loading = false;
    _notifyLive(wasLoading: wasLoading, changed: true);
    _evaluateEnergyAlerts();
  }

  static bool _isKnownDevice(String deviceId) =>
      deviceId == ThingsBoardApi.deviceBattery ||
      deviceId == ThingsBoardApi.devicePzem ||
      deviceId == ThingsBoardApi.deviceSensor;

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
    if (!_energyAlertsEnabled && !_environmentAlertsEnabled) {
      final hadAlerts = _activeAlertIds.isNotEmpty;
      _activeAlertIds = {};
      if (hadAlerts) _alertMessages.value = const [];
      return;
    }
    final alerts = <String, String>{};
    if (_energyAlertsEnabled) {
      final soc = _battery?.latestValues['soc'];
      if (soc != null && soc < _lowSocThreshold) {
        alerts['low_soc'] = 'SOC baterai rendah: ${soc.toStringAsFixed(0)}%';
      }
      final devices = <(String, String, DeviceTelemetry?)>[
        ('battery', 'Baterai', _battery),
        ('pzem', 'PZEM', _pzem),
        ('sensor', 'Sensor lingkungan', _sensor),
      ];
      for (final (id, name, telemetry) in devices) {
        if (telemetry != null &&
            telemetry.isStale(minutes: _staleTelemetryMinutes)) {
          alerts['stale_$id'] = 'Data $name belum diperbarui';
        }
      }
    }
    final sensor = _sensor;
    if (_environmentAlertsEnabled &&
        sensor != null &&
        !sensor.isStale(minutes: _staleTelemetryMinutes)) {
      _addRangeAlerts(
        alerts,
        id: 'ambient_temp',
        label: 'Suhu lingkungan',
        unit: '°C',
        value: sensor.latestValues['temp_dht'],
        minimum: _environmentTempMin,
        maximum: _environmentTempMax,
      );
      _addRangeAlerts(
        alerts,
        id: 'humidity',
        label: 'Kelembapan',
        unit: '%',
        value: sensor.latestValues['humidity_dht'],
        minimum: _environmentHumidityMin,
        maximum: _environmentHumidityMax,
      );
      _addRangeAlerts(
        alerts,
        id: 'tds',
        label: 'TDS',
        unit: 'ppm',
        value: sensor.latestValues['tds_ppm'],
        minimum: _environmentTdsMin,
        maximum: _environmentTdsMax,
      );
    }

    final newEntries = alerts.entries
        .where((entry) => !_activeAlertIds.contains(entry.key))
        .toList();
    final newMessages = newEntries.map((entry) => entry.value).toList();
    final nextMessages = alerts.values.toList();
    final changed =
        alerts.length != _activeAlertIds.length ||
        !alerts.keys.every(_activeAlertIds.contains) ||
        !sameStrings(nextMessages, _alertMessages.value);
    if (!changed) return;
    _activeAlertIds = alerts.keys.toSet();
    _alertMessages.value = nextMessages;

    if (newEntries.isNotEmpty) {
      final now = DateTime.now();
      for (final entry in newEntries) {
        _persistAlarm(entry.key, entry.value, now);
      }
    }
    if (newMessages.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(newMessages.join(' · '))));
      });
    }
  }

  void _addRangeAlerts(
    Map<String, String> alerts, {
    required String id,
    required String label,
    required String unit,
    required double? value,
    required double? minimum,
    required double? maximum,
  }) {
    if (value == null) return;
    if (minimum != null && value < minimum) {
      alerts['environment_${id}_low'] =
          '$label rendah: ${value.toStringAsFixed(1)} $unit (batas $minimum $unit)';
    }
    if (maximum != null && value > maximum) {
      alerts['environment_${id}_high'] =
          '$label tinggi: ${value.toStringAsFixed(1)} $unit (batas $maximum $unit)';
    }
  }

  void _persistAlarm(String id, String message, DateTime now) {
    final severity = alarmSeverityFromId(id);
    unawaited(
      _alarmHistoryService.addAlarm(
        AlarmRecord(
          id: '${now.millisecondsSinceEpoch}_$id',
          timestamp: now,
          type: alarmTypeFromId(id),
          severity: severity,
          message: message,
          value: alarmValueFromId(
            id,
            batteryValues: _battery?.latestValues,
            sensorValues: _sensor?.latestValues,
          ),
        ),
      ),
    );
    unawaited(
      AlarmNotificationService.notifyAlarm(
        id: id,
        title:
            'EnerGrow: ${severity == AlarmSeverity.critical ? 'Critical' : 'Warning'} alarm',
        message: message,
        critical: severity == AlarmSeverity.critical,
      ),
    );
  }

  void _showConnectionStatus() {
    _connectionStatusTimer?.cancel();
    if (mounted && !_connectionStatusVisible.value) {
      _connectionStatusVisible.value = true;
    }
    _connectionStatusTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _connectionStatusVisible.value = false;
    });
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
          : 'ThingsBoard tidak mengirim histori power_dc/power_ac dalam 14 hari terakhir.';
      _energyUpdatedAt = now;
      _notifyEnergy();
    } catch (error) {
      if (!mounted) return;
      debugPrint('Energy summary history request failed: $error');
      _energyLoading = false;
      _energyError =
          'Histori daya gagal dimuat. Tarik layar untuk mencoba lagi.';
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
    if (_historyRequestInFlight.contains(prefix)) {
      if (_historyRequestDate[prefix] != selectionKey) {
        _historyPendingRefresh.add(prefix);
      }
      return;
    }
    _historyRequestInFlight.add(prefix);
    _historyRequestDate[prefix] = selectionKey;
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
  String? _prefixForPage(int index) => switch (index) {
    1 => 'pv',
    2 => 'ac',
    3 => 'battery',
    _ => null,
  };

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
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih rentang tanggal telemetry',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
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
    await widget.api.logout();
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
      // The dashboard holds one long-lived weather service, so it has to be
      // told to pick up an API key or city that was just saved in Settings.
      await _weatherService.reloadStoredConfig();
      if (_weatherService.hasApiKey) {
        await _fetchWeather();
      }
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

  // ── Weather ──────────────────────────────────────────────────────────────────
  Future<void> _initializeWeatherService() async {
    await _weatherService.initialize();
    if (_weatherService.hasApiKey) {
      await _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    if (!_weatherService.hasApiKey) return;
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });
    try {
      final weather = await _weatherService.getCurrentWeather();
      final forecast = await _weatherService.getForecast();
      if (!mounted) return;
      setState(() {
        _currentWeather = weather;
        _weatherForecast = forecast;
        _weatherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherError = e.toString();
      });
    }
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
        tooltip: 'Muat ulang data',
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
          tooltip: 'Pengaturan',
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
    return ValueListenableBuilder<bool>(
      valueListenable: _chartPointerActiveNotifier,
      builder: (context, chartPointerActive, _) => PageView.builder(
        controller: _pageController,
        physics: chartPointerActive
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: 5,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) => _buildPage(index, isDark),
      ),
    );
  }

  void _onPageChanged(int index) {
    _selectedIndex = index;
    _selectedPage.value = index;
    final prefix = _prefixForPage(index);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
  }

  Widget _buildPage(int index, bool isDark) {
    final items = <Widget Function()>[
      _connectionStatusBannerBuilder,
      _offlineBannerBuilder,
      _energyAlertBannerBuilder,
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
              MediaQuery.of(context).padding.top + kToolbarHeight,
          onRefresh: _refreshCurrentPage,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight - 6,
              16,
              MediaQuery.of(context).padding.bottom + 76,
            ),
            itemCount: items.length,
            itemBuilder: (context, itemIndex) => items[itemIndex](),
          ),
        ),
      ),
    );
  }

  List<Widget Function()> _pageContentFor(int index, bool isDark) {
    return switch (index) {
      1 => _pvPage(isDark),
      2 => _acPage(isDark),
      3 => _batteryPage(isDark),
      4 => [
        () => Bound(
          listenable: _cctvKeepAlive,
          token: _cctvUrl,
          builder: () => CctvScreen(streamUrl: _cctvUrl),
        ),
      ],
      _ => _overviewPage(isDark),
    };
  }

  // ── Banners ──────────────────────────────────────────────────────────────────
  Object get _visualToken => Object.hash(
    _seedColor,
    _performanceMode,
    _selectedDate,
    _displayName,
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

  Widget _connectionStatusBannerBuilder() {
    return _bindRevision(
      _connectionChromeListenable,
      Theme.of(context).brightness == Brightness.dark,
      () => ConnectionStatusBannerSwitcher(
        visible: _connectionStatusVisible.value,
        builder: () => ConnectionStatusBanner(
          failed: _error != null,
          staleNames: _staleDeviceNames(),
          health: _connectionHealth.health,
          lastSuccessfulAt: _lastSuccessfulTelemetryAt,
          errorMessage: _error,
          isDark: Theme.of(context).brightness == Brightness.dark,
          onRetry: _fetchAll,
        ),
      ),
    );
  }

  List<String> _staleDeviceNames() => staleDeviceNames(
    batteryValues: _battery?.latestValues,
    batteryLastUpdate: _battery?.lastUpdate,
    pzemValues: _pzem?.latestValues,
    pzemLastUpdate: _pzem?.lastUpdate,
    sensorValues: _sensor?.latestValues,
    sensorLastUpdate: _sensor?.lastUpdate,
    staleMinutes: _staleTelemetryMinutes,
  );

  Widget _energyAlertBannerBuilder() {
    return _bindRevision(_alertMessages, true, () {
      final messages = _alertMessages.value;
      return messages.isEmpty
          ? const SizedBox.shrink()
          : EnergyAlertBanner(messages: messages);
    });
  }

  Widget _offlineBannerBuilder() {
    return _bindRevision(_liveRevision, true, () {
      if (!_isOfflineMode) return const SizedBox.shrink();
      return OfflineBanner(cacheTime: _cachedTelemetryTime, onRetry: _fetchAll);
    });
  }

  // ── Overview page ────────────────────────────────────────────────────────────
  List<Widget Function()> _overviewPage(bool isDark) {
    return [
      () => GreetingHeader(displayName: _displayName, isDark: isDark),
      () => const SizedBox(height: 16),
      () => _dateStrip(isDark),
      () => const SizedBox(height: 20),
      () => _bindRevision(_liveRevision, isDark, () => _heroCard(isDark)),
      () => const SizedBox(height: 12),
      () => WeatherCard(
        weather: _currentWeather,
        forecast: _weatherForecast,
        isDark: isDark,
        performanceMode: _performanceMode,
        onRefresh: _fetchWeather,
        onSettings: _openSettings,
        isLoading: _weatherLoading,
        error: _weatherError,
      ),
      () => const SizedBox(height: 12),
      () => _bindRevision(_energyRevision, isDark, () => _energySummaryCard(isDark)),
      () => const SizedBox(height: 12),
      () => _bindRevision(_liveRevision, isDark, () => _dualCards(isDark)),
      () => const SizedBox(height: 12),
      () => _bindRevision(_liveRevision, isDark, () => _environmentGrid(isDark)),
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
      soc: _battery?.latestValues['soc'] ?? 0.0,
      pzemStale: _pzem?.isStale(minutes: _staleTelemetryMinutes) ?? true,
      pzemAgeLabel: _pzem?.ageLabel,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
      onNavigate: _selectPage,
    );
  }

  Widget _energySummaryCard(bool isDark) {
    return EnergySummaryCard(
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
    return DualStatusCards(
      battery: (
        soc: _battery?.latestValues['soc'] ?? 0.0,
        voltage: _battery?.latestValues['voltage'] ?? 0.0,
        current: _battery?.latestValues['current'] ?? 0.0,
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
      onNavigate: _selectPage,
    );
  }

  Widget _environmentGrid(bool isDark) {
    return EnvironmentGrid(
      values: _sensor?.latestValues,
      isDark: isDark,
      seedColor: _seedColor,
      performanceMode: _performanceMode,
    );
  }

  // ── Detail pages ─────────────────────────────────────────────────────────────
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
      _liveRevision,
      isDark,
      () => _telemetryCard(
        _pzem,
        isDark,
        const [
          MetricDef('voltage_dc', 'Voltage', 'V', Icons.bolt),
          MetricDef('current_dc', 'Current', 'A', Icons.swap_horiz),
          MetricDef('power_dc', 'Power', 'W', Icons.wb_sunny),
          MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
        ],
      ),
    ),
    () => const SizedBox(height: 16),
    () => _chartSectionHeader('PV', isDark),
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
      _liveRevision,
      isDark,
      () => _telemetryCard(
        _pzem,
        isDark,
        const [
          MetricDef('voltage_ac', 'Voltage', 'V', Icons.bolt),
          MetricDef('current_ac', 'Current', 'A', Icons.swap_horiz),
          MetricDef('power_ac', 'Power', 'W', Icons.power),
          MetricDef('frequency_ac', 'Frequency', 'Hz', Icons.graphic_eq),
          MetricDef('energy_ac', 'Energy', 'kWh', Icons.bar_chart),
          MetricDef('pf_ac', 'Power Factor', '', Icons.electric_meter),
        ],
      ),
    ),
    () => const SizedBox(height: 16),
    () => _chartSectionHeader('AC', isDark),
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
      _liveRevision,
      isDark,
      () => _telemetryCard(
        _battery,
        isDark,
        const [
          MetricDef('voltage', 'Voltage', 'V', Icons.bolt),
          MetricDef('current', 'Current', 'A', Icons.swap_horiz),
          MetricDef('power', 'Power', 'W', Icons.bolt_outlined),
          MetricDef('soc', 'State of Charge', '%', Icons.battery_charging_full),
          MetricDef('cycles', 'Cycles', '', Icons.refresh),
          MetricDef(
            'remain_capacity_ah',
            'Remaining Capacity',
            'Ah',
            Icons.battery_3_bar,
          ),
        ],
      ),
    ),
    () => const SizedBox(height: 16),
    () => _chartSectionHeader('Battery', isDark),
    () => const SizedBox(height: 8),
    () => _bindRevision(
      _chartRevision,
      isDark,
      () => _chartCard('battery', isDark),
    ),
  ];

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

  Widget _chartSectionHeader(String title, bool isDark) {
    return ChartSectionHeader(
      title: title,
      isDark: isDark,
      selectedDate: _selectedDate,
      rangeStart: _selectedRangeStart,
      rangeEnd: _selectedRangeEnd,
      realtimeConnected: _realtimeConnected,
      onPickRange: _pickDateFromCalendar,
    );
  }

  Widget _chartCard(String prefix, bool isDark) {
    return TelemetryChartCard(
      prefix: prefix,
      isDark: isDark,
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
