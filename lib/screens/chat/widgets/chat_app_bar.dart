import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../../dashboard/widgets/glass_hero_card.dart';

/// The assistant's app bar: a centred title between two round actions.
///
/// The reference centres a plain title and hangs one round action on each side
/// of it, so the default back arrow is replaced rather than kept alongside a
/// second affordance for the same thing.
AppBar chatAppBar({
  required BuildContext context,
  required bool clearEnabled,
  required VoidCallback onClear,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: AppGlass.pageInkStrong,
    automaticallyImplyLeading: false,
    centerTitle: true,
    leadingWidth: 68,
    leading: Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Center(
        child: GlassCircleButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          fill: AppSurfaces.surface,
          ink: AppSurfaces.onSurface,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    ),
    title: Text(
      'Ask the assistant',
      style: AppType.headlineMd.copyWith(color: AppGlass.pageInkStrong),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Center(
          child: GlassCircleButton(
            icon: Icons.delete_outline,
            tooltip: 'Clear conversation',
            fill: AppSurfaces.surface,
            ink: AppSurfaces.onSurface,
            // Disabled rather than hidden while a reply is in flight: clearing
            // the transcript mid-request would let the reply arrive into an
            // empty history and then contradict it.
            onPressed: clearEnabled ? onClear : null,
          ),
        ),
      ),
    ],
  );
}
