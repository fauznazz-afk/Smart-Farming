import 'package:flutter/material.dart';

import '../settings_controller.dart';

/// Selectable refresh intervals, in seconds.
const List<int> kRefreshIntervalOptions = [5, 10, 30, 60];

/// Auto-refresh toggle plus polling interval.
class MonitoringSection extends StatelessWidget {
  const MonitoringSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto refresh telemetry'),
          value: settings.autoRefresh,
          onChanged: (value) =>
              settings.update(() => settings.autoRefresh = value),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: settings.refreshSeconds,
          decoration: const InputDecoration(labelText: 'Refresh interval'),
          items: kRefreshIntervalOptions
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text('$option seconds'),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              settings.update(() => settings.refreshSeconds = value);
            }
          },
        ),
      ],
    );
  }
}

/// Editable HTTPS stream page for the CCTV tab.
class CctvSection extends StatelessWidget {
  const CctvSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: settings.cctvUrl,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Stream URL',
        prefixIcon: Icon(Icons.link),
      ),
    );
  }
}
