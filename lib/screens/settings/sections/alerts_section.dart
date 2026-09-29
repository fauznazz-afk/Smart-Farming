import 'package:flutter/material.dart';

import '../settings_controller.dart';
import '../widgets/settings_fields.dart';

/// Selectable low-SOC warning thresholds, in percent.
const List<int> kLowSocOptions = [10, 15, 20, 25, 30, 40, 50];

/// Selectable stale-telemetry thresholds, in minutes.
const List<int> kStaleMinutesOptions = [5, 10, 15, 30, 60];

/// Selectable "device has stopped responding" thresholds, in minutes.
///
/// Deliberately far above [kStaleMinutesOptions]: ten minutes of silence in an
/// MQTT pipeline is a hiccup, an hour is a dead sensor.
const List<int> kOfflineMinutesOptions = [15, 30, 60, 120, 240, 480];

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
            'Checked in the background too, so a low battery is reported '
            'without opening the app.',
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
        LabeledDropdown(
          label: 'Report a device as stopped after',
          value: settings.offlineMinutes,
          options: kOfflineMinutesOptions,
          enabled: settings.energyAlerts,
          suffix: ' minutes',
          onChanged: (value) {
            if (value != null) {
              settings.update(() => settings.offlineMinutes = value);
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
            'Only fresh readings are judged, so an alert always describes the '
            'current state rather than one that has already ended.',
          ),
          value: settings.envAlerts,
          onChanged: (value) =>
              settings.update(() => settings.envAlerts = value),
        ),
        for (final range in settings.envRanges) EnvRangeField(setting: range),
        UnsavedDefaultsNote(ranges: settings.envRanges),
      ],
    );
  }
}

/// Toggle plus per-sensor min/max limits for the fish tank alerts.
class FishAlertsSection extends StatelessWidget {
  const FishAlertsSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable fish tank alerts'),
          subtitle: const Text(
            'Monitors pH, water temperature and turbidity. Only fresh readings '
            'are judged, so an alert always describes the current state.',
          ),
          value: settings.fishAlerts,
          onChanged: (value) =>
              settings.update(() => settings.fishAlerts = value),
        ),
        for (final range in settings.fishRanges) EnvRangeField(setting: range),
        UnsavedDefaultsNote(ranges: settings.fishRanges),
      ],
    );
  }
}
