import 'package:flutter/material.dart';

import '../settings_controller.dart';

/// App name and installed version.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final version = settings.appVersion;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('EnerGrow monitoring application'),
      trailing: Text(version == null ? 'Loading…' : 'v$version'),
    );
  }
}

/// Logout action for the current ThingsBoard session.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onLogout,
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
    );
  }
}
