import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../settings_controller.dart';
import '../widgets/settings_fields.dart';

/// The two numbers that turn raw telemetry into an economic and a physical
/// statement: what a kWh costs, and how big the array is.
///
/// **A separate section, and not two more fields inside an alert screen.** The
/// daily production target lives in `Energy alerts` because a target is a
/// threshold the alarm engine enforces. A tariff is not a threshold and is
/// never enforced by anything — it only prices a number for the reader. Putting
/// the two together would suggest the tariff can raise an alarm, which is the
/// kind of claim this app's settings copy has been careful not to make.
class InstallationSection extends StatelessWidget {
  const InstallationSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: settings.electricityTariff,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: settingsFieldDecoration(
            label: 'Electricity tariff',
            suffixText: 'Rp / kWh',
            helperText: 'Leave blank to hide the money figures.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: settings.pvInstalledWp,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: settingsFieldDecoration(
            label: 'Installed PV capacity',
            suffixText: 'Wp',
            helperText:
                'The nameplate on your inverter. Leave blank to hide the '
                'performance figures.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // **The note is here, not on the card.** A tariff is a price the app
        // cannot verify and a nameplate is a number it certainly cannot — so the
        // honest place to say so is where the number is typed. Repeating it on
        // the dashboard would be a caption nobody reads twice.
        Text(
          'The app never sends either value anywhere. Every figure derived '
          'from them is arithmetic on telemetry you already have.',
          style: AppType.slotMicro.copyWith(
            color: AppSurfaces.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}