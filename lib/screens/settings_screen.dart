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

/// Section metadata used to build both the category list and the detail pages.
class _SectionMeta {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _sections = <_SectionMeta>[
    _SectionMeta(
      title: 'Appearance',
      subtitle: 'Choose the app theme and accent color.',
      icon: Icons.palette_outlined,
    ),
    _SectionMeta(
      title: 'Monitoring',
      subtitle: 'Set how often live telemetry updates.',
      icon: Icons.monitor_heart_outlined,
    ),
    _SectionMeta(
      title: 'Energy alerts',
      subtitle: 'Show warnings when power data needs attention.',
      icon: Icons.notifications_active_outlined,
    ),
    _SectionMeta(
      title: 'Environment alerts',
      subtitle: 'Set crop-specific limits. Blank limits are not monitored.',
      icon: Icons.sensors_outlined,
    ),
    _SectionMeta(
      title: 'CCTV source',
      subtitle: 'Set the secure camera stream page.',
      icon: Icons.videocam_outlined,
    ),
    _SectionMeta(
      title: 'Performance',
      subtitle: 'Tune glass effects for smoother scrolling.',
      icon: Icons.speed_outlined,
    ),
    _SectionMeta(
      title: 'About',
      subtitle: 'Application information.',
      icon: Icons.info_outline,
    ),
    _SectionMeta(
      title: 'Account',
      subtitle: 'Manage your ThingsBoard session.',
      icon: Icons.manage_accounts_outlined,
    ),
  ];

  /// `null` = category list; `0–7` = detail page for that section.
  int? _selectedSection;

  late final TextEditingController _cctvUrlController;
  final _ambientTempMinController = TextEditingController();
  final _ambientTempMaxController = TextEditingController();
  final _humidityMinController = TextEditingController();
  final _humidityMaxController = TextEditingController();
  final _tdsMinController = TextEditingController();
  final _tdsMaxController = TextEditingController();
  final _dailyProductionTargetController = TextEditingController();
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
    _dailyProductionTargetController.dispose();
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
      _cctvUrlController.text = await CctvUrl.loadCctvUrl();
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
      _dailyProductionTargetController.text =
          preferences.getString('daily_production_target_kwh') ?? '';
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
        _validateEnvironmentRange(
          'suhu',
          _ambientTempMinController,
          _ambientTempMaxController,
          allowedMinimum: -40,
          allowedMaximum: 100,
        ) ??
        _validateEnvironmentRange(
          'kelembapan',
          _humidityMinController,
          _humidityMaxController,
          allowedMinimum: 0,
          allowedMaximum: 100,
        ) ??
        _validateEnvironmentRange(
          'TDS',
          _tdsMinController,
          _tdsMaxController,
          allowedMinimum: 0,
        );
    if (environmentRangeError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(environmentRangeError)));
      return;
    }
    final targetText = _dailyProductionTargetController.text.trim();
    final target = targetText.isEmpty ? null : double.tryParse(targetText);
    if (targetText.isNotEmpty && (target == null || target <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Target produksi harus berupa angka lebih besar dari 0.',
          ),
        ),
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
          content: Text(
            'Isi minimal satu batas sensor untuk mengaktifkan peringatan.',
          ),
        ),
      );
      return;
    }
    final url = parseAllowedCctvUrl(_cctvUrlController.text);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CCTV URL harus HTTPS dan memakai host resmi'),
        ),
      );
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
    await preferences.setInt('stale_telemetry_minutes', _staleTelemetryMinutes);
    if (target == null) {
      await preferences.remove('daily_production_target_kwh');
    } else {
      await preferences.setString(
        'daily_production_target_kwh',
        target.toString(),
      );
    }
    await CctvUrl.saveCctvUrl(url.toString());
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
        content: const Text(
          'Your saved session will be cleared from this device.',
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: Icon(
                      icon,
                      color: theme.colorScheme.onPrimary,
                      size: 19,
                    ),
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
  ) => Padding(
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

  // ---------------------------------------------------------------------------
  // Category list (main page)
  // ---------------------------------------------------------------------------

  Widget _buildCategoryList() {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        return ListTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              section.icon,
              color: theme.colorScheme.onPrimary,
              size: 19,
            ),
          ),
          title: Text(section.title),
          subtitle: Text(
            section.subtitle,
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
          onTap: () => setState(() => _selectedSection = index),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Detail pages (one per category)
  // ---------------------------------------------------------------------------

  Widget _buildDetailPage(int index) {
    final section = _sections[index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _settingsSection(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
          children: _sectionChildren(index),
        ),
      ],
    );
  }

  List<Widget> _sectionChildren(int index) {
    switch (index) {
      case 0:
        return _appearanceChildren();
      case 1:
        return _monitoringChildren();
      case 2:
        return _energyAlertsChildren();
      case 3:
        return _environmentAlertsChildren();
      case 4:
        return _cctvChildren();
      case 5:
        return _performanceChildren();
      case 6:
        return _aboutChildren();
      case 7:
        return _accountChildren();
      default:
        return [];
    }
  }

  List<Widget> _appearanceChildren() => [
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
    const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _paletteOptions.entries.map((entry) {
        final selected = _selectedSeed.toARGB32() == entry.value.toARGB32();
        return ChoiceChip(
          label: Text(entry.key),
          selected: selected,
          avatar: CircleAvatar(radius: 9, backgroundColor: entry.value),
          onSelected: (_) {
            setState(() => _selectedSeed = entry.value);
            widget.themeController.setSeedColor(entry.value);
          },
        );
      }).toList(),
    ),
  ];

  List<Widget> _monitoringChildren() => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Auto refresh telemetry'),
      value: _autoRefresh,
      onChanged: (value) => setState(() => _autoRefresh = value),
    ),
    const SizedBox(height: 8),
    DropdownButtonFormField<int>(
      initialValue: _refreshSeconds,
      decoration: const InputDecoration(labelText: 'Refresh interval'),
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
  ];

  List<Widget> _energyAlertsChildren() => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Enable energy alerts'),
      subtitle: const Text('In-app alerts appear while the dashboard is open.'),
      value: _energyAlertsEnabled,
      onChanged: (value) => setState(() => _energyAlertsEnabled = value),
    ),
    const SizedBox(height: 8),
    DropdownButtonFormField<int>(
      initialValue: _lowSocThreshold,
      decoration: const InputDecoration(
        labelText: 'Warn when battery SOC falls below',
      ),
      items: const [10, 15, 20, 25, 30, 40, 50]
          .map(
            (value) => DropdownMenuItem(value: value, child: Text('$value%')),
          )
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
          .map(
            (value) =>
                DropdownMenuItem(value: value, child: Text('$value minutes')),
          )
          .toList(),
      onChanged: _energyAlertsEnabled
          ? (value) {
              if (value != null) {
                setState(() => _staleTelemetryMinutes = value);
              }
            }
          : null,
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _dailyProductionTargetController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Daily production target',
        suffixText: 'kWh',
        helperText: 'Leave blank to hide target progress.',
      ),
    ),
  ];

  List<Widget> _environmentAlertsChildren() => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Enable environment alerts'),
      subtitle: const Text(
        'Alerts appear in the app when fresh sensor values cross a limit.',
      ),
      value: _environmentAlertsEnabled,
      onChanged: (value) => setState(() => _environmentAlertsEnabled = value),
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
  ];

  List<Widget> _cctvChildren() => [
    TextField(
      controller: _cctvUrlController,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Stream URL',
        prefixIcon: Icon(Icons.link),
      ),
    ),
  ];

  List<Widget> _performanceChildren() => [
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
  ];

  List<Widget> _aboutChildren() => [
    ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('EnerGrow monitoring application'),
      trailing: Text(_appVersion == null ? 'Loading…' : 'v$_appVersion'),
    ),
  ];

  List<Widget> _accountChildren() => [
    OutlinedButton.icon(
      onPressed: _confirmLogout,
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewingDetail = _selectedSection != null;
    final title = viewingDetail
        ? _sections[_selectedSection!].title
        : 'Settings';
    return PopScope(
      canPop: !viewingDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && viewingDetail) {
          setState(() => _selectedSection = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: viewingDetail
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedSection = null),
                )
              : null,
          title: Text(title),
        ),
        bottomNavigationBar: viewingDetail
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _saveButton(),
              ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: viewingDetail
              ? _buildDetailPage(_selectedSection!)
              : _buildCategoryList(),
        ),
      ),
    );
  }
}
