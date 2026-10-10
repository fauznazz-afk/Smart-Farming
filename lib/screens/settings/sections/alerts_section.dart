import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
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

/// A `SwitchListTile` title in the app's uppercase label face.
///
/// This is the brief's `label-uppercase-md`, which is also what the theme's
/// `labelLarge` resolves to. Reaching for the token rather than the theme slot
/// keeps the control's title from changing shape when the text theme is retuned
/// for some other screen.
final TextStyle _toggleTitle = AppType.labelUppercase;

/// A `SwitchListTile` subtitle: the brief's "rare lowercase descriptive line",
/// in the measured secondary ink.
final TextStyle _toggleSubtitle = AppType.bodySm.copyWith(
  color: AppSurfaces.onSurfaceVariant,
);

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
          title: Text('Enable energy alerts', style: _toggleTitle),
          subtitle: Text(
            'Checked in the background too, so a low battery is reported '
            'without opening the app.',
            style: _toggleSubtitle,
          ),
          value: settings.energyAlerts,
          onChanged: (value) =>
              settings.update(() => settings.energyAlerts = value),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.md),
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
        const SizedBox(height: AppSpacing.md),
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
        const SizedBox(height: AppSpacing.md),
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
          title: Text('Enable environment alerts', style: _toggleTitle),
          subtitle: Text(
            'Only fresh readings are judged, so an alert always describes the '
            'current state rather than one that has already ended.',
            style: _toggleSubtitle,
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
          title: Text('Enable fish tank alerts', style: _toggleTitle),
          subtitle: Text(
            'Monitors pH, water temperature and turbidity. Only fresh readings '
            'are judged, so an alert always describes the current state.',
            style: _toggleSubtitle,
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
