import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry_model.dart';
import '../services/thingsboard_api.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/brand_logo.dart';
import 'cctv_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class _SectionTheme {
  final Color bg;
  final Color fg;
  final Color accent;
  const _SectionTheme(this.bg, this.fg, this.accent);
}

const _batteryThemeDark = _SectionTheme(
  Color(0xFF173A35),
  Color(0xFF8CE8D0),
  Color(0xFF48D7B4),
);
const _pvThemeDark = _SectionTheme(
  Color(0xFF26382D),
  Color(0xFFFFD166),
  Color(0xFFF59E0B),
);
const _acThemeDark = _SectionTheme(
  Color(0xFF3E2A20),
  Color(0xFFFFB991),
  Color(0xFFFF8552),
);
const _envThemeDark = _SectionTheme(
  Color(0xFF19354A),
  Color(0xFFA7D8FF),
  Color(0xFF65B9F4),
);

const _batteryThemeLight = _SectionTheme(
  Color(0xFFE3F7EE),
  Color(0xFF0F614C),
  Color(0xFF109B7A),
);
const _pvThemeLight = _SectionTheme(
  Color(0xFFFFF7DD),
  Color(0xFF875B00),
  Color(0xFFD97706),
);
const _acThemeLight = _SectionTheme(
  Color(0xFFFFEEE5),
  Color(0xFF943E19),
  Color(0xFFE0531C),
);
const _envThemeLight = _SectionTheme(
  Color(0xFFE6F3FB),
  Color(0xFF145C8F),
  Color(0xFF2585C4),
);

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
  final _pageController = PageController();
  DeviceTelemetry? _battery;
  DeviceTelemetry? _pzem;
  DeviceTelemetry? _sensor;
  final Map<String, List<TelemetryPoint>> _history = {};
  final _chartBounds = <String, _ChartBounds>{};
  int _selectedIndex = 0;
  bool _loading = true;
  bool _chartLoading = true;
  bool _chartPointerActive = false;
  bool _telemetryRequestInFlight = false;
  final _historyRequestInFlight = <String>{};
  final _historyLoaded = <String>{};
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  String _cctvUrl = defaultCctvUrl;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAll();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoRefresh = preferences.getBool('auto_refresh') ?? true;
      _refreshSeconds = preferences.getInt('refresh_seconds') ?? 10;
      _cctvUrl = preferences.getString('cctv_url') ?? defaultCctvUrl;
    });
    _restartRefreshTimer();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
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
      setState(() {
        _battery = results[0];
        _pzem = results[1];
        _sensor = results[2];
        _loading = false;
        _error = null;
      });
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
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    } finally {
      _telemetryRequestInFlight = false;
    }
  }

  Future<void> _refreshCurrentPage() async {
    await _fetchAll();
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix == null) return;
    _historyLoaded.remove(prefix);
    await _fetchHistoryFor(prefix);
  }

  Future<void> _fetchHistoryFor(String prefix) async {
    if (_historyRequestInFlight.contains(prefix)) return;
    _historyRequestInFlight.add(prefix);
    if (mounted && !_historyLoaded.contains(prefix)) {
      setState(() => _chartLoading = true);
    }
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 24));
    final keys = switch (prefix) {
      'pv' => ('voltage_dc', 'current_dc', 'power_dc'),
      'ac' => ('voltage_ac', 'current_ac', 'power_ac'),
      _ => ('voltage', 'current', 'power'),
    };
    final deviceId = prefix == 'battery'
        ? ThingsBoardApi.deviceBattery
        : ThingsBoardApi.devicePzem;
    final requests = <String, Future<List<TelemetryPoint>>>{
      '${prefix}_voltage': widget.api.fetchHistory(
        deviceId,
        keys.$1,
        start: start,
        end: now,
      ),
      '${prefix}_current': widget.api.fetchHistory(
        deviceId,
        keys.$2,
        start: start,
        end: now,
      ),
      '${prefix}_power': widget.api.fetchHistory(
        deviceId,
        keys.$3,
        start: start,
        end: now,
      ),
    };
    final results = await Future.wait(
      requests.entries.map((entry) async {
        try {
          return MapEntry(entry.key, await entry.value);
        } catch (_) {
          return MapEntry(entry.key, <TelemetryPoint>[]);
        }
      }),
    );
    if (mounted) {
      setState(() {
        _history.addAll(Map.fromEntries(results));
        _chartBounds.remove(prefix);
        _historyLoaded.add(prefix);
        _chartLoading = false;
      });
    }
    _historyRequestInFlight.remove(prefix);
  }

  String? _prefixForPage(int index) => switch (index) {
    1 => 'pv',
    2 => 'ac',
    3 => 'battery',
    _ => null,
  };

  _SectionTheme _sectionTheme(String type, bool isDark) {
    if (isDark) {
      return switch (type) {
        'battery' => _batteryThemeDark,
        'pv' => _pvThemeDark,
        'ac' => _acThemeDark,
        _ => _envThemeDark,
      };
    } else {
      return switch (type) {
        'battery' => _batteryThemeLight,
        'pv' => _pvThemeLight,
        'ac' => _acThemeLight,
        _ => _envThemeLight,
      };
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartRefreshTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
    }
  }

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
        builder: (_) => SettingsScreen(themeController: widget.themeController),
      ),
    );
    if (changed == true) _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandLogo(size: 32),
            const SizedBox(width: 10),
            Text(_pageTitle),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchAll,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'settings') _openSettings();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _battery == null
          ? _errorView()
          : PageView.builder(
              controller: _pageController,
              physics: _chartPointerActive
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
              itemCount: 5,
              onPageChanged: (index) {
                if (_selectedIndex != index) {
                  setState(() => _selectedIndex = index);
                }
                final prefix = _prefixForPage(index);
                if (prefix != null) unawaited(_fetchHistoryFor(prefix));
              },
              itemBuilder: (context, index) => RefreshIndicator(
                onRefresh: _refreshCurrentPage,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).padding.bottom + 104,
                  ),
                  children: [
                    if (_error != null) _warningBanner(),
                    ..._pageContentFor(index, isDark),
                  ],
                ),
              ),
            ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
            child: RepaintBoundary(
              child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x331F2422)
                    : const Color(0xF2FFFFFF),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white30 : const Color(0xFFD6DFD9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x55000000)
                        : const Color(0x18000000),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, constraints) {
                      final page = _pageController.hasClients
                          ? (_pageController.page ??
                                _selectedIndex.toDouble())
                          : _selectedIndex.toDouble();
                      final itemWidth = constraints.maxWidth / 5;
                      final indicatorLeft =
                          page.clamp(0.0, 4.0).toDouble() * itemWidth;
                      return Stack(
                        children: [
                          Positioned(
                            left: indicatorLeft + 2,
                            top: 0,
                            width: itemWidth - 4,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0x22FFFFFF)
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              _glassNavItem(
                                0,
                                Icons.dashboard_outlined,
                                Icons.dashboard,
                                'Overview',
                                page,
                                isDark,
                              ),
                              _glassNavItem(
                                1,
                                Icons.wb_sunny_outlined,
                                Icons.wb_sunny,
                                'PV',
                                page,
                                isDark,
                              ),
                              _glassNavItem(
                                2,
                                Icons.power_outlined,
                                Icons.power,
                                'AC',
                                page,
                                isDark,
                              ),
                              _glassNavItem(
                                3,
                                Icons.battery_5_bar_outlined,
                                Icons.battery_full,
                                'Battery',
                                page,
                                isDark,
                              ),
                              _glassNavItem(
                                4,
                                Icons.videocam_outlined,
                                Icons.videocam,
                                'CCTV',
                                page,
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
    double page,
    bool isDark,
  ) {
    final selected = page.round() == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final itemColor = selected
        ? primaryColor
        : (isDark ? Colors.white70 : const Color(0xFF556059));
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _selectPage(index),
          child: SizedBox(
            height: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: itemColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0,
                    color: itemColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _pageTitle => const [
    'EnerGrow',
    'PV Monitoring',
    'AC Monitoring',
    'Battery Monitoring',
    'CCTV Monitoring',
  ][_selectedIndex];

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> _pageContentFor(int index, bool isDark) {
    final pvTheme = _sectionTheme('pv', isDark);
    final acTheme = _sectionTheme('ac', isDark);
    final batteryTheme = _sectionTheme('battery', isDark);
    final envTheme = _sectionTheme('env', isDark);

    switch (index) {
      case 1:
        return _sourcePage('PV', _pzem, pvTheme, 'pv', isDark, [
          _MetricDef('voltage_dc', 'Voltage', 'V', Icons.bolt),
          _MetricDef('current_dc', 'Current', 'A', Icons.swap_horiz),
          _MetricDef('power_dc', 'Power', 'W', Icons.wb_sunny),
          _MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
        ]);
      case 2:
        return _sourcePage('AC', _pzem, acTheme, 'ac', isDark, [
          _MetricDef('voltage_ac', 'Voltage', 'V', Icons.bolt),
          _MetricDef('current_ac', 'Current', 'A', Icons.electrical_services),
          _MetricDef('power_ac', 'Power', 'W', Icons.power),
          _MetricDef('frequency_ac', 'Frequency', 'Hz', Icons.graphic_eq),
          _MetricDef('energy_ac', 'Energy', 'kWh', Icons.bar_chart),
        ]);
      case 3:
        return _sourcePage('Battery', _battery, batteryTheme, 'battery', isDark, [
          _MetricDef('voltage', 'Voltage', 'V', Icons.bolt),
          _MetricDef('current', 'Current', 'A', Icons.swap_horiz),
          _MetricDef('power', 'Power', 'W', Icons.bolt_outlined),
          _MetricDef(
            'soc',
            'State Of Charge',
            '%',
            Icons.battery_charging_full,
          ),
        ]);
      case 4:
        return [
          if (index == _selectedIndex)
            CctvScreen(streamUrl: _cctvUrl)
          else
            const SizedBox(height: 340),
        ];
      default:
        return [
          _sectionTitle('Live Energy Sources'),
          _summaryTile(
            'PV',
            _pzem,
            pvTheme,
            'power_dc',
            'W',
            Icons.wb_sunny,
            1,
          ),
          _summaryTile('AC', _pzem, acTheme, 'power_ac', 'W', Icons.power, 2),
          _summaryTile(
            'Battery',
            _battery,
            batteryTheme,
            'soc',
            '%',
            Icons.battery_full,
            3,
          ),
          _sectionTitle('Environment'),
          _telemetryCard(_sensor, envTheme, [
            _MetricDef(
              'temp_dht',
              'Ambient temperature',
              '°C',
              Icons.thermostat,
            ),
            _MetricDef('humidity_dht', 'Humidity', '%', Icons.water_drop),
            _MetricDef(
              'temp_ds18b20',
              'PV temperature',
              '°C',
              Icons.device_thermostat,
            ),
            _MetricDef('lux', 'Illuminance', 'lx', Icons.light_mode),
            _MetricDef('tds_ppm', 'TDS', 'ppm', Icons.science),
          ]),
        ];
    }
  }

  List<Widget> _sourcePage(
    String name,
    DeviceTelemetry? data,
    _SectionTheme theme,
    String prefix,
    bool isDark,
    List<_MetricDef> metrics,
  ) => [
    _sectionTitle('$name Status'),
    _telemetryCard(data, theme, metrics),
    _sectionTitle('$name · Last 24 Hours'),
    _chartCard(theme, prefix, isDark),
  ];

  Widget _summaryTile(
    String name,
    DeviceTelemetry? data,
    _SectionTheme theme,
    String key,
    String unit,
    IconData icon,
    int targetIndex,
  ) {
    final value = data?.latestValues[key];
    return Card(
      color: theme.bg,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _selectPage(targetIndex),
        leading: Icon(icon, color: theme.fg),
        title: Text(
          name,
          style: TextStyle(color: theme.fg, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          data?.ageLabel ?? 'No update received',
          style: TextStyle(color: theme.fg.withValues(alpha: .75)),
        ),
        trailing: Text(
          value == null ? '-- $unit' : '${value.toStringAsFixed(2)} $unit',
          style: TextStyle(
            color: theme.fg,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 42),
          const SizedBox(height: 12),
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

  Widget _warningBanner() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: MaterialBanner(
      padding: const EdgeInsets.all(12),
      content: const Text('Some data could not be updated.'),
      leading: const Icon(Icons.warning_amber),
      actions: [TextButton(onPressed: _fetchAll, child: const Text('Retry'))],
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(letterSpacing: 1.1),
    ),
  );

  Widget _telemetryCard(
    DeviceTelemetry? data,
    _SectionTheme theme,
    List<_MetricDef> metrics,
  ) {
    final stale = data?.isStale() ?? true;
    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (stale) _staleRow(theme, data),
          ...List.generate(metrics.length, (index) {
            final metric = metrics[index];
            final value = data?.latestValues[metric.key];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: index == metrics.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.fg.withValues(alpha: .15),
                        ),
                      ),
                    ),
              child: Row(
                children: [
                  Icon(metric.icon, size: 19, color: theme.fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metric.label,
                      style: TextStyle(color: theme.fg),
                    ),
                  ),
                  Text(
                    value == null
                        ? '-- ${metric.unit}'
                        : '${value.toStringAsFixed(2)} ${metric.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.fg,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _staleRow(_SectionTheme theme, DeviceTelemetry? data) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Icon(Icons.schedule, size: 15, color: theme.fg),
        const SizedBox(width: 6),
        Text(
          data?.ageLabel ?? 'No update received',
          style: TextStyle(fontSize: 12, color: theme.fg),
        ),
      ],
    ),
  );

  Widget _chartCard(_SectionTheme theme, String prefix, bool isDark) {
    final series = [
      _ChartSeries(
        'Voltage',
        'V',
        _history['${prefix}_voltage'] ?? [],
        prefix == 'pv'
            ? (isDark ? const Color(0xFF4DABF7) : const Color(0xFF1E70BF))
            : (isDark ? const Color(0xFF6FC7FF) : const Color(0xFF0284C7)),
      ),
      _ChartSeries(
        'Current',
        'A',
        _history['${prefix}_current'] ?? [],
        prefix == 'pv'
            ? (isDark ? const Color(0xFF2EC4B6) : const Color(0xFF0D9488))
            : (isDark ? const Color(0xFFFFC857) : const Color(0xFFD97706)),
      ),
      _ChartSeries('Power', 'W', _history['${prefix}_power'] ?? [], theme.accent),
    ];
    final bounds = _chartBounds.putIfAbsent(
      prefix,
      () => _ChartBounds.fromSeries(series),
    );
    final hasData = series.any((item) => item.points.isNotEmpty);
    return Container(
      height: 390,
      padding: const EdgeInsets.fromLTRB(12, 16, 18, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B211E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? null : Border.all(color: const Color(0xFFE2E8E4)),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
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
                              ? const Color(0x443A453F)
                              : const Color(0x18000000),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (_) => FlLine(
                          color: isDark
                              ? const Color(0x333A453F)
                              : const Color(0x10000000),
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
                            getTitlesWidget: (value, meta) => SideTitleWidget(
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
                            getTitlesWidget: (value, meta) => SideTitleWidget(
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
                            getTooltipItems: (touchedSpots) => touchedSpots
                                .map(
                                  (spot) => LineTooltipItem(
                                    '${_axisNumber(spot.y)} ${series[spot.barIndex].unit}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                                .toList(),
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
                                isCurved: true,
                                color: item.color,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                              ),
                            )
                            .toList(),
                      ),
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

  String _axisNumber(double value) {
    final formatted = value.toStringAsFixed(2);
    return formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _setChartPointerActive(bool active) {
    if (_chartPointerActive == active || !mounted) return;
    setState(() => _chartPointerActive = active);
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
            'Min ${_axisNumber(minimum)}  Max ${_axisNumber(maximum)} ${series.unit}',
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
}

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
