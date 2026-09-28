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

/// Editable HTTPS stream pages for the two cameras.
///
/// Both are validated by the same host allowlist, and both default to a
/// different `src` on the same go2rtc host. They are two settings rather than
/// one plus a derived second value so a user with a different rig can point each
/// page at their own camera.
class CctvSection extends StatelessWidget {
  const CctvSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: settings.cctvUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Hydroponics camera URL',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: settings.fishCctvUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Fish camera URL',
            prefixIcon: Icon(Icons.videocam_outlined),
          ),
        ),
      ],
    );
  }
}
