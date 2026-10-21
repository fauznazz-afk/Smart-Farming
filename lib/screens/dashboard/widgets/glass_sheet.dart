import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// The one opaque surface in the glass system, and the three parts it is made of.
///
/// [AppGlass] fills are translucent because they sit on the hero and have the
/// hero behind them; a sheet is a different layer of interface that happens to be
/// white, so painting it translucent would let the page gradient bleed through the
/// only surface that is supposed to be flat. The rows keep a grey fill rather than
/// a tint of the sheet, and the selected row is drawn with an outline instead of a
/// different fill — white on white is invisible, and a second grey would have been a
/// tone nobody can predict.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onTitleTap,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Makes the title a route rather than a label.
  ///
  /// **The sheet's title is the only part of it that names a bigger view of the
  /// same data**, so it is the only part that should open one. The 7-day rows are
  /// a summary of what the energy report breaks down, and the report lost its
  /// entry point when the instrument panel came off this page.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppGlass.sheet,
        // **Rounded on all four corners, and the bottom two are the point.**
        //
        // This was `BorderRadius.vertical(top: ...)`, which is the shape a bottom
        // *sheet* has when it is docked to the screen edge — the bottom corners
        // are off-screen, so rounding them would be rounding nothing. It is no
        // longer docked: the sheet ends above the nav bar with page behind it
        // visible, so its lower corners are on screen and drawing as square
        // makes the card read as a panel that was cut off rather than as a
        // rounded object.
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: AppGlass.sheetShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppGlass.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // The title carries the route, so it is the one tappable thing in a
          // sheet whose rows are not. `Material` sits inside the decorated
          // container for the same reason `AppCard` does: outside it, the opaque
          // sheet fill paints over the ink layer and the ripple is invisible.
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(AppRadius.badge),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppType.headlineMd.copyWith(
                        color: AppGlass.sheetTitleInk,
                      ),
                    ),
                    if (onTitleTap != null) ...<Widget>[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppGlass.sheetRowInkMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            // Bottom padding belongs here, not on the sheet: without it the last
            // row sits on the bottom radius and is clipped at the user's text scale.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < children.length; i++) ...<Widget>[
                  children[i],
                  if (i != children.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of the sheet: day name, condition glyph, number, description.
///
/// The row carries its own translucent `Material` so an `InkWell` added later has
/// an ink layer to paint into; the opaque fill lives on the `Container` below it,
/// which is why the two cannot be merged.
class GlassSheetRow extends StatelessWidget {
  const GlassSheetRow({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.trailing,
    this.highlight = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final String trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        // A minimum, not a fixed height: the trailing sentence wraps instead of
        // being ellipsised, so the row has to be allowed to grow with it.
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppGlass.sheetRow,
          borderRadius: BorderRadius.circular(AppRadius.sheetRow),
          border: highlight
              ? Border.all(color: AppGlass.active, width: 1.5)
              : null,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: AppType.emphasis.copyWith(
                  color: AppGlass.sheetRowInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 26, color: AppGlass.sheetRowInkMuted),
            const SizedBox(width: 12),
            Text(
              value,
              style: AppType.strong.copyWith(
                color: AppGlass.sheetRowInk,
              ),
            ),
            const SizedBox(width: 12),
            // The trailing slot owns the row's remaining width and wraps: it is the
            // half that carries the unit and the meaning, so it is not the half that
            // gets clipped.
            Expanded(
              child: Text(
                trailing,
                textAlign: TextAlign.right,
                style: AppType.bodyMd.copyWith(color: AppGlass.sheetRowInkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
