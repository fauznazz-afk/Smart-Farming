import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme_controller.dart';

const defaultCctvUrl = 'https://cctv.mbkm20262027.tech/stream.html?src=cam1';
const appVersion = '1.0.0+1';

const _paletteOptions = <String, Color>{
  'EnerGrow green': Color(0xFF35A968),
  'Solar amber': Color(0xFFF4B942),
  'Ocean cyan': Color(0xFF2AA7A1),
  'Forest teal': Color(0xFF2E7D65),
};

class SettingsScreen extends StatefulWidget {
  final AppThemeController themeController;

  const SettingsScreen({super.key, required this.themeController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cctvUrlController = TextEditingController(text: defaultCctvUrl);
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
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
      _cctvUrlController.text =
          preferences.getString('cctv_url') ?? defaultCctvUrl;
      _selectedSeed = widget.themeController.seedColor;
    });
  }

  Future<void> _saveSettings() async {
    final url = Uri.tryParse(_cctvUrlController.text.trim());
    if (url == null || !url.hasScheme) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CCTV URL tidak valid')));
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('auto_refresh', _autoRefresh);
    await preferences.setInt('refresh_seconds', _refreshSeconds);
    await preferences.setString('cctv_url', _cctvUrlController.text.trim());
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Monitoring preferences'),
            subtitle: Text('Control how often live telemetry is refreshed.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('App color'),
            subtitle: Text('Choose the accent palette used across EnerGrow.'),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _paletteOptions.entries.map((entry) {
              final selected =
                  _selectedSeed.toARGB32() == entry.value.toARGB32();
              return ChoiceChip(
                label: Text(entry.key),
                selected: selected,
                avatar: CircleAvatar(backgroundColor: entry.value),
                onSelected: (_) {
                  setState(() => _selectedSeed = entry.value);
                  widget.themeController.setSeedColor(entry.value);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto refresh telemetry'),
            value: _autoRefresh,
            onChanged: (value) => setState(() => _autoRefresh = value),
          ),
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
          const SizedBox(height: 24),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('CCTV source'),
            subtitle: Text(
              'Use a go2rtc stream page that supports WebSocket video.',
            ),
          ),
          TextField(
            controller: _cctvUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Stream URL',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Save settings'),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            subtitle: Text('EnerGrow monitoring application'),
            trailing: Text('v$appVersion'),
          ),
        ],
      ),
    );
  }
}
