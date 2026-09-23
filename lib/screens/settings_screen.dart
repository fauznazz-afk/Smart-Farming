import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cctv_url.dart';
import '../theme/app_theme_controller.dart';

const defaultCctvUrl = 'https://cctv.mbkm20262027.tech/stream.html?src=cam1';
const appVersion = '1.2.1';

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
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  bool _energyAlertsEnabled = true;
  int _lowSocThreshold = 20;
  int _staleTelemetryMinutes = 10;
  bool _saving = false;
  Color _selectedSeed = AppThemeController.defaultSeed;

  @override
  void initState() {
    super.initState();
    _selectedSeed = widget.themeController.seedColor;
    _loadSettings();
  }

  @override
  void dispose() {
    _cctvUrlController.dispose();
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
      _lowSocThreshold = preferences.getInt('low_soc_threshold') ?? 20;
      _staleTelemetryMinutes =
          preferences.getInt('stale_telemetry_minutes') ?? 10;
      _cctvUrlController.text =
          preferences.getString('cctv_url') ?? defaultCctvUrl;
      _selectedSeed = widget.themeController.seedColor;
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
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
    await preferences.setInt('low_soc_threshold', _lowSocThreshold);
    await preferences.setInt(
      'stale_telemetry_minutes',
      _staleTelemetryMinutes,
    );
    await preferences.setString('cctv_url', url.toString());
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
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
          FilledButton.icon(
            onPressed: _saving ? null : _saveSettings,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save settings'),
          ),
          const SizedBox(height: 12),
          _settingsSection(
            title: 'About',
            subtitle: 'App and account information.',
            icon: Icons.info_outline,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('EnerGrow monitoring application'),
                trailing: const Text('v$appVersion'),
              ),
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
