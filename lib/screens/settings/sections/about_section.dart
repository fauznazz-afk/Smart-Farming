import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/app_update_service.dart';
import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../settings_controller.dart';
import '../widgets/settings_fields.dart';

/// App name, installed version, and a manual update check.
class AboutSection extends StatefulWidget {
  const AboutSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  bool _checking = false;

  /// Checks now, ignoring the once-a-day gate.
  ///
  /// **`force: true`, and the button existing is the reason.** The gate is
  /// right for the automatic check - a phone in a greenhouse on a metered
  /// connection should not ask GitHub on every launch - but it means the banner
  /// is invisible to anyone who wants to see it now, including the developer who
  /// just published a release. A button that does nothing because a check ran
  /// this morning is indistinguishable from a broken button.
  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final release = await const AppUpdateService().check(force: true);
      if (!mounted) return;
      if (release == null) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('You are on the latest version.')),
        );
        return;
      }
      // **The same dialog for both paths, so there is one place that opens a
      /// release page.** Snacking the version and leaving the user to find
      /// Settings would make the update discoverable only to people who already
      // know it is there.
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Version ${release.version} available'),
          content: Text(
            release.notes == null
                ? 'Open the release page to install it?'
                : release.notes!,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open'),
            ),
          ],
        ),
      );
      if (open == true && mounted) {
        await launchUrl(
          Uri.parse(release.url),
          mode: LaunchMode.externalApplication,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.settings.appVersion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'EnerGrow monitoring application',
            style: AppType.labelUppercase,
          ),
          // The version is metadata, and the brief's micro line is what a
          // trailing figure takes. `Text` here rather than the old bare default
          // style, so the row's two halves are two deliberate sizes rather than
          // one inherited and one not.
          trailing: Text(
            version == null ? 'Loading…' : 'v$version',
            style: AppType.labelMicro.copyWith(color: faintColor),
          ),
        ),
        SecondaryButton(
          onPressed: _checking ? null : _checkNow,
          icon: Icon(
            _checking
                ? Icons.hourglass_empty_outlined
                : Icons.system_update_alt,
            size: 20,
          ),
          label: _checking ? 'Checking…' : 'Check for updates',
        ),
      ],
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
    // it is *not* the primary CTA — the accent fill is reserved, per the brief,
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
