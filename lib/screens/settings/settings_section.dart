import 'package:flutter/material.dart';

import 'sections/about_section.dart';
import 'sections/alerts_section.dart';
import 'sections/background_status_section.dart';
import 'sections/monitoring_section.dart';
import 'settings_controller.dart';

/// One entry in the settings list, and the widget shown when it is opened.
class SettingsSection {
  const SettingsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext, SettingsController) builder;
}

/// Builds the settings list in display order.
///
/// [onLogout] is only used by the Account entry, so the whole list can be
/// rebuilt when the screen wires up its callbacks.
List<SettingsSection> buildSettingsSections({
  required Future<void> Function() onLogout,
}) =>
    [
      SettingsSection(
        title: 'Monitoring',
        subtitle: 'Set how often live telemetry updates.',
        icon: Icons.monitor_heart_outlined,
        builder: (_, settings) => MonitoringSection(settings: settings),
      ),
      SettingsSection(
        title: 'Energy alerts',
        subtitle: 'Show warnings when power data needs attention.',
        icon: Icons.notifications_active_outlined,
        builder: (_, settings) => EnergyAlertsSection(settings: settings),
      ),
      SettingsSection(
        title: 'Environment alerts',
        subtitle: 'Set crop-specific limits. Blank limits are not monitored.',
        icon: Icons.sensors_outlined,
        builder: (_, settings) => EnvironmentAlertsSection(settings: settings),
      ),
      SettingsSection(
        title: 'Fish tank alerts',
        subtitle: 'Set fish tank limits. Blank limits are not monitored.',
        icon: Icons.water_drop_outlined,
        builder: (_, settings) => FishAlertsSection(settings: settings),
      ),
      SettingsSection(
        title: 'CCTV source',
        subtitle: 'Set the secure camera stream page.',
        icon: Icons.videocam_outlined,
        builder: (_, settings) => CctvSection(settings: settings),
      ),
      SettingsSection(
        title: 'Background checks',
        subtitle: 'Is the alarm check running, and can Android delay it?',
        icon: Icons.schedule_send_outlined,
        builder: (_, settings) => const BackgroundStatusSection(),
      ),
      SettingsSection(
        title: 'About',
        subtitle: 'Application information.',
        icon: Icons.info_outline,
        builder: (_, settings) => AboutSection(settings: settings),
      ),
      SettingsSection(
        title: 'Account',
        subtitle: 'Manage your ThingsBoard session.',
        icon: Icons.manage_accounts_outlined,
        builder: (_, settings) => AccountSection(onLogout: onLogout),
      ),
    ];
