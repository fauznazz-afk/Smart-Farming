import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../settings_controller.dart';
import '../widgets/settings_fields.dart';

/// App name and installed version.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final version = settings.appVersion;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'EnerGrow monitoring application',
        style: AppType.labelUppercase,
      ),
      // The version is metadata, and the brief's micro line is what a trailing
      // figure takes. `Text` here rather than the old bare default style, so
      // the row's two halves are two deliberate sizes rather than one
      // inherited and one not.
      trailing: Text(
        version == null ? 'Loading…' : 'v$version',
        style: AppType.labelMicro.copyWith(color: faintColor),
      ),
    );
  }
}

/// Logout action for the current ThingsBoard session.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    // The brief's `button-secondary`. Logout is a real destructive action, so
    // it is *not* the primary CTA — the lime fill is reserved, per the brief,
    // for the one action the screen exists to complete, and on Settings that
    // is Save. A page-fill block behind a hairline says "action" without
    // shouting, which is the right register for leaving.
    return SecondaryButton(
      onPressed: onLogout,
      icon: const Icon(Icons.logout, size: 20),
      label: 'Logout',
    );
  }
}
