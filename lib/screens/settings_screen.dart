import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cctv_url.dart';
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
  final _cctvUrlController = TextEditingController(text: defaultCctvUrl);
  final _ambientTempMinController = TextEditingController();
  final _ambientTempMaxController = TextEditingController();
  final _humidityMinController = TextEditingController();
  final _humidityMaxController = TextEditingController();
  final _tdsMinController = TextEditingController();
  final _tdsMaxController = TextEditingController();
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  bool _energyAlertsEnabled = true;
  bool _environmentAlertsEnabled = false;
  int _lowSocThreshold = 20;
  int _staleTelemetryMinutes = 10;
  bool _saving = false;
  String? _appVersion;
  Color _selectedSeed = AppThemeController.defaultSeed;

  @override
  void initState() {
    super.initState();
    _selectedSeed = widget.themeController.seedColor;
    _loadSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _cctvUrlController.dispose();
    _ambientTempMinController.dispose();
    _ambientTempMaxController.dispose();
    _humidityMinController.dispose();
    _humidityMaxController.dispose();
    _tdsMinController.dispose();
    _tdsMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
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
      _cctvUrlController.text =
          preferences.getString('cctv_url') ?? defaultCctvUrl;
      _ambientTempMinController.text =
          preferences.getString('environment_temp_min') ?? '';
      _ambientTempMaxController.text =
          preferences.getString('environment_temp_max') ?? '';
      _humidityMinController.text =
          preferences.getString('environment_humidity_min') ?? '';
      _humidityMaxController.text =
          preferences.getString('environment_humidity_max') ?? '';
      _tdsMinController.text =
          preferences.getString('environment_tds_min') ?? '';
      _tdsMaxController.text =
          preferences.getString('environment_tds_max') ?? '';
      _selectedSeed = widget.themeController.seedColor;
    });
  }

  String? _validateEnvironmentRange(
    String label,
    TextEditingController minimum,
    TextEditingController maximum, {
    double? allowedMinimum,
    double? allowedMaximum,
  }) {
    final minText = minimum.text.trim();
    final maxText = maximum.text.trim();
    final minValue = minText.isEmpty ? null : double.tryParse(minText);
    final maxValue = maxText.isEmpty ? null : double.tryParse(maxText);
    if ((minText.isNotEmpty && minValue == null) ||
        (maxText.isNotEmpty && maxValue == null)) {
      return '$label harus berupa angka yang valid.';
    }
    for (final value in [minValue, maxValue]) {
      if (value == null) continue;
      if (allowedMinimum != null && value < allowedMinimum) {
        return '$label tidak boleh kurang dari $allowedMinimum.';
      }
      if (allowedMaximum != null && value > allowedMaximum) {
        return '$label tidak boleh lebih dari $allowedMaximum.';
      }
    }
    if (minValue != null && maxValue != null && minValue >= maxValue) {
      return 'Batas minimum $label harus lebih kecil dari batas maksimum.';
    }
    return null;
  }

  Future<void> _saveOptionalThreshold(
    SharedPreferences preferences,
    String key,
    TextEditingController controller,
  ) async {
    final value = controller.text.trim();
    if (value.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value);
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    final environmentRangeError =
        _validateEnvironmentRange('suhu', _ambientTempMinController,
            _ambientTempMaxController,
            allowedMinimum: -40, allowedMaximum: 100) ??
        _validateEnvironmentRange('kelembapan', _humidityMinController,
            _humidityMaxController,
            allowedMinimum: 0, allowedMaximum: 100) ??
        _validateEnvironmentRange('TDS', _tdsMinController, _tdsMaxController,
            allowedMinimum: 0);
    if (environmentRangeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(environmentRangeError)),
      );
      return;
    }
    if (_environmentAlertsEnabled &&
        [
          _ambientTempMinController,
          _ambientTempMaxController,
          _humidityMinController,
          _humidityMaxController,
          _tdsMinController,
          _tdsMaxController,
        ].every((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi minimal satu batas sensor untuk mengaktifkan peringatan.'),
        ),
      );
      return;
    }
    final url = parseAllowedCctvUrl(_cctvUrlController.text);
    if (url == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
        content: Text('CCTV URL harus HTTPS dan memakai host resmi'),
      ));
      return;
    }
    setState(() => _saving = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('auto_refresh', _autoRefresh);
    await preferences.setInt('refresh_seconds', _refreshSeconds);
    await preferences.setBool('energy_alerts_enabled', _energyAlertsEnabled);
    await preferences.setBool(
      'environment_alerts_enabled',
      _environmentAlertsEnabled,
    );
    await preferences.setInt('low_soc_threshold', _lowSocThreshold);
    await preferences.setInt(
      'stale_telemetry_minutes',
      _staleTelemetryMinutes,
    );
    await preferences.setString('cctv_url', url.toString());
    await _saveOptionalThreshold(
      preferences,
      'environment_temp_min',
      _ambientTempMinController,
    );
    await _saveOptionalThreshold(
      preferences,
      'environment_temp_max',
      _ambientTempMaxController,
    );
    await _saveOptionalThreshold(
      preferences,
      'environment_humidity_min',
      _humidityMinController,
    );
    await _saveOptionalThreshold(
      preferences,
      'environment_humidity_max',
      _humidityMaxController,
    );
    await _saveOptionalThreshold(
      preferences,
      'environment_tds_min',
      _tdsMinController,
    );
    await _saveOptionalThreshold(
      preferences,
      'environment_tds_max',
      _tdsMaxController,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Your saved session will be cleared from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.onLogout();
  }

  Widget _settingsSection({
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: theme.colorScheme.onPrimary, size: 19),
                  ),
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

  Widget _environmentRangeFields(
    String label,
    String unit,
    TextEditingController minimum,
    TextEditingController maximum,
  ) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minimum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(labelText: 'Min ($unit)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: maximum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(labelText: 'Max ($unit)'),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _saveButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _settingsSection(
            title: 'Appearance',
            subtitle: 'Choose the app theme and accent color.',
            icon: Icons.palette_outlined,
            children: [
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
                selected: {widget.themeController.themeMode},
                onSelectionChanged: (selection) {
                  widget.themeController.setThemeMode(selection.first);
                  setState(() {});
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Accent color',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paletteOptions.entries.map((entry) {
                  final selected =
                      _selectedSeed.toARGB32() == entry.value.toARGB32();
                  return ChoiceChip(
                    label: Text(entry.key),
                    selected: selected,
                    avatar: CircleAvatar(
                      radius: 9,
                      backgroundColor: entry.value,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedSeed = entry.value);
                      widget.themeController.setSeedColor(entry.value);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          _settingsSection(
            title: 'Monitoring',
            subtitle: 'Set how often live telemetry updates.',
            icon: Icons.monitor_heart_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto refresh telemetry'),
                value: _autoRefresh,
                onChanged: (value) => setState(() => _autoRefresh = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _refreshSeconds,
                decoration: const InputDecoration(
                  labelText: 'Refresh interval',
                ),
                items: const [5, 10, 30, 60]
                    .map(
                      (seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds seconds'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _refreshSeconds = value);
                },
              ),
            ],
          ),
          _settingsSection(
            title: 'Energy alerts',
            subtitle: 'Show warnings when power data needs attention.',
            icon: Icons.notifications_active_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable energy alerts'),
                subtitle: const Text(
                  'In-app alerts appear while the dashboard is open.',
                ),
                value: _energyAlertsEnabled,
                onChanged: (value) =>
                    setState(() => _energyAlertsEnabled = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _lowSocThreshold,
                decoration: const InputDecoration(
                  labelText: 'Warn when battery SOC falls below',
                ),
                items: const [10, 15, 20, 25, 30, 40, 50]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value%'),
                        ))
                    .toList(),
                onChanged: _energyAlertsEnabled
                    ? (value) {
                        if (value != null) {
                          setState(() => _lowSocThreshold = value);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _staleTelemetryMinutes,
                decoration: const InputDecoration(
                  labelText: 'Warn when telemetry is older than',
                ),
                items: const [5, 10, 15, 30, 60]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value minutes'),
                        ))
                    .toList(),
                onChanged: _energyAlertsEnabled
                    ? (value) {
                        if (value != null) {
                          setState(() => _staleTelemetryMinutes = value);
                        }
                      }
                    : null,
              ),
            ],
          ),
          _settingsSection(
            title: 'Environment alerts',
            subtitle:
                'Set crop-specific limits. Blank limits are not monitored.',
            icon: Icons.sensors_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable environment alerts'),
                subtitle: const Text(
                  'Alerts appear in the app when fresh sensor values cross a limit.',
                ),
                value: _environmentAlertsEnabled,
                onChanged: (value) =>
                    setState(() => _environmentAlertsEnabled = value),
              ),
              _environmentRangeFields(
                'Ambient temperature',
                '°C',
                _ambientTempMinController,
                _ambientTempMaxController,
              ),
              _environmentRangeFields(
                'Humidity',
                '%',
                _humidityMinController,
                _humidityMaxController,
              ),
              _environmentRangeFields(
                'Water TDS',
                'ppm',
                _tdsMinController,
                _tdsMaxController,
              ),
            ],
          ),
          _settingsSection(
            title: 'CCTV source',
            subtitle: 'Set the secure camera stream page.',
            icon: Icons.videocam_outlined,
            children: [
              TextField(
                controller: _cctvUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Stream URL',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
          _settingsSection(
            title: 'Performance',
            subtitle: 'Tune glass effects for smoother scrolling.',
            icon: Icons.speed_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Smooth Glass Mode'),
                subtitle: Text(
                  widget.themeController.performanceMode
                      ? 'Optimized rendering is enabled'
                      : 'Full backdrop blur is enabled',
                ),
                value: widget.themeController.performanceMode,
                onChanged: (value) {
                  widget.themeController.setPerformanceMode(value);
                  setState(() {});
                },
              ),
            ],
          ),
          _settingsSection(
            title: 'About',
            subtitle: 'Application information.',
            icon: Icons.info_outline,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('EnerGrow monitoring application'),
                trailing: Text(
                  _appVersion == null ? 'Loading…' : 'v$_appVersion',
                ),
              ),
            ],
          ),
          _settingsSection(
            title: 'Account',
            subtitle: 'Manage your ThingsBoard session.',
            icon: Icons.manage_accounts_outlined,
            children: [
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
