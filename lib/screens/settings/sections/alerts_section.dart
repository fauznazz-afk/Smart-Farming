import 'package:flutter/material.dart';

import '../settings_controller.dart';
import '../widgets/settings_fields.dart';

/// Selectable low-SOC warning thresholds, in percent.
const List<int> kLowSocOptions = [10, 15, 20, 25, 30, 40, 50];

/// Selectable stale-telemetry thresholds, in minutes.
const List<int> kStaleMinutesOptions = [5, 10, 15, 30, 60];

/// Battery and telemetry staleness warnings plus the daily production target.
class EnergyAlertsSection extends StatelessWidget {
  const EnergyAlertsSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable energy alerts'),
          subtitle: const Text(
            'In-app alerts appear while the dashboard is open.',
          ),
          value: settings.energyAlerts,
          onChanged: (value) =>
              settings.update(() => settings.energyAlerts = value),
        ),
        const SizedBox(height: 8),
        LabeledDropdown(
          label: 'Warn when battery SOC falls below',
          value: settings.lowSoc,
          options: kLowSocOptions,
          enabled: settings.energyAlerts,
          suffix: '%',
          onChanged: (value) {
            if (value != null) settings.update(() => settings.lowSoc = value);
          },
        ),
        const SizedBox(height: 12),
        LabeledDropdown(
          label: 'Warn when telemetry is older than',
          value: settings.staleMinutes,
          options: kStaleMinutesOptions,
          enabled: settings.energyAlerts,
          suffix: ' minutes',
          onChanged: (value) {
            if (value != null) {
              settings.update(() => settings.staleMinutes = value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: settings.dailyTarget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Daily production target',
            suffixText: 'kWh',
            helperText: 'Leave blank to hide target progress.',
          ),
        ),
      ],
    );
  }
}

/// Toggle plus per-sensor min/max limits for the environment alerts.
class EnvironmentAlertsSection extends StatelessWidget {
  const EnvironmentAlertsSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable environment alerts'),
          subtitle: const Text(
            'Alerts appear in the app when fresh sensor values cross a limit.',
          ),
          value: settings.envAlerts,
          onChanged: (value) =>
              settings.update(() => settings.envAlerts = value),
        ),
        for (final range in settings.envRanges) EnvRangeField(setting: range),
      ],
    );
  }
}
