import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../utils/csv_builder.dart';
import '../../../services/energy_report_service.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.buckets,
    required this.selectedDate,
    required this.monthly,
    required this.sharingNotifier,
  });

  final List<EnergyBucket> buckets;
  final DateTime selectedDate;
  final bool monthly;
  final ValueNotifier<bool> sharingNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: sharingNotifier,
      builder: (context, isSharing, _) {
        // The brief's `button-primary`, standing directly on the page.
        //
        // **The `AppCard` wrapper is gone, and that is deliberate.** It used to
        // put this button inside a card, which is a `surface` fill carrying its
        // own stamped shadow — so the one object the brief says may be a large
        // lime fill sat inside a second, quieter box, with two shadows and two
        // edges. The brief is explicit that "the only large fill ever rendered
        // in primary is the primary button", and this is it.
        //
        // The shadow is painted by the `DecoratedBox` behind the button rather
        // than by `FilledButton`'s `elevation`, because Material maps elevation
        // through `kElevationToShadow` and can only produce a blurred halo —
        // the one shadow language the brief bans. `AppShadows.stampedIn` is
        // the tinted variant: a solid offset rectangle in the brand hue at 20%,
        // so the displacement itself bleeds lime.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.all(AppRadius.card),
            boxShadow: AppShadows.stampedIn(AppPalette.primary),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSharing
                  ? null
                  : () => shareEnergyReport(
                      context: context,
                      buckets: buckets,
                      selectedDate: selectedDate,
                      monthly: monthly,
                      sharingNotifier: sharingNotifier,
                    ),
              icon: isSharing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined, size: 20),
              label: Text(isSharing ? 'Preparing CSV…' : 'Export CSV report'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: AppPalette.onHue,
                // Both disabled colours keep the fill and the ink, so the
                // button does not grey out behind the spinner mid-write. It is
                // still disabled — `onPressed` is null — it says so with its
                // label rather than by becoming a different button.
                disabledBackgroundColor: AppPalette.primary,
                disabledForegroundColor: AppPalette.onHue,
                // 13/900/0.1em. Buttons shout; `label-uppercase` is the
                // metadata line and this is not metadata.
                textStyle: AppType.buttonLabel,
                // 56dp as `minimumSize` rather than a fixed height, so the
                // button still grows with the user's font scale.
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.all(AppRadius.card),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
