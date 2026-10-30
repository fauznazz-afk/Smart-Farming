import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/app_update.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/design_tokens.dart';
import 'banners.dart';

/// "A newer release exists", with the one action that does anything about it.
///
/// **Outlined in the accent, and deliberately not a warning colour.** The accent
/// is this app's accent and this is an informational banner - it is not a fault,
/// and nothing here is out of range. `ConnectionStatusBanner` reaches for
/// `statusWarn` because stale telemetry *is* a warning; an available update is
/// an opportunity, and painting it amber would make the two indistinguishable
/// from across the room.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.release,
    required this.onDismiss,
  });

  final AppRelease release;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.system_update_alt,
                color: AppPalette.accent,
                size: 17,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'UPDATE ${release.version} AVAILABLE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelUppercase.copyWith(color: AppPalette.accent),
              ),
            ),
            _Action(label: 'GET', onTap: _open),
            _Action(label: 'LATER', onTap: onDismiss),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final uri = Uri.parse(release.url);
    // **The result is deliberately ignored.** `launchUrl` returns false when no
    // browser can handle it and throws when the URL is malformed, and both are
    // non-events here: the banner has already told the user what exists, and a
    // snackbar explaining that their phone has no browser is noise about the
    // phone rather than about the update. The release URL is validated as https
    // at parse time, so the throwing case is already unreachable.
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).onError((_, _) => false);
  }
}

/// One small outlined action, so the banner has two and neither is a filled
/// button competing with the accent.
///
/// **44 dp tall, and that number was a bug before it was a rule.** The first
/// version of this wrapped a 10 sp `Text` in a `Padding`, and the measured hit
/// area was **12 dp** tall - a sixth of the 48 dp every platform calls the
/// minimum, on the one control the banner exists for. A comment claimed the
/// target was real; the test measured it and said otherwise. 44 is the same
/// floor the chart card's download button uses, for the same reason: it is
/// Material's minimum tap size and the banner is a strip the user reaches for
/// with a thumb.
class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  /// Material's minimum tap size, and the house figure - see `chart_card.dart`.
  static const double _minTarget = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        // `Center` with a `ConstrainedBox`, so the label is centred in the
        // target rather than the target being centred on the label. A
        // `Center` alone would size to the text and reintroduce the 12 dp.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTarget,
              minHeight: _minTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: AppType.labelMicro.copyWith(color: AppPalette.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps [UpdateBanner] so it animates in and out instead of appearing.
///
/// A banner that pops into existence over the telemetry is more alarming than
/// one that settles, and this is the same reasoning [BannerSwitcher] already
/// encodes for the connection banners.
class UpdateBannerSwitcher extends StatelessWidget {
  const UpdateBannerSwitcher({
    super.key,
    required this.release,
    required this.visible,
    required this.onDismiss,
  });

  final AppRelease? release;
  final bool visible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return BannerSwitcher(
      visible: visible,
      // Identity is the version, so a second check that finds the same release
      // does not restart the animation, and one that finds a newer one does.
      identity: release?.version ?? '',
      bottomSpacing: 8,
      builder: () => release == null
          ? const SizedBox.shrink()
          : UpdateBanner(release: release!, onDismiss: onDismiss),
    );
  }
}
