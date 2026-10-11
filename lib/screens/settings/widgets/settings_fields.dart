import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/settings_validation.dart';

/// Rounded surface with an icon badge, title, subtitle, and body.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        // The brief's `card-padding`, 16. It was 14/8, which is neither the
        // card scale nor anything else — the previous system had no 16.
        //
        // **Tightened to 12 on the drill-in page, and the direction is the
        // user's.** Settings is a list of fields, not a showcase; at 16 the
        // nine category cards each spent 32dp of their height on padding before
        // a single control appeared. 12 keeps the card's silhouette and the
        // hairline legible while giving the controls the room, which is what a
        // settings page is for.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsIconBadge(icon: icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // `headline-md`: the brief gives card titles inside list
                      // rows the display weight at 20px. `titleMedium` already
                      // resolved to this token through the text theme, so the
                      // change is that the value is now read rather than
                      // inherited — a card title that survives a theme edit.
                      Text(title, style: AppType.headlineMd),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        // Left in the body face on purpose, and this is the
                        // one place the brief's "prefer uppercase even for
                        // body" is not followed. These nine strings are the
                        // only *sentences* on the screen, and `body-sm` is the
                        // brief's own slot for exactly that — "the rare
                        // lowercase line for descriptive paragraphs".
                        // `label-uppercase-md` would be a second thing to
                        // check against the tile-height ceiling
                        // `settings_screen_test.dart` pins, and it has not
                        // been measured here.
                        style: AppType.bodySm.copyWith(color: faintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // **The divider sits closer than it did, and the gap under it is
            // gone.** At `sm` top plus `xs` bottom the header block and the
            // controls were 12dp apart inside a card that was already 16dp from
            // its own edge — two spacings saying the same thing. One `xs` on
            // each side now.
            Padding(
              // 34 badge + 12 gap, matching the row above rather than a second
              // hand-picked number.
              padding: const EdgeInsets.only(left: 46, top: AppSpacing.xs),
              child: AppDivider(opacity: 0.12),
            ),
            const SizedBox(height: AppSpacing.xs),
            child,
          ],
        ),
      ),
    );
  }
}

/// Circular accent icon container used as a section/list leading.
///
/// **Neutral on purpose, and the accent it used to take was amber.**
/// [AppPalette.accent] is `statusWarn` in `color_helpers.dart` — it is the
/// "telemetry is stale" hue. Painting every settings icon in it gave a warning
/// colour a decorative job, which is the same defect as the permanent green
/// "semua normal" badge: a hue means one thing or the reader cannot rely on it.
///
/// So the badge is tonal instead: `surfaceAlt` one step above the card it sits
/// on, a hairline for the silhouette, and `onSurfaceVariant` ink — the brief's
/// `tab-item-inactive` colour, which is what an inactive chrome glyph takes.
class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppSurfaces.surfaceAlt,
        shape: BoxShape.circle,
        border: AppBorders.controlBorder,
      ),
      child: Icon(icon, color: AppSurfaces.onSurfaceVariant, size: 19),
    );
  }
}

/// Decimal text field that accepts negative values.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    this.label,
    this.inactive = false,
  });

  final TextEditingController controller;
  final String? label;

  /// True while the field holds a shipped default that has never been saved, so
  /// no alarm rule is enforcing it yet.
  ///
  /// The value itself is printed in the faint colour rather than given a badge,
  /// because the number still has to be readable — it is the value the user
  /// would get after saving. Only its *status* is different, and the section
  /// says so once in words instead of every field repeating it.
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      // `label-uppercase-md`, the brief's `input-text` typography: every glyph
      // the user types is uppercase bold and wide-tracked, placeholder
      // included. Set here rather than only in the theme because this field is
      // the one that carries a *second* style for the unsaved-default case,
      // and that case has to derive from the same token rather than from a
      // third literal.
      style: inactive
          ? AppType.labelUppercase.copyWith(
              color: AppSurfaces.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            )
          : AppType.labelUppercase,
      decoration: InputDecoration(
        labelText: label,
        helperText: inactive ? 'Not saved yet' : null,
      ),
    );
  }
}

/// Labelled min/max pair for one environment sensor.
class EnvRangeField extends StatelessWidget {
  const EnvRangeField({super.key, required this.setting});

