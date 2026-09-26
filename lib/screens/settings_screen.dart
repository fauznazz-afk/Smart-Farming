import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cctv_url.dart';
import '../services/weather_service.dart';
import '../theme/app_theme_controller.dart';

const defaultCctvUrl = 'https://cctv.mbkm20262027.tech/stream.html?src=cam1';
const _paletteOptions = <String, Color>{
  'EnerGrow green': Color(0xFF35A968),
  'Solar amber': Color(0xFFF4B942),
  'Ocean cyan': Color(0xFF2AA7A1),
  'Forest teal': Color(0xFF2E7D65),
};

class SettingsScreen extends StatefulWidget {
  final AppThemeController themeController;
  final Future<void> Function() onLogout;

  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Section metadata ──────────────────────────────────────────────────────
  static const _sections = [
    _Section(
      title: 'Appearance',
      subtitle: 'Choose the app theme and accent color.',
      icon: Icons.palette_outlined,
      builder: _buildAppearance,
    ),
    _Section(
      title: 'Monitoring',
      subtitle: 'Set how often live telemetry updates.',
      icon: Icons.monitor_heart_outlined,
      builder: _buildMonitoring,
    ),
    _Section(
      title: 'Energy alerts',
      subtitle: 'Show warnings when power data needs attention.',
      icon: Icons.notifications_active_outlined,
      builder: _buildEnergyAlerts,
    ),
    _Section(
      title: 'Environment alerts',
      subtitle: 'Set crop-specific limits. Blank limits are not monitored.',
      icon: Icons.sensors_outlined,
      builder: _buildEnvironmentAlerts,
    ),
    _Section(
      title: 'Weather',
      subtitle: 'Configure OpenWeatherMap API and location.',
      icon: Icons.cloud_outlined,
      builder: _buildWeather,
    ),
    _Section(
      title: 'CCTV source',
      subtitle: 'Set the secure camera stream page.',
      icon: Icons.videocam_outlined,
      builder: _buildCctv,
    ),
    _Section(
      title: 'Performance',
      subtitle: 'Tune glass effects for smoother scrolling.',
      icon: Icons.speed_outlined,
      builder: _buildPerformance,
    ),
    _Section(
      title: 'About',
      subtitle: 'Application information.',
      icon: Icons.info_outline,
      builder: _buildAbout,
    ),
    _Section(
      title: 'Account',
      subtitle: 'Manage your ThingsBoard session.',
      icon: Icons.manage_accounts_outlined,
      builder: _buildAccount,
    ),
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  int? _selectedSection; // null = list, 0-7 = detail
  bool _saving = false;
  String? _appVersion;

  // Controllers grouped by feature
  final _cctvUrl = TextEditingController(text: defaultCctvUrl);
  final _dailyTarget = TextEditingController();
  final _weatherApiKey = TextEditingController();
  final _weatherCity = TextEditingController();
  final _envRanges = {
    'temp': _RangeControllers(),
    'humidity': _RangeControllers(),
    'tds': _RangeControllers(),
  };

  // Simple values
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  bool _energyAlerts = true;
  bool _envAlerts = false;
  int _lowSoc = 20;
  int _staleMinutes = 10;
  Color _selectedSeed = AppThemeController.defaultSeed;
  bool _weatherLoading = false;
  String? _weatherError;
  String? _weatherLocationName;
  double? _weatherLatitude;
  double? _weatherLongitude;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedSeed = widget.themeController.seedColor;
    _loadSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _cctvUrl.dispose();
    _dailyTarget.dispose();
    _weatherApiKey.dispose();
    _weatherCity.dispose();
    for (final c in _envRanges.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoRefresh = p.getBool('auto_refresh') ?? true;
      _refreshSeconds = p.getInt('refresh_seconds') ?? 10;
      _energyAlerts = p.getBool('energy_alerts_enabled') ?? true;
      _envAlerts = p.getBool('environment_alerts_enabled') ?? false;
      _lowSoc = p.getInt('low_soc_threshold') ?? 20;
      _staleMinutes = p.getInt('stale_telemetry_minutes') ?? 10;
      _cctvUrl.text = p.getString('cctv_url') ?? defaultCctvUrl;
      _dailyTarget.text = p.getString('daily_production_target_kwh') ?? '';
      _weatherApiKey.text = p.getString('weather_api_key') ?? '';
      _weatherCity.text = p.getString('weather_location_name') ?? '';
      _weatherLocationName = p.getString('weather_location_name');
      _weatherLatitude = p.getDouble('weather_location_lat');
      _weatherLongitude = p.getDouble('weather_location_lon');
      _envRanges['temp']!.min.text = p.getString('environment_temp_min') ?? '';
      _envRanges['temp']!.max.text = p.getString('environment_temp_max') ?? '';
      _envRanges['humidity']!.min.text =
          p.getString('environment_humidity_min') ?? '';
      _envRanges['humidity']!.max.text =
          p.getString('environment_humidity_max') ?? '';
      _envRanges['tds']!.min.text = p.getString('environment_tds_min') ?? '';
      _envRanges['tds']!.max.text = p.getString('environment_tds_max') ?? '';
      _selectedSeed = widget.themeController.seedColor;
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;

    // Validate environment ranges
    final envError =
        _validateRange('suhu', _envRanges['temp']!, -40, 100) ??
        _validateRange('kelembapan', _envRanges['humidity']!, 0, 100) ??
        _validateRange('TDS', _envRanges['tds']!, 0, null);
    if (envError != null) return _showError(envError);

    // Validate daily target
    final targetText = _dailyTarget.text.trim();
    final target = targetText.isEmpty ? null : double.tryParse(targetText);
    if (targetText.isNotEmpty && (target == null || target <= 0)) {
      return _showError(
        'Target produksi harus berupa angka lebih besar dari 0.',
      );
    }

    // Require at least one env limit if alerts enabled
    if (_envAlerts &&
        _envRanges.values.every(
          (c) => c.min.text.trim().isEmpty && c.max.text.trim().isEmpty,
        )) {
      return _showError(
        'Isi minimal satu batas sensor untuk mengaktifkan peringatan.',
      );
    }

    // Validate CCTV URL
    if (parseAllowedCctvUrl(_cctvUrl.text) == null) {
      return _showError('CCTV URL harus HTTPS dan memakai host resmi');
    }

    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();

    await p.setBool('auto_refresh', _autoRefresh);
    await p.setInt('refresh_seconds', _refreshSeconds);
    await p.setBool('energy_alerts_enabled', _energyAlerts);
    await p.setBool('environment_alerts_enabled', _envAlerts);
    await p.setInt('low_soc_threshold', _lowSoc);
    await p.setInt('stale_telemetry_minutes', _staleMinutes);
    await p.setString('cctv_url', _cctvUrl.text.trim());
    await p.setString('weather_api_key', _weatherApiKey.text.trim());
    await p.setString('weather_location_name', _weatherCity.text.trim());

    if (target == null) {
      await p.remove('daily_production_target_kwh');
    } else {
      await p.setString('daily_production_target_kwh', target.toString());
    }

    // Save env ranges (remove if empty)
    for (final entry in _envRanges.entries) {
      await _saveIfNotEmpty(p, 'environment_${entry.key}_min', entry.value.min);
      await _saveIfNotEmpty(p, 'environment_${entry.key}_max', entry.value.max);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _saveIfNotEmpty(
    SharedPreferences p,
    String key,
    TextEditingController c,
  ) async {
    final v = c.text.trim();
    v.isEmpty ? await p.remove(key) : await p.setString(key, v);
  }

  String? _validateRange(
    String label,
    _RangeControllers c,
    double? minAllowed,
    double? maxAllowed,
  ) {
    final minText = c.min.text.trim();
    final maxText = c.max.text.trim();
    final minVal = minText.isEmpty ? null : double.tryParse(minText);
    final maxVal = maxText.isEmpty ? null : double.tryParse(maxText);

    if ((minText.isNotEmpty && minVal == null) ||
        (maxText.isNotEmpty && maxVal == null)) {
      return '$label harus berupa angka yang valid.';
    }
    for (final v in [minVal, maxVal]) {
      if (v == null) continue;
      if (minAllowed != null && v < minAllowed) {
        return '$label tidak boleh kurang dari $minAllowed.';
      }
      if (maxAllowed != null && v > maxAllowed) {
        return '$label tidak boleh lebih dari $maxAllowed.';
      }
    }
    if (minVal != null && maxVal != null && minVal >= maxVal) {
      return 'Batas minimum $label harus lebih kecil dari batas maksimum.';
    }
    return null;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
          'Your saved session will be cleared from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await widget.onLogout();
  }

  // ── UI Builders ───────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconBadge(theme, icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 8),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBadge(ThemeData theme, IconData icon) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: theme.colorScheme.primary,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: theme.colorScheme.onPrimary, size: 19),
  );

  Widget _envRangeField(String label, String unit, _RangeControllers c) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _numberField(c.min, 'Min ($unit)')),
                const SizedBox(width: 10),
                Expanded(child: _numberField(c.max, 'Max ($unit)')),
              ],
            ),
          ],
        ),
      );

  Widget _numberField(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
  );

  Widget _saveButton() => FilledButton.icon(
    onPressed: _saving ? null : _saveSettings,
    icon: _saving
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.save),
    label: Text(_saving ? 'Saving...' : 'Save settings'),
  );

  // ── Section content builders (static functions for simplicity) ────────────
  static List<Widget> _buildAppearance(_SettingsScreenState s) => [
    SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.settings_suggest_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {s.widget.themeController.themeMode},
      onSelectionChanged: (sel) {
        s.widget.themeController.setThemeMode(sel.first);
        s.setState(() {});
      },
    ),
    const SizedBox(height: 18),
    const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _paletteOptions.entries.map((e) {
        final selected = s._selectedSeed.toARGB32() == e.value.toARGB32();
        return ChoiceChip(
          label: Text(e.key),
          selected: selected,
          avatar: CircleAvatar(radius: 9, backgroundColor: e.value),
          onSelected: (_) {
            s.setState(() => s._selectedSeed = e.value);
            s.widget.themeController.setSeedColor(e.value);
          },
        );
      }).toList(),
    ),
  ];

  static List<Widget> _buildMonitoring(_SettingsScreenState s) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Auto refresh telemetry'),
      value: s._autoRefresh,
      onChanged: (v) => s.setState(() => s._autoRefresh = v),
    ),
    const SizedBox(height: 8),
    DropdownButtonFormField<int>(
      initialValue: s._refreshSeconds,
      decoration: const InputDecoration(labelText: 'Refresh interval'),
      items: const [5, 10, 30, 60]
          .map((s) => DropdownMenuItem(value: s, child: Text('$s seconds')))
          .toList(),
      onChanged: (v) {
        if (v != null) s.setState(() => s._refreshSeconds = v);
      },
    ),
  ];

  static List<Widget> _buildEnergyAlerts(_SettingsScreenState s) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Enable energy alerts'),
      subtitle: const Text('In-app alerts appear while the dashboard is open.'),
      value: s._energyAlerts,
      onChanged: (v) => s.setState(() => s._energyAlerts = v),
    ),
    const SizedBox(height: 8),
    _dropdown(
      'Warn when battery SOC falls below',
      s._lowSoc,
      [10, 15, 20, 25, 30, 40, 50],
      (v) => s.setState(() => s._lowSoc = v!),
      enabled: s._energyAlerts,
      suffix: '%',
    ),
    const SizedBox(height: 12),
    _dropdown(
      'Warn when telemetry is older than',
      s._staleMinutes,
      [5, 10, 15, 30, 60],
      (v) => s.setState(() => s._staleMinutes = v!),
      enabled: s._energyAlerts,
      suffix: ' minutes',
    ),
    const SizedBox(height: 12),
    TextField(
      controller: s._dailyTarget,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Daily production target',
        suffixText: 'kWh',
        helperText: 'Leave blank to hide target progress.',
      ),
    ),
  ];

  static List<Widget> _buildEnvironmentAlerts(_SettingsScreenState s) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Enable environment alerts'),
      subtitle: const Text(
        'Alerts appear in the app when fresh sensor values cross a limit.',
      ),
      value: s._envAlerts,
      onChanged: (v) => s.setState(() => s._envAlerts = v),
    ),
    s._envRangeField('Ambient temperature', '°C', s._envRanges['temp']!),
    s._envRangeField('Humidity', '%', s._envRanges['humidity']!),
    s._envRangeField('Water TDS', 'ppm', s._envRanges['tds']!),
  ];

  static List<Widget> _buildCctv(_SettingsScreenState s) => [
    TextField(
      controller: s._cctvUrl,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Stream URL',
        prefixIcon: Icon(Icons.link),
      ),
    ),
  ];

  static List<Widget> _buildWeather(_SettingsScreenState s) => [
    TextField(
      controller: s._weatherApiKey,
      decoration: const InputDecoration(
        labelText: 'OpenWeatherMap API Key',
        prefixIcon: Icon(Icons.key),
        helperText: 'Get your free API key from openweathermap.org/api',
      ),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: s._weatherCity,
      decoration: const InputDecoration(
        labelText: 'City name (optional)',
        prefixIcon: Icon(Icons.location_city),
        helperText: 'Leave blank to use GPS location',
      ),
    ),
    const SizedBox(height: 16),
    if (s._weatherLocationName != null) ...[
      Text(
        'Current location: ${s._weatherLocationName}',
        style: Theme.of(s.context).textTheme.bodyMedium,
      ),
      if (s._weatherLatitude != null && s._weatherLongitude != null)
        Text(
          'Coordinates: ${s._weatherLatitude!.toStringAsFixed(4)}, ${s._weatherLongitude!.toStringAsFixed(4)}',
          style: Theme.of(s.context).textTheme.bodySmall?.copyWith(
            color: Theme.of(s.context).colorScheme.onSurfaceVariant,
          ),
        ),
      const SizedBox(height: 16),
    ],
    FilledButton.icon(
      onPressed: s._weatherLoading
          ? null
          : () => s._testWeatherConnection(),
      icon: s._weatherLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_sync),
      label: Text(s._weatherLoading ? 'Testing...' : 'Test Connection'),
    ),
    if (s._weatherError != null) ...[
      const SizedBox(height: 12),
      Text(
        s._weatherError!,
        style: TextStyle(
          color: Theme.of(s.context).colorScheme.error,
        ),
      ),
    ],
  ];

  Future<void> _testWeatherConnection() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    final weatherService = WeatherService();
    await weatherService.initialize();
    await weatherService.setApiKey(_weatherApiKey.text.trim());

    try {
      WeatherData? weather;
      if (_weatherCity.text.trim().isNotEmpty) {
        weather = await weatherService.getWeatherByCity(_weatherCity.text.trim());
      } else {
        weather = await weatherService.getCurrentWeather();
      }

      if (mounted) {
        setState(() {
          _weatherLoading = false;
          if (weather != null) {
            _weatherLocationName = weather.locationName;
            _weatherLatitude = weather.latitude;
            _weatherLongitude = weather.longitude;
            _weatherCity.text = weather.locationName;
            _weatherError = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Weather connection successful! Location: ${weather.locationName}'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            _weatherError = 'Failed to fetch weather data. Check your API key and location.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherLoading = false;
          String errorMsg = e.toString();
          // Clean up the error message
          if (errorMsg.startsWith('Exception: ')) {
            errorMsg = errorMsg.substring(11);
          }
          _weatherError = errorMsg;
        });
      }
    }
  }

  static List<Widget> _buildPerformance(_SettingsScreenState s) => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Smooth Glass Mode'),
      subtitle: Text(
        s.widget.themeController.performanceMode
            ? 'Optimized rendering is enabled'
            : 'Full backdrop blur is enabled',
      ),
      value: s.widget.themeController.performanceMode,
      onChanged: (v) {
        s.widget.themeController.setPerformanceMode(v);
        s.setState(() {});
      },
    ),
  ];

  static List<Widget> _buildAbout(_SettingsScreenState s) => [
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('EnerGrow monitoring application'),
      trailing: Text(s._appVersion == null ? 'Loading…' : 'v${s._appVersion}'),
    ),
  ];

  static List<Widget> _buildAccount(_SettingsScreenState s) => [
    OutlinedButton.icon(
      onPressed: s._confirmLogout,
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
    ),
  ];

  // ── Navigation ────────────────────────────────────────────────────────────
  Widget _buildCategoryList() {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sections.length,
      itemBuilder: (_, i) {
        final sec = _sections[i];
        return ListTile(
          leading: _iconBadge(theme, sec.icon),
          title: Text(sec.title),
          subtitle: Text(
            sec.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () => setState(() => _selectedSection = i),
        );
      },
    );
  }

  Widget _buildDetailPage(int index) {
    final sec = _sections[index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _sectionCard(
          title: sec.title,
          subtitle: sec.subtitle,
          icon: sec.icon,
          children: sec.builder(this),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final detail = _selectedSection != null;
    return PopScope(
      canPop: !detail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && detail) setState(() => _selectedSection = null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: detail
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedSection = null),
                )
              : null,
          title: Text(detail ? _sections[_selectedSection!].title : 'Settings'),
        ),
        bottomNavigationBar: detail
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _saveButton(),
              ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: detail
              ? _buildDetailPage(_selectedSection!)
              : _buildCategoryList(),
        ),
      ),
    );
  }
}

// ── Helper types ────────────────────────────────────────────────────────────
class _RangeControllers {
  final min = TextEditingController();
  final max = TextEditingController();
  void dispose() {
    min.dispose();
    max.dispose();
  }
}

class _Section {
  final String title, subtitle;
  final IconData icon;
  final List<Widget> Function(_SettingsScreenState) builder;
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

Widget _dropdown(
  String label,
  int value,
  List<int> options,
  ValueChanged<int?> onChanged, {
  required bool enabled,
  String suffix = '',
}) => DropdownButtonFormField<int>(
  initialValue: value,
  decoration: InputDecoration(
    labelText: label,
    suffixText: suffix.isEmpty ? null : suffix,
  ),
  items: options
      .map((v) => DropdownMenuItem(value: v, child: Text('$v$suffix')))
      .toList(),
  onChanged: enabled ? onChanged : null,
);
