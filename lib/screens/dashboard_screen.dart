import 'dart:async';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry_model.dart';
import '../services/thingsboard_api.dart';
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

const _batteryTheme = _SectionTheme(
  Color(0xFF173A35),
  Color(0xFF8CE8D0),
  Color(0xFF48D7B4),
);
const _pvTheme = _SectionTheme(
  Color(0xFF26382D),
  Color(0xFFFFD166),
  Color(0xFFF59E0B),
);
const _acTheme = _SectionTheme(
  Color(0xFF3E2A20),
  Color(0xFFFFB991),
  Color(0xFFFF8552),
);
const _envTheme = _SectionTheme(
  Color(0xFF19354A),
  Color(0xFFA7D8FF),
  Color(0xFF65B9F4),
);

class DashboardScreen extends StatefulWidget {
  final ThingsBoardApi api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DeviceTelemetry? _battery;
  DeviceTelemetry? _pzem;
  DeviceTelemetry? _sensor;
  final Map<String, List<TelemetryPoint>> _history = {};
  int _selectedIndex = 0;
  bool _loading = true;
  bool _chartLoading = true;
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  String _cctvUrl = defaultCctvUrl;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
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
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
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
      unawaited(_fetchHistory());
    } catch (error) {
      if (!mounted) return;
      if (error.toString().contains('Token expired')) {
        await widget.api.logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchHistory() async {
    if (_history.isEmpty) setState(() => _chartLoading = true);
    final requests = <String, Future<List<TelemetryPoint>>>{
      'battery_voltage': widget.api.fetchHistory(
        ThingsBoardApi.deviceBattery,
        'voltage',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'battery_current': widget.api.fetchHistory(
        ThingsBoardApi.deviceBattery,
        'current',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'battery_power': widget.api.fetchHistory(
        ThingsBoardApi.deviceBattery,
        'power',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'pv_voltage': widget.api.fetchHistory(
        ThingsBoardApi.devicePzem,
        'voltage_dc',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'pv_current': widget.api.fetchHistory(
        ThingsBoardApi.devicePzem,
        'current_dc',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'pv_power': widget.api.fetchHistory(
        ThingsBoardApi.devicePzem,
        'power_dc',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'ac_voltage': widget.api.fetchHistory(
        ThingsBoardApi.devicePzem,
        'voltage_ac',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'ac_current': widget.api.fetchHistory(
        ThingsBoardApi.devicePzem,
        'current_ac',
        start: _dayAgo,
        end: DateTime.now(),
      ),
      'ac_power': widget.api.fetchHistory(
        ThingsBoardApi.devicePzem,
        'power_ac',
        start: _dayAgo,
        end: DateTime.now(),
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
    if (!mounted) return;
    setState(() {
      _history.addAll(Map.fromEntries(results));
      _chartLoading = false;
    });
  }

  DateTime get _dayAgo => DateTime.now().subtract(const Duration(hours: 24));

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (changed == true) _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
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
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_error != null) _warningBanner(),
                  ..._pageContent,
                ],
              ),
            ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCC1B211E),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white24),
              ),
              child: NavigationBar(
                height: 72,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                indicatorColor: const Color(0x5535A968),
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                labelTextStyle: WidgetStatePropertyAll(
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.wb_sunny_outlined),
                    selectedIcon: Icon(Icons.wb_sunny),
                    label: 'PV',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.power_outlined),
                    selectedIcon: Icon(Icons.power),
                    label: 'AC',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.battery_5_bar_outlined),
                    selectedIcon: Icon(Icons.battery_full),
                    label: 'Battery',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.videocam_outlined),
                    selectedIcon: Icon(Icons.videocam),
                    label: 'CCTV',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _pageTitle => const [
    'PLTS Monitoring',
    'PV Monitoring',
    'AC Monitoring',
    'Battery Monitoring',
    'CCTV Monitoring',
  ][_selectedIndex];

  List<Widget> get _pageContent {
    switch (_selectedIndex) {
      case 1:
        return _sourcePage('PV', _pzem, _pvTheme, 'pv', [
          _MetricDef('voltage_dc', 'Voltage', 'V', Icons.bolt),
          _MetricDef('current_dc', 'Current', 'A', Icons.swap_horiz),
          _MetricDef('power_dc', 'Power', 'W', Icons.wb_sunny),
          _MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
        ]);
      case 2:
        return _sourcePage('AC', _pzem, _acTheme, 'ac', [
          _MetricDef('voltage_ac', 'Voltage', 'V', Icons.bolt),
          _MetricDef('current_ac', 'Current', 'A', Icons.electrical_services),
          _MetricDef('power_ac', 'Power', 'W', Icons.power),
          _MetricDef('frequency_ac', 'Frequency', 'Hz', Icons.graphic_eq),
          _MetricDef('energy_ac', 'Energy', 'kWh', Icons.bar_chart),
        ]);
      case 3:
        return _sourcePage('Battery', _battery, _batteryTheme, 'battery', [
          _MetricDef('voltage', 'Voltage', 'V', Icons.bolt),
          _MetricDef('current', 'Current', 'A', Icons.swap_horiz),
          _MetricDef('power', 'Power', 'W', Icons.bolt_outlined),
          _MetricDef(
            'soc',
            'State of charge',
            '%',
            Icons.battery_charging_full,
          ),
        ]);
      case 4:
        return [CctvScreen(streamUrl: _cctvUrl)];
      default:
        return [
          _sectionTitle('LIVE ENERGY SOURCES'),
          _summaryTile(
            'PV',
            _pzem,
            _pvTheme,
            'power_dc',
            'W',
            Icons.wb_sunny,
            1,
          ),
          _summaryTile('AC', _pzem, _acTheme, 'power_ac', 'W', Icons.power, 2),
          _summaryTile(
            'BATTERY',
            _battery,
            _batteryTheme,
            'soc',
            '%',
            Icons.battery_full,
            3,
          ),
          _sectionTitle('ENVIRONMENT'),
          _telemetryCard(_sensor, _envTheme, [
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
    List<_MetricDef> metrics,
  ) => [
    _sectionTitle('$name STATUS'),
    _telemetryCard(data, theme, metrics),
    _sectionTitle('$name · LAST 24 HOURS'),
    _chartCard(theme, prefix),
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
        onTap: () => setState(() => _selectedIndex = targetIndex),
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

  Widget _chartCard(_SectionTheme theme, String prefix) {
    final series = [
      _ChartSeries(
        'Voltage',
        _history['${prefix}_voltage'] ?? [],
        prefix == 'pv' ? const Color(0xFF4DABF7) : const Color(0xFF6FC7FF),
      ),
      _ChartSeries(
        'Current',
        _history['${prefix}_current'] ?? [],
        prefix == 'pv' ? const Color(0xFF2EC4B6) : const Color(0xFFFFC857),
      ),
      _ChartSeries('Power', _history['${prefix}_power'] ?? [], theme.accent),
    ];
    final hasData = series.any((item) => item.points.isNotEmpty);
    return Container(
      height: 390,
      padding: const EdgeInsets.fromLTRB(12, 16, 18, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B211E),
        borderRadius: BorderRadius.circular(14),
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
                      .map((item) => _legend(item.label, item.color))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      minX: _minX(series),
                      maxX: _maxX(series),
                      minY: _minY(series),
                      maxY: _maxY(series),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: _chartInterval(series),
                        verticalInterval: _timeInterval(series),
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0x443A453F),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (_) => const FlLine(
                          color: Color(0x333A453F),
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
                            interval: _chartInterval(series),
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4,
                              child: Text(
                                _axisNumber(value),
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Color(0xFFB7C4BD),
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: _timeInterval(series),
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 6,
                              child: SizedBox(
                                width: 32,
                                child: Text(
                                  _axisTime(value),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Color(0xFFB7C4BD),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
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
                const SizedBox(height: 10),
                Row(children: series.map(_statistics).toList()),
              ],
            ),
    );
  }

  double _minX(List<_ChartSeries> series) => series
      .expand((item) => item.points)
      .map((point) => point.timestamp.millisecondsSinceEpoch.toDouble())
      .reduce((a, b) => a < b ? a : b);

  double _maxX(List<_ChartSeries> series) => series
      .expand((item) => item.points)
      .map((point) => point.timestamp.millisecondsSinceEpoch.toDouble())
      .reduce((a, b) => a > b ? a : b);

  double _minY(List<_ChartSeries> series) {
    final values = series
        .expand((item) => item.points)
        .map((point) => point.value);
    final minimum = values.reduce((a, b) => a < b ? a : b);
    return minimum < 0 ? minimum * 1.1 : 0;
  }

  double _maxY(List<_ChartSeries> series) {
    final maximum = series
        .expand((item) => item.points)
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);
    return maximum <= 0 ? 1 : maximum * 1.1;
  }

  double _chartInterval(List<_ChartSeries> series) =>
      (_maxY(series) - _minY(series)) / 3;

  double _timeInterval(List<_ChartSeries> series) {
    final interval = (_maxX(series) - _minX(series)) / 3;
    return interval == 0 ? 1 : interval;
  }

  String _axisNumber(double value) =>
      value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

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
            series.label,
            style: TextStyle(
              color: series.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Latest ${_axisNumber(latestPoint.value)}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Avg ${_axisNumber(average)}',
            style: const TextStyle(fontSize: 9),
          ),
          Text(
            'Min ${_axisNumber(minimum)}  Max ${_axisNumber(maximum)}',
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
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
  final List<TelemetryPoint> points;
  final Color color;
  _ChartSeries(this.label, this.points, this.color);
}