  final EnvRangeSetting setting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            setting.label,
            // The brief's placeholder/label slot: uppercase, wide-tracked, in
            // `on-surface-variant`.
            style: AppType.labelUppercase.copyWith(
              color: AppSurfaces.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NumberField(
                  controller: setting.min,
                  label: 'Min (${setting.unit})',
                  inactive: setting.minIsPrefill,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(
                  controller: setting.max,
                  label: 'Max (${setting.unit})',
                  inactive: setting.maxIsPrefill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line saying how many **limits** are still showing an unsaved default.
///
/// Exists because a default sitting in a field reads exactly like a stored one,
/// and the two are not the same thing: a stored limit has a rule behind it, a
/// default does not. The per-field caption says *which* fields; this says what
/// that means, and how many, in one sentence.
///
/// The two are deliberately different kinds of statement. The per-field "Not
/// saved yet" is a label on a control; repeating the consequence under every one
/// of them would be the three-ways-to-signal-one-state problem the environment
/// cards had. So the count and the consequence live here, and the per-field mark
/// stays a caption.
class UnsavedDefaultsNote extends StatelessWidget {
  const UnsavedDefaultsNote({super.key, required this.ranges});

  final List<EnvRangeSetting> ranges;

  @override
  Widget build(BuildContext context) {
    // **Counting fields, not ranges. This said "3 limits" while the screen
    // showed five.** It counted the ranges that had at least one prefilled
    // side, and the Environment screen has three of those -- temperature,
    // humidity, TDS -- with five prefilled *fields* between them, because
    // temperature and humidity prefill both ends and TDS prefills only its
    // minimum.
    //
    // Found on an emulator: the sentence at the bottom of the card read
    // "3 limits are shown as defaults" directly under five fields each captioned
    // "Not saved yet". A count that contradicts the thing it is counting is
    // worse than no count, and it is exactly the failure `FEATURE.md` records
    // for `_history` being reported dead: a number that looks authoritative and
    // is not.
    final count = ranges.fold<int>(
      0,
      (sum, r) => sum + (r.minIsPrefill ? 1 : 0) + (r.maxIsPrefill ? 1 : 0),
    );
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: AppSurfaces.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              count == 1
                  ? '1 limit is shown as a default. It is not monitored until '
                        'you save.'
                  : '$count limits are shown as defaults. They are not '
                        'monitored until you save.',
              style: AppType.bodySm.copyWith(
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Integer dropdown that can be disabled while its parent toggle is off.
class LabeledDropdown extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.suffix = '',
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix.isEmpty ? null : suffix,
      ),
      items: options
          .map(
            (option) =>
                DropdownMenuItem(value: option, child: Text('$option$suffix')),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Primary save action shown while browsing the settings list.
///
/// The brief's `button-primary`, and four of its values changed here.
///
/// * **56dp, not 48.** The brief's `height: 56px`. It is set as `minimumSize`
///   rather than as a fixed `SizedBox` height so the button still grows with the
///   user's font scale — 48 was the accessibility floor and this is above it.
/// * **8px, not a pill.** `AppRadius.card`. The pill came from the previous
///   system's rounded-soft look; the brief is explicit that "filter chips are
///   full-pill, everything else is 8px".
/// * **`AppType.buttonLabel`, not `label-uppercase`.** 13px at weight 900 with
///   0.1em tracking. Buttons shout; the brief gives them the display weight at
///   label size, which is not the same as a 12px/700 metadata line.
/// * **The tinted hard shadow**, `AppShadows.stampedIn(AppPalette.primary)`.
///   That is the brief's signature move for the one button allowed to be
///   electric: a solid offset rectangle in the brand hue at 20%, no blur, so
///   the displacement itself bleeds lime.
///
/// The shadow is painted by a [DecoratedBox] *behind* the button rather than by
/// `FilledButton.styleFrom`, because Material's `elevation` maps through
/// `kElevationToShadow` and can only ever produce a blurred halo — the exact
/// thing the brief bans. `DecoratedBox` paints its decoration first and then its
/// child, so only the 4px offset strip is visible around the opaque lime fill.
class SaveSettingsButton extends StatelessWidget {
  const SaveSettingsButton({
    super.key,
    required this.saving,
    required this.onPressed,
  });

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.all(AppRadius.card),
        boxShadow: AppShadows.stampedIn(AppPalette.primary),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: saving ? null : onPressed,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 20),
          label: Text(saving ? 'Saving...' : 'Save settings'),
          style: FilledButton.styleFrom(
            backgroundColor: AppPalette.primary,
            foregroundColor: AppPalette.onHue,
            // Both disabled colours keep the fill and the ink, so the button
            // does not grey out behind the spinner mid-write. It is still
            // disabled — `onPressed` is null — it just says so with its label
            // rather than by turning into a different button.
            disabledBackgroundColor: AppPalette.primary,
            disabledForegroundColor: AppPalette.onHue,
            textStyle: AppType.buttonLabel,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.all(AppRadius.card),
            ),
          ),
        ),
      ),
    );
  }
}

/// The brief's `button-secondary`: the page fill behind a hairline, 56dp, no
/// shadow.
///
/// Used by the two actions inside the Background checks card. It sits on the
/// card rather than on the page, so its fill is *darker* than its surround —
/// which is the brief's own relationship (`background` below `surface`) applied
/// one level down, and it reads as an action set into the card without needing
/// a second outline colour.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;

  /// Sized at the brief's `iconSize` (20) by the caller, the same way
  /// [SaveSettingsButton] sizes its own.
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppSurfaces.page,
        foregroundColor: AppSurfaces.onSurface,
        disabledBackgroundColor: AppSurfaces.page,
        disabledForegroundColor: AppSurfaces.onSurfaceVariant,
        side: AppBorders.hairline,
        textStyle: AppType.buttonLabel,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.all(AppRadius.card),
        ),
      ),
    );
  }
}
