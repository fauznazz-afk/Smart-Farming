import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultCctvUrl = 'https://cctv.mbkm20262027.tech/stream.html?src=cam1';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cctvUrlController = TextEditingController(text: defaultCctvUrl);
  bool _autoRefresh = true;
  int _refreshSeconds = 10;

  @override
  void initState() {
    super.initState();
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto refresh telemetry'),
            value: _autoRefresh,
            onChanged: (value) => setState(() => _autoRefresh = value),
          ),
          DropdownButtonFormField<int>(
            value: _refreshSeconds,
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
        ],
      ),
    );
  }
}
