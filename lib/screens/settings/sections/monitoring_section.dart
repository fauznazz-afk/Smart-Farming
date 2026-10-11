import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../settings_controller.dart';
import '../widgets/settings_fields.dart';

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
        SettingsSwitchRow(
          title: 'Auto refresh telemetry',
          value: settings.autoRefresh,
          onChanged: (value) =>
              settings.update(() => settings.autoRefresh = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<int>(
          initialValue: settings.refreshSeconds,
          decoration: settingsFieldDecoration(label: 'Refresh interval'),
          items: kRefreshIntervalOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text('$option seconds'),
                ),
              )
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
          decoration: settingsFieldDecoration(
            label: 'Hydroponics camera URL',
            prefixIcon: const Icon(Icons.link),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: settings.fishCctvUrl,
          keyboardType: TextInputType.url,
          decoration: settingsFieldDecoration(
            label: 'Fish camera URL',
            prefixIcon: const Icon(Icons.videocam_outlined),
          ),
        ),
      ],
    );
  }
}
