import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry_model.dart';
import '../services/thingsboard_api.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/energy_summary_card.dart';
import 'cctv_screen.dart';
import 'energy_report_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

// ── File-level accent colours & tint helpers ──────────────────────────────────

// ── Widget ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final ThingsBoardApi api;
  final AppThemeController themeController;
  const DashboardScreen({
    super.key,
    required this.api,
    required this.themeController,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // ── State fields ─────────────────────────────────────────────────────────────
  final _pageController = PageController();
  final ValueNotifier<int> _selectedPage = ValueNotifier(0);
  DeviceTelemetry? _battery;
  DeviceTelemetry? _pzem;
  DeviceTelemetry? _sensor;
  final Map<String, List<TelemetryPoint>> _history = {};
  final Map<String, List<TelemetryPoint>> _energyHistory = {};
  final _chartBounds = <String, _ChartBounds>{};
  int _selectedIndex = 0;
  bool _loading = true;
  bool _chartLoading = true;
  bool _energyLoading = true;
  String? _energyError;
  bool _weeklyEnergySummary = false;
  bool _energyRequestInFlight = false;
  bool _chartPointerActive = false;
  bool _telemetryRequestInFlight = false;
  final _historyRequestInFlight = <String>{};
  final _historyRequestDate = <String, DateTime>{};
  final _historyPendingRefresh = <String>{};
  final _historyLoaded = <String>{};
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  String _cctvUrl = defaultCctvUrl;
  String? _error;
  Timer? _refreshTimer;
  Timer? _connectionStatusTimer;
  bool _connectionStatusInitialized = false;
  bool _connectionStatusVisible = false;
  DateTime _selectedDate = DateTime.now();
  DateTime? _energyUpdatedAt;
  DateTime? _lastSuccessfulTelemetryAt;
  String _displayName = '';
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
  Set<String> _activeAlertIds = {};
  List<String> _activeAlertMessages = [];
  final ValueNotifier<double> _appBarBlurProgress = ValueNotifier(0);

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.themeController.addListener(_onThemeChanged);
    _fetchAll();
    _fetchEnergyHistory();
    _loadPreferences();
    _loadDisplayName();
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _selectedPage.dispose();
    _appBarBlurProgress.dispose();
    _refreshTimer?.cancel();
    _connectionStatusTimer?.cancel();
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

  // ── Theme helpers ─────────────────────────────────────────────────────────────
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  bool get _performanceMode => widget.themeController.performanceMode;

  Color _themeColor({required double lightness, double saturation = 0.62}) {
    final hsl = HSLColor.fromColor(widget.themeController.seedColor);
    return hsl
        .withSaturation(saturation.clamp(0.0, 1.0))
        .withLightness(lightness.clamp(0.0, 1.0))
        .toColor();
  }

  Color _metricColor(int index, bool isDark) {
    final base = HSLColor.fromColor(widget.themeController.seedColor);
    return base
        .withSaturation(isDark ? 0.64 : 0.72)
        .withLightness(isDark ? 0.68 : 0.40)
        .toColor();
  }

  Color _strongMetricColor(int index, bool isDark) {
    final base = HSLColor.fromColor(widget.themeController.seedColor);
    return base
        .withSaturation(isDark ? 0.78 : 0.86)
        .withLightness(isDark ? 0.64 : 0.36)
        .toColor();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final progress = ((notification.metrics.pixels - 4) / 44)
        .clamp(0.0, 1.0)
        .toDouble();
    if ((progress - _appBarBlurProgress.value).abs() >= 0.015) {
      _appBarBlurProgress.value = progress;
    }
    return false;
  }

  // ── Data loading ──────────────────────────────────────────────────────────────
  Future<void> _loadDisplayName() async {
    final name = await widget.api.fetchDisplayName();
    if (mounted) setState(() => _displayName = name);
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoRefresh = preferences.getBool('auto_refresh') ?? true;
      _refreshSeconds = preferences.getInt('refresh_seconds') ?? 10;
      _energyAlertsEnabled =
          preferences.getBool('energy_alerts_enabled') ?? true;
      _environmentAlertsEnabled =
          preferences.getBool('environment_alerts_enabled') ?? false;
      _lowSocThreshold = preferences.getInt('low_soc_threshold') ?? 20;
      _staleTelemetryMinutes =
          preferences.getInt('stale_telemetry_minutes') ?? 10;
      _environmentTempMin = double.tryParse(
        preferences.getString('environment_temp_min') ?? '',
      );
      _environmentTempMax = double.tryParse(
        preferences.getString('environment_temp_max') ?? '',
      );
      _environmentHumidityMin = double.tryParse(
        preferences.getString('environment_humidity_min') ?? '',
      );
      _environmentHumidityMax = double.tryParse(
        preferences.getString('environment_humidity_max') ?? '',
      );
      _environmentTdsMin = double.tryParse(
        preferences.getString('environment_tds_min') ?? '',
      );
      _environmentTdsMax = double.tryParse(
        preferences.getString('environment_tds_max') ?? '',
      );
      _cctvUrl = preferences.getString('cctv_url') ?? defaultCctvUrl;
    });
    _restartRefreshTimer();
    _evaluateEnergyAlerts();
  }

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshSeconds),
        (_) => _fetchAll(),
      );
    }
  }

  Future<void> _fetchAll() async {
    if (_telemetryRequestInFlight) return;
    _telemetryRequestInFlight = true;
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
      final changed =
          _loading ||
          _error != null ||
          !_sameTelemetry(_battery, results[0]) ||
          !_sameTelemetry(_pzem, results[1]) ||
          !_sameTelemetry(_sensor, results[2]);
      final timestampChanged =
          _lastSuccessfulTelemetryAt == null ||
          now.difference(_lastSuccessfulTelemetryAt!).inMinutes >= 1;
      _battery = results[0];
      _pzem = results[1];
      _sensor = results[2];
      _lastSuccessfulTelemetryAt = now;
      if (changed || timestampChanged) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      _evaluateEnergyAlerts();
      final lastEnergyUpdate = _energyUpdatedAt;
      if (lastEnergyUpdate == null ||
          DateTime.now().difference(lastEnergyUpdate).inMinutes >= 15) {
        unawaited(_fetchEnergyHistory());
      }
    } catch (error) {
      if (!mounted) return;
      if (error.toString().contains('Token expired')) {
        await widget.api.logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LoginScreen(themeController: widget.themeController),
          ),
          (_) => false,
        );
        return;
      }
      final message = error.toString();
      final statusChanged = !_connectionStatusInitialized || _error == null;
      _connectionStatusInitialized = true;
      if (statusChanged) _showConnectionStatus();
      if (_error != message || _loading) {
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    } finally {
      _telemetryRequestInFlight = false;
    }
  }

  Future<void> _refreshCurrentPage() async {
    await _fetchAll();
    if (_selectedIndex == 0) await _fetchEnergyHistory();
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix == null) return;
    _historyLoaded.remove(prefix);
    await _fetchHistoryFor(prefix);
  }

  Future<void> _fetchEnergyHistory() async {
    if (_energyRequestInFlight) return;
    _energyRequestInFlight = true;
    if (mounted && _energyHistory.isEmpty) {
      setState(() => _energyLoading = true);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 13, minutes: 15));
    try {
      final histories = await widget.api.fetchHistoryForKeys(
        ThingsBoardApi.devicePzem,
        const ['power_dc', 'power_ac'],
        start: start,
        end: now,
        intervalMs: 30 * 60 * 1000,
        limit: 1500,
      );
      if (!mounted) return;
      final hasHistory = histories.values.any((points) => points.isNotEmpty);
      final sortedHistories = {
        for (final entry in histories.entries)
          entry.key: List<TelemetryPoint>.of(entry.value)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      };
      setState(() {
        _energyHistory
          ..clear()
          ..addAll(sortedHistories);
        _energyLoading = false;
        _energyError = hasHistory ? null : 'ThingsBoard tidak mengirim histori power_dc/power_ac dalam 14 hari terakhir.';
        _energyUpdatedAt = now;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Energy summary history request failed: $error');
      setState(() {
        _energyLoading = false;
        _energyError =
            'Histori daya gagal dimuat. Tarik layar untuk mencoba lagi.';
      });
    } finally {
      _energyRequestInFlight = false;
    }
  }

  void _evaluateEnergyAlerts() {
    if (!_energyAlertsEnabled && !_environmentAlertsEnabled) {
      final changed = _activeAlertIds.isNotEmpty;
      _activeAlertIds = {};
      _activeAlertMessages = [];
      if (changed && mounted) setState(() {});
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
    final newMessages = alerts.entries
        .where((entry) => !_activeAlertIds.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    final changed =
        alerts.length != _activeAlertIds.length ||
        !alerts.keys.every(_activeAlertIds.contains) ||
        !_sameStrings(alerts.values.toList(), _activeAlertMessages);
    if (!changed) return;
    _activeAlertIds = alerts.keys.toSet();
    _activeAlertMessages = alerts.values.toList();
    if (newMessages.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(newMessages.join(' · '))));
      });
    }
    if (mounted) setState(() {});
  }

  void _showConnectionStatus() {
    _connectionStatusTimer?.cancel();
    if (mounted && !_connectionStatusVisible) {
      setState(() => _connectionStatusVisible = true);
    }
    _connectionStatusTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _connectionStatusVisible = false);
    });
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

  List<String> _staleDeviceNames() {
    final devices = <(String, DeviceTelemetry?)>[
      ('Baterai', _battery),
      ('PZEM', _pzem),
      ('Sensor lingkungan', _sensor),
    ];
    return devices
        .where(
          (entry) =>
              entry.$2 != null &&
              entry.$2!.isStale(minutes: _staleTelemetryMinutes),
        )
        .map((entry) => entry.$1)
        .toList();
  }

  String _formatClock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  bool _sameStrings(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }

  bool _sameTelemetry(DeviceTelemetry? first, DeviceTelemetry second) {
    if (first == null) return false;
    if (first.latestValues.length != second.latestValues.length) return false;
    for (final entry in second.latestValues.entries) {
      if (first.latestValues[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _setWeeklyEnergySummary(bool weekly) {
    if (_weeklyEnergySummary == weekly) return;
    setState(() => _weeklyEnergySummary = weekly);
  }

  double _energyForPeriod(String key, DateTime start, DateTime end) {
    final points = _energyHistory[key] ?? const <TelemetryPoint>[];
    var kwh = 0.0;
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final gapMs = current.timestamp
          .difference(previous.timestamp)
          .inMilliseconds;
      if (gapMs <= 0 || gapMs > 60 * 60 * 1000) continue;
      final left = previous.timestamp.isAfter(start)
          ? previous.timestamp
          : start;
      final right = current.timestamp.isBefore(end) ? current.timestamp : end;
      final durationMs = right.difference(left).inMilliseconds;
      if (durationMs <= 0) continue;
      final leftFraction =
          left.difference(previous.timestamp).inMilliseconds / gapMs;
      final rightFraction =
          right.difference(previous.timestamp).inMilliseconds / gapMs;
      final leftPower =
          previous.value + (current.value - previous.value) * leftFraction;
      final rightPower =
          previous.value + (current.value - previous.value) * rightFraction;
      final averageWatts = math
          .max(0.0, (leftPower + rightPower) / 2)
          .toDouble();
      kwh += averageWatts * durationMs / 3600000000;
    }
    return kwh;
  }

  ({double current, double previous}) _energyComparison(String key) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = _weeklyEnergySummary
        ? today.subtract(const Duration(days: 6))
        : today;
    final previousStart = _weeklyEnergySummary
        ? periodStart.subtract(const Duration(days: 7))
        : today.subtract(const Duration(days: 1));
    return (
      current: _energyForPeriod(key, periodStart, now),
      previous: _energyForPeriod(key, previousStart, periodStart),
    );
  }

  Future<void> _fetchHistoryFor(String prefix) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (_historyRequestInFlight.contains(prefix)) {
      if (_historyRequestDate[prefix] != selDay) {
        _historyPendingRefresh.add(prefix);
      }
      return;
    }
    _historyRequestInFlight.add(prefix);
    _historyRequestDate[prefix] = selDay;
    if (mounted && !_historyLoaded.contains(prefix)) {
      setState(() => _chartLoading = true);
    }
    DateTime start, end;
    if (selDay == today) {
      end = now;
      start = now.subtract(const Duration(hours: 24));
    } else {
      start = selDay;
      end = DateTime(selDay.year, selDay.month, selDay.day, 23, 59, 59);
    }
    final keys = switch (prefix) {
      'pv' => ('voltage_dc', 'current_dc', 'power_dc'),
      'ac' => ('voltage_ac', 'current_ac', 'power_ac'),
      _ => ('voltage', 'current', 'power'),
    };
    final deviceId = prefix == 'battery'
        ? ThingsBoardApi.deviceBattery
        : ThingsBoardApi.devicePzem;
    Map<String, List<TelemetryPoint>> histories;
    try {
      histories = await widget.api.fetchHistoryForKeys(
        deviceId,
        [keys.$1, keys.$2, keys.$3],
        start: start,
        end: end,
      );
    } catch (_) {
      histories = const {};
    }
    final currentDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (mounted && currentDay == selDay) {
      setState(() {
        _history['${prefix}_voltage'] = histories[keys.$1] ?? [];
        _history['${prefix}_current'] = histories[keys.$2] ?? [];
        _history['${prefix}_power'] = histories[keys.$3] ?? [];
        _chartBounds.remove(prefix);
        _historyLoaded.add(prefix);
        _chartLoading = false;
      });
    }
    _historyRequestInFlight.remove(prefix);
    _historyRequestDate.remove(prefix);
    if (_historyPendingRefresh.remove(prefix) &&
        _prefixForPage(_selectedIndex) == prefix) {
      unawaited(_fetchHistoryFor(prefix));
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────────
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
    if (_chartPointerActive == active || !mounted) return;
    setState(() => _chartPointerActive = active);
  }

  // ── Date strip ────────────────────────────────────────────────────────────────
  List<DateTime> get _stripDays {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  void _selectDate(DateTime date) {
    final sel = DateTime(date.year, date.month, date.day);
    final cur = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (sel == cur) return;
    setState(() {
      _selectedDate = date;
      _historyLoaded.clear();
      _chartBounds.clear();
    });
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today.subtract(const Duration(days: 6));
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final initialDate = selected.isBefore(firstDate)
        ? firstDate
        : selected.isAfter(today)
        ? today
        : selected;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
      locale: const Locale('id', 'ID'),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Pilih tanggal dalam 7 hari terakhir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null && mounted) _selectDate(picked);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(themeController: widget.themeController),
      ),
      (_) => false,
    );
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
    if (changed == true) _loadPreferences();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
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
            return ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 16 * progress,
                  sigmaY: 16 * progress,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.34 * progress),
                    border: Border(
                      bottom: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08 * progress),
                      ),
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
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
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: AmbientBackground(
        isDark: isDark,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null && _battery == null)
            ? _errorView()
            : PageView.builder(
                controller: _pageController,
                physics: _chartPointerActive
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: 5,
                onPageChanged: (index) {
                  _selectedIndex = index;
                  _selectedPage.value = index;
                  final prefix = _prefixForPage(index);
                  if (prefix != null) unawaited(_fetchHistoryFor(prefix));
                },
                itemBuilder: (context, index) => RepaintBoundary(
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
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          MediaQuery.of(context).padding.top +
                              kToolbarHeight -
                              6,
                          16,
                          MediaQuery.of(context).padding.bottom + 76,
                        ),
                        children: [
                          if (_battery != null || _error != null)
                            _animatedConnectionStatusBanner(),
                          if (_activeAlertMessages.isNotEmpty)
                            _energyAlertBanner(),
                          ..._pageContentFor(index, isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
      extendBody: true,
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _selectedPage,
        builder: (context, _, child) => _glassNavBar(isDark),
      ),
    );
  }

  // ── Bottom nav bar ────────────────────────────────────────────────────────────
  Widget _glassNavBar(bool isDark) {
    final page = _selectedIndex.toDouble();
    final primary = _strongMetricColor(_selectedIndex, isDark);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: RepaintBoundary(
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.40)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xEE101412)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  _navItem(
                    0,
                    Icons.dashboard_outlined,
                    Icons.dashboard,
                    'Ringkas',
                    page,
                    isDark,
                    primary,
                  ),
                  _navItem(
                    1,
                    Icons.wb_sunny_outlined,
                    Icons.wb_sunny,
                    'PV',
                    page,
                    isDark,
                    primary,
                  ),
                  _navItem(
                    2,
                    Icons.power_outlined,
                    Icons.power,
                    'AC',
                    page,
                    isDark,
                    primary,
                  ),
                  _navItem(
                    3,
                    Icons.battery_5_bar_outlined,
                    Icons.battery_full,
                    'Baterai',
                    page,
                    isDark,
                    primary,
                  ),
                  _navItem(
                    4,
                    Icons.videocam_outlined,
                    Icons.videocam,
                    'CCTV',
                    page,
                    isDark,
                    primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    double page,
    bool isDark,
    Color primary,
  ) {
    final selected = page.round() == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () => _selectPage(index),
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 64,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selected
                    ? Container(
                        key: ValueKey('sel_$index'),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          selectedIcon,
                          size: 22,
                          color: Colors.white,
                        ),
                      )
                    : Column(
                        key: ValueKey('unsel_$index'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: _metricColor(
                              index,
                              isDark,
                            ).withValues(alpha: 0.72),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9,
                              color: _metricColor(
                                index,
                                isDark,
                              ).withValues(alpha: 0.72),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Page content router ───────────────────────────────────────────────────────
  List<Widget> _pageContentFor(int index, bool isDark) {
    return switch (index) {
      1 => _pvPage(isDark),
      2 => _acPage(isDark),
      3 => _batteryPage(isDark),
      4 => [CctvScreen(streamUrl: _cctvUrl)],
      _ => _overviewPage(isDark),
    };
  }

  // ── Overview page ─────────────────────────────────────────────────────────────
  List<Widget> _overviewPage(bool isDark) {
    final primary = isDark ? Colors.white70 : Colors.black54;
    return [
      _greetingHeader(isDark, primary),
      const SizedBox(height: 16),
      _dateStrip(isDark),
      const SizedBox(height: 20),
      _heroCard(isDark),
      const SizedBox(height: 12),
      _energySummaryCard(isDark),
      const SizedBox(height: 12),
      _dualCards(isDark),
      const SizedBox(height: 12),
      _environmentGrid(isDark),
    ];
  }

  Widget _energySummaryCard(bool isDark) {
    final solar = _energyComparison('power_dc');
    final load = _energyComparison('power_ac');
    return EnergySummaryCard(
      isDark: isDark,
      performanceMode: _performanceMode,
      weekly: _weeklyEnergySummary,
      loading: _energyLoading,
      hasData:
          (_energyHistory['power_dc']?.isNotEmpty ?? false) ||
          (_energyHistory['power_ac']?.isNotEmpty ?? false),
      errorMessage: _energyError,
      solarKwh: solar.current,
      previousSolarKwh: solar.previous,
      loadKwh: load.current,
      previousLoadKwh: load.previous,
      onRangeChanged: _setWeeklyEnergySummary,
      onOpenReport: _openEnergyReport,
    );
  }

  void _openEnergyReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EnergyReportScreen(api: widget.api)),
    );
  }

  Widget _greetingHeader(bool isDark, Color primary) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Selamat Pagi'
        : now.hour < 15
        ? 'Selamat Siang'
        : now.hour < 18
        ? 'Selamat Sore'
        : 'Selamat Malam';
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.18),
            border: Border.all(color: primary.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/user_icon.png',
              fit: BoxFit.contain,
              color: primary,
              colorBlendMode: BlendMode.srcIn,
              semanticLabel: 'Profil pengguna',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting${_displayName.isNotEmpty ? ", $_displayName!" : "!"}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_dayNameFull(now.weekday)}, ${now.day} ${_monthName(now.month)} ${now.year}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateStrip(bool isDark) {
    final days = _stripDays;
    final first = days.first;
    final last = days.last;
    final dateRange = first.month == last.month
        ? '${first.day}–${last.day} ${_monthName(last.month)} ${last.year}'
        : '${first.day} ${_monthName(first.month)} – '
              '${last.day} ${_monthName(last.month)} ${last.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Pilih tanggal',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                onPressed: _pickDateFromCalendar,
                icon: Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dateRange,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '7 hari',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 6.0;
            final chipWidth =
                (constraints.maxWidth - gap * (days.length - 1)) / days.length;
            return Row(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: chipWidth,
                    child: GlassDateChip(
                      width: chipWidth,
                      dayName: _dayNameShort(days[i].weekday),
                      dayNumber: days[i].day,
                      isSelected:
                          days[i].year == _selectedDate.year &&
                          days[i].month == _selectedDate.month &&
                          days[i].day == _selectedDate.day,
                      isDark: isDark,
                      accentColor: _strongMetricColor(0, isDark),
                      onTap: () => _selectDate(days[i]),
                      performanceMode: _performanceMode,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _heroCard(bool isDark) {
    final pvPower = _pzem?.latestValues['power_dc'];
    final acPower = _pzem?.latestValues['power_ac'] ?? 0.0;
    final soc = _battery?.latestValues['soc'] ?? 0.0;
    final pzemStale = _pzem?.isStale(minutes: _staleTelemetryMinutes) ?? true;

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: _performanceMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                Icons.wb_sunny_rounded,
                size: 18,
                color: _metricColor(2, isDark),
              ),
              const SizedBox(width: 6),
              Text(
                'Live Active Power',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              if (pzemStale)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _pzem?.ageLabel ?? 'No update',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Value + gauge row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          pvPower == null ? '--' : pvPower.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'W',
                          style: TextStyle(
                            fontSize: 20,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PV Output',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              GlassCircularGauge(
                progress: soc / 100,
                centerLabel: '${soc.toStringAsFixed(0)}%',
                centerSubLabel: 'SOC',
                trackColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                progressColor: widget.themeController.seedColor,
                size: 90,
                strokeWidth: 9,
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Capsule trio
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _dashboardShortcut(
                    pageIndex: 1,
                    child: GlassCapsule(
                      label: 'PV Output',
                      value: pvPower?.toStringAsFixed(0) ?? '--',
                      unit: 'W',
                      accentColor: _themeColor(lightness: isDark ? 0.72 : 0.42),
                      progress: ((pvPower ?? 0) / 300).clamp(0.0, 1.0),
                      isDark: isDark,
                      performanceMode: _performanceMode,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dashboardShortcut(
                    pageIndex: 2,
                    child: GlassCapsule(
                      label: 'AC Load',
                      value: acPower.toStringAsFixed(0),
                      unit: 'W',
                      accentColor: _themeColor(
                        lightness: isDark ? 0.64 : 0.36,
                        saturation: 0.48,
                      ),
                      progress: (acPower / 2000).clamp(0.0, 1.0),
                      isDark: isDark,
                      performanceMode: _performanceMode,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dashboardShortcut(
                    pageIndex: 3,
                    child: GlassCapsule(
                      label: 'Battery',
                      value: soc.toStringAsFixed(0),
                      unit: '%',
                      accentColor: widget.themeController.seedColor,
                      progress: soc / 100,
                      isDark: isDark,
                      performanceMode: _performanceMode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dualCards(bool isDark) {
    final soc = _battery?.latestValues['soc'] ?? 0.0;
    final v = _battery?.latestValues['voltage'] ?? 0.0;
    final a = _battery?.latestValues['current'] ?? 0.0;
    final voltageAc = _pzem?.latestValues['voltage_ac'] ?? 0.0;
    final currentAc = _pzem?.latestValues['current_ac'] ?? 0.0;
    final powerAc = _pzem?.latestValues['power_ac'] ?? 0.0;
    final freqAc = _pzem?.latestValues['frequency_ac'] ?? 0.0;
    final isStable =
        (freqAc - 50).abs() < 2 && voltageAc > 200 && voltageAc < 240;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Battery detail card
          Expanded(
            child: _dashboardShortcut(
              pageIndex: 3,
              child: LiquidGlassCard(
                isDark: isDark,
                performanceMode: _performanceMode,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.battery_charging_full,
                          size: 14,
                          color: _metricColor(0, isDark),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Battery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GlassCircularGauge(
                      progress: soc / 100,
                      centerLabel: '${soc.toStringAsFixed(0)}%',
                      centerSubLabel: 'SOC',
                      trackColor: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.07),
                      progressColor: widget.themeController.seedColor,
                      size: 110,
                      strokeWidth: 11,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _miniMetric(
                          '${v.toStringAsFixed(1)} V',
                          'Voltage',
                          isDark,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                        _miniMetric(
                          '${a.toStringAsFixed(2)} A',
                          'Current',
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // AC status card
          Expanded(
            child: _dashboardShortcut(
              pageIndex: 2,
              child: LiquidGlassCard(
                isDark: isDark,
                performanceMode: _performanceMode,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.power,
                          size: 14,
                          color: _metricColor(2, isDark),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AC Grid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isStable
                                ? Colors.green.withValues(alpha: 0.18)
                                : Colors.red.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isStable ? 'Stable' : 'Unstable',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isStable ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _glassMetricRow(
                      'Voltage',
                      '${voltageAc.toStringAsFixed(1)} V',
                      isDark,
                    ),
                    _dividerLine(isDark),
                    _glassMetricRow(
                      'Current',
                      '${currentAc.toStringAsFixed(2)} A',
                      isDark,
                    ),
                    _dividerLine(isDark),
                    _glassMetricRow(
                      'Power',
                      '${powerAc.toStringAsFixed(0)} W',
                      isDark,
                    ),
                    _dividerLine(isDark),
                    _glassMetricRow(
                      'Frequency',
                      '${freqAc.toStringAsFixed(1)} Hz',
                      isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardShortcut({required int pageIndex, required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectPage(pageIndex),
      child: child,
    );
  }

  Widget _environmentGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Environment',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _envCard(
                'temp_dht',
                'Ambient Temp',
                '°C',
                Icons.thermostat,
                isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _envCard(
                'humidity_dht',
                'Humidity',
                '%',
                Icons.water_drop,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _envCard(
                'temp_ds18b20',
                'PV Temp',
                '°C',
                Icons.device_thermostat,
                isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _envCard(
                'lux',
                'Illuminance',
                'lx',
                Icons.light_mode,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _envCard('tds_ppm', 'TDS', 'ppm', Icons.science, isDark),
      ],
    );
  }

  Widget _envCard(
    String key,
    String label,
    String unit,
    IconData icon,
    bool isDark,
  ) {
    final value = _sensor?.latestValues[key];
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: _performanceMode,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _metricColor(3, isDark)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value == null ? '--' : value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Detail pages ──────────────────────────────────────────────────────────────
  List<Widget> _pvPage(bool isDark) => [
    _glassPageHeader(
      'PV Status',
      Icons.wb_sunny,
      _strongMetricColor(0, isDark),
      isDark,
    ),
    const SizedBox(height: 10),
    _glassTelemetryCard(_pzem, isDark, _metricColor(0, isDark), [
      _MetricDef('voltage_dc', 'Voltage', 'V', Icons.bolt),
      _MetricDef('current_dc', 'Current', 'A', Icons.swap_horiz),
      _MetricDef('power_dc', 'Power', 'W', Icons.wb_sunny),
      _MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
    ]),
    const SizedBox(height: 16),
    _chartSectionHeader('PV · Last 24 Hours', isDark),
    const SizedBox(height: 8),
    _glassChartCard('pv', isDark),
  ];

  List<Widget> _acPage(bool isDark) => [
    _glassPageHeader(
      'AC Status',
      Icons.power,
      _strongMetricColor(1, isDark),
      isDark,
    ),
    const SizedBox(height: 10),
    _glassTelemetryCard(_pzem, isDark, _metricColor(1, isDark), [
      _MetricDef('voltage_ac', 'Voltage', 'V', Icons.bolt),
      _MetricDef('current_ac', 'Current', 'A', Icons.swap_horiz),
      _MetricDef('power_ac', 'Power', 'W', Icons.power),
      _MetricDef('frequency_ac', 'Frequency', 'Hz', Icons.graphic_eq),
      _MetricDef('energy_ac', 'Energy', 'kWh', Icons.bar_chart),
      _MetricDef('pf_ac', 'Power Factor', '', Icons.electric_meter),
    ]),
    const SizedBox(height: 16),
    _chartSectionHeader('AC · Last 24 Hours', isDark),
    const SizedBox(height: 8),
    _glassChartCard('ac', isDark),
  ];

  List<Widget> _batteryPage(bool isDark) => [
    _glassPageHeader(
      'Battery Status',
      Icons.battery_charging_full,
      _strongMetricColor(2, isDark),
      isDark,
    ),
    const SizedBox(height: 10),
    _glassTelemetryCard(_battery, isDark, _metricColor(2, isDark), [
      _MetricDef('voltage', 'Voltage', 'V', Icons.bolt),
      _MetricDef('current', 'Current', 'A', Icons.swap_horiz),
      _MetricDef('power', 'Power', 'W', Icons.bolt_outlined),
      _MetricDef('soc', 'State of Charge', '%', Icons.battery_charging_full),
      _MetricDef('cycles', 'Cycles', '', Icons.refresh),
      _MetricDef(
        'remain_capacity_ah',
        'Remaining Capacity',
        'Ah',
        Icons.battery_3_bar,
      ),
    ]),
    const SizedBox(height: 16),
    _chartSectionHeader('Battery · Last 24 Hours', isDark),
    const SizedBox(height: 8),
    _glassChartCard('battery', isDark),
  ];

  // ── Component helpers ─────────────────────────────────────────────────────────
  Widget _glassPageHeader(
    String title,
    IconData icon,
    Color accent,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _chartSectionHeader(String title, bool isDark) {
    final sel = _selectedDate;
    final now = DateTime.now();
    final isToday =
        sel.year == now.year && sel.month == now.month && sel.day == now.day;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(width: 8),
        if (!isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.10),
            ),
            child: Text(
              '${sel.day}/${sel.month}/${sel.year}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
      ],
    );
  }

  Widget _glassTelemetryCard(
    DeviceTelemetry? data,
    bool isDark,
    Color accent,
    List<_MetricDef> metrics,
  ) {
    final stale = data?.isStale(minutes: _staleTelemetryMinutes) ?? true;
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: _performanceMode,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          if (stale)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 15,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data?.ageLabel ?? 'No update received',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ...List.generate(metrics.length, (index) {
            final metric = metrics[index];
            final value = data?.latestValues[metric.key];
            final displayValue = value == null
                ? (metric.unit.isEmpty ? '--' : '-- ${metric.unit}')
                : (metric.unit.isEmpty
                      ? value.toStringAsFixed(2)
                      : '${value.toStringAsFixed(2)} ${metric.unit}');
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        metric.icon,
                        size: 19,
                        color: _metricColor(index, isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          metric.label,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.87)
                                : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < metrics.length - 1)
                  Container(
                    height: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _glassChartCard(String prefix, bool isDark) {
    final series = [
      _ChartSeries(
        'Voltage',
        'V',
        _history['${prefix}_voltage'] ?? [],
        isDark ? const Color(0xFFFF5252) : const Color(0xFFE53935),
      ),
      _ChartSeries(
        'Current',
        'A',
        _history['${prefix}_current'] ?? [],
        isDark ? const Color(0xFF69F0AE) : const Color(0xFF43A047),
      ),
      _ChartSeries(
        'Power',
        'W',
        _history['${prefix}_power'] ?? [],
        isDark ? const Color(0xFF448AFF) : const Color(0xFF1E88E5),
      ),
    ];
    final bounds = _chartBounds.putIfAbsent(
      prefix,
      () => _ChartBounds.fromSeries(series),
    );
    final hasData = series.any((item) => item.points.isNotEmpty);

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: _performanceMode,
      height: 400,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: _chartLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
          ? const Center(child: Text('No historical data available'))
          : Column(
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: series
                      .map((item) => _legend(item, item.color))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => _setChartPointerActive(true),
                    onPointerUp: (_) => _setChartPointerActive(false),
                    onPointerCancel: (_) => _setChartPointerActive(false),
                    child: RepaintBoundary(
                      child: LineChart(
                        LineChartData(
                          minX: bounds.minX,
                          maxX: bounds.maxX,
                          minY: bounds.minY,
                          maxY: bounds.maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: bounds.chartInterval,
                            verticalInterval: bounds.timeInterval,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.08),
                              strokeWidth: 1,
                            ),
                            getDrawingVerticalLine: (_) => FlLine(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.black.withValues(alpha: 0.06),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 48,
                                interval: bounds.chartInterval,
                                getTitlesWidget: (value, meta) =>
                                    SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      space: 4,
                                      child: Text(
                                        _axisNumber(value),
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: isDark
                                              ? const Color(0xFFB7C4BD)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: bounds.timeInterval,
                                getTitlesWidget: (value, meta) =>
                                    SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      space: 6,
                                      child: SizedBox(
                                        width: 32,
                                        child: Text(
                                          _axisTime(value),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: isDark
                                                ? const Color(0xFFB7C4BD)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipRoundedRadius: 14,
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              tooltipMargin: 12,
                              maxContentWidth: 150,
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              tooltipBorder: BorderSide(
                                color: Colors.white.withValues(alpha: 0.24),
                                width: 1,
                              ),
                              getTooltipColor: (_) => isDark
                                  ? const Color(0xCC18211D)
                                  : const Color(0xD9FFFFFF),
                              getTooltipItems: (touchedSpots) {
                                if (touchedSpots.isEmpty) {
                                  return const [];
                                }
                                final time = _axisTime(touchedSpots.first.x);
                                final values = <String>[];
                                for (final spot in touchedSpots) {
                                  values.add(
                                    '${_axisNumber(spot.y)} ${series[spot.barIndex].unit}',
                                  );
                                }
                                final tooltip = LineTooltipItem(
                                  '$time\n${values.join('  ·  ')}',
                                  TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF17211C),
                                    fontSize: 11,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                                return List<LineTooltipItem?>.generate(
                                  touchedSpots.length,
                                  (index) => index == 0 ? tooltip : null,
                                );
                              },
                            ),
                          ),
                          lineBarsData: series
                              .map(
                                (item) => LineChartBarData(
                                  spots: item.points
                                      .map(
                                        (point) => FlSpot(
                                          point.timestamp.millisecondsSinceEpoch
                                              .toDouble(),
                                          point.value,
                                        ),
                                      )
                                      .toList(),
                                  isCurved: false,
                                  color: item.color,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                ),
                              )
                              .toList(),
                        ),
                        duration: Duration.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: series.map(_statistics).toList()),
              ],
            ),
    );
  }

  Widget _miniMetric(String value, String label, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _glassMetricRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine(bool isDark) {
    return Container(
      height: 0.5,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );
  }

  // ── Error / warning views ─────────────────────────────────────────────────────
  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
          const Text('Gagal mengambil telemetry dari ThingsBoard.'),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _fetchAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _connectionStatusBanner() {
    final failed = _error != null;
    final staleNames = _staleDeviceNames();
    final stale = !failed && staleNames.isNotEmpty;
    final color = failed
        ? Colors.deepOrange
        : stale
        ? Colors.orange.shade800
        : Colors.green;
    final lastUpdate = _lastSuccessfulTelemetryAt;
    final label = failed
        ? 'ThingsBoard gagal'
        : stale
        ? 'Terhubung · stale: ${staleNames.join(', ')}'
        : 'ThingsBoard terhubung';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: Tooltip(
          key: ValueKey('$failed:$stale:$label'),
          message: failed
              ? 'Fetch telemetry gagal. Periksa koneksi/server. ${_error ?? ''}'
              : 'Fetch sukses${lastUpdate == null ? '' : ' pukul ${_formatClock(lastUpdate)}'}${stale ? '. Data lama: ${staleNames.join(', ')}' : ''}',
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  failed ? Icons.cloud_off : Icons.cloud_done_outlined,
                  color: color,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (failed)
                  InkWell(
                    onTap: _fetchAll,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.refresh, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedConnectionStatusBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axis: Axis.vertical,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: _connectionStatusVisible
          ? KeyedSubtree(
              key: const ValueKey('connection-status-visible'),
              child: _connectionStatusBanner(),
            )
          : const SizedBox(
              key: ValueKey('connection-status-hidden'),
              width: double.infinity,
              height: 0,
            ),
    );
  }

  Widget _energyAlertBanner() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE66A45).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE66A45).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFFE66A45),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _activeAlertMessages
                  .map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(message),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Chart stat / legend helpers ───────────────────────────────────────────────
  String _axisNumber(double value) {
    final formatted = value.toStringAsFixed(2);
    return formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _axisTime(double value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _statistics(_ChartSeries series) {
    if (series.points.isEmpty) return const Expanded(child: SizedBox.shrink());
    final values = series.points.map((point) => point.value).toList();
    final latestPoint = series.points.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
    final average = values.reduce((a, b) => a + b) / values.length;
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${series.label} (${series.unit})',
            style: TextStyle(
              color: series.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Latest ${_axisNumber(latestPoint.value)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Avg ${_axisNumber(average)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Min ${_axisNumber(minimum)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Max ${_axisNumber(maximum)} ${series.unit}',
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _legend(_ChartSeries series, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '${series.label} (${series.unit})',
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );

  // ── Date / time name helpers ──────────────────────────────────────────────────
  String _dayNameShort(int weekday) => const [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ][(weekday - 1) % 7];

  String _dayNameFull(int weekday) => const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ][(weekday - 1) % 7];

  String _monthName(int month) => const [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ][month - 1];
}

// ── Data helpers ──────────────────────────────────────────────────────────────

class _MetricDef {
  final String key;
  final String label;
  final String unit;
  final IconData icon;
  _MetricDef(this.key, this.label, this.unit, this.icon);
}

class _ChartSeries {
  final String label;
  final String unit;
  final List<TelemetryPoint> points;
  final Color color;
  _ChartSeries(this.label, this.unit, this.points, this.color);
}

class _ChartBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double chartInterval;
  final double timeInterval;

  const _ChartBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.chartInterval,
    required this.timeInterval,
  });

  factory _ChartBounds.fromSeries(List<_ChartSeries> series) {
    final points = series.expand((item) => item.points).toList();
    if (points.isEmpty) {
      return const _ChartBounds(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        chartInterval: 1,
        timeInterval: 1,
      );
    }
    final xValues = points
        .map((point) => point.timestamp.millisecondsSinceEpoch.toDouble())
        .toList();
    final yValues = points.map((point) => point.value).toList();
    final minX = xValues.reduce((a, b) => a < b ? a : b);
    final maxX = xValues.reduce((a, b) => a > b ? a : b);
    final minimum = yValues.reduce((a, b) => a < b ? a : b);
    final maximum = yValues.reduce((a, b) => a > b ? a : b);
    final minY = minimum < 0 ? minimum * 1.1 : 0.0;
    final maxY = maximum <= 0 ? 1.0 : maximum * 1.1;
    final chartInterval = (maxY - minY) / 3;
    final timeInterval = (maxX - minX) / 3;
    return _ChartBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      chartInterval: chartInterval == 0 ? 1 : chartInterval,
      timeInterval: timeInterval == 0 ? 1 : timeInterval,
    );
  }
}
