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
        // **Tightened again, and this time it is the panel look the rest of the
        // app moved to.** 12/10/12/8 rather than 12/12/12/8: the top was the
        // only remaining 12 on the card and it is the same 12 the side padding
        // already spends, so the header started one 12 lower than the left edge
        // of its own title. 10 is a literal because `AppSpacing` has no step
        // between 8 and 12 and `design_tokens.dart` is not this screen's to
        // change — a token wants to be a decision somebody makes once.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          10,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsIconBadge(icon: icon),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // **`label-uppercase-md`, not `headline-md`.** The drill-in
                      // page's heading is already in the app bar directly above
                      // it — `SettingsScreen` passes `section.title` to both —
                      // so the card was setting the same words twice, the second
                      // time at 20px. The instrument-panel look is a small
                      // uppercase label, and that is what this is now. Nothing is
                      // lost with the title: `settings_screen_test.dart` finds it
                      // by text, not by style.
                      Text(title, style: AppType.labelUppercase),
                      const SizedBox(height: 2),
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
              // 28 badge + 8 gap, matching the row above rather than a second
              // hand-picked number.
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: AppDivider(opacity: 0.12),
            ),
            const SizedBox(height: 6),
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
///
/// **28dp, not 34.** It is a leading glyph, not a control: it carries no state
/// and is never tapped, and the row that holds it is now sized by its label. It
/// also sets the width the header row's divider insets to, so shrinking it is
/// what lets `SectionCard` indent the divider by 36 rather than 46.
class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppSurfaces.surfaceAlt,
        shape: BoxShape.circle,
        border: AppBorders.controlBorder,
      ),
      child: Icon(icon, color: AppSurfaces.onSurfaceVariant, size: 16),
    );
  }
}

/// Compact input decoration for every settings field.
///
/// The app theme's own `contentPadding` is 16 vertical, which is the right
/// answer for a login form — one field, thumb-sized — and the wrong one here,
/// because a settings page is a *column* of fields: the Environment alerts
/// section alone stacks six of them. 14 with `isDense` keeps every field at or
/// above the 48dp touch floor (`settings_screen_test.dart` measures it rather
/// than assuming it) and gives back ~10dp per field, which is ~60dp on that one
/// section.
///
/// Applied per field rather than in `main.dart` on purpose: the dashboard's own
/// inputs keep the roomier padding, and a global change would be a different
/// decision made by a different screen.
InputDecoration settingsFieldDecoration({
  String? label,
  String? helperText,
  String? suffixText,
  Widget? prefixIcon,
}) => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  labelText: label,
  helperText: helperText,
  suffixText: suffixText,
  prefixIcon: prefixIcon,
);

/// A toggle row, sized for a column of fields rather than for a list.
///
/// `dense` + `compact` is what removes the 16dp of vertical padding Material
/// puts on a two-line `SwitchListTile`. It is *not* `ListTile` with
/// `dense: true` plus a height assertion: the density here is Material's own,
/// and the row it produces is still a full-width tappable `SwitchListTile`, so
/// the ink layer, the semantics node and the switch's own 48dp target are
/// unchanged. `settings_screen_test.dart` pins the resulting height.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      isThreeLine: false,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppType.labelUppercase),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppType.bodySm.copyWith(
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
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
      decoration: settingsFieldDecoration(
        label: label,
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
      padding: const EdgeInsets.only(top: 6),
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
          const SizedBox(height: 6),
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
              const SizedBox(width: 8),
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
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
      decoration: settingsFieldDecoration(
        label: label,
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
/// * **The tinted hard shadow**, `AppShadows.stampedIn(AppPalette.error)`.
///   That is the brief's signature move for the one button allowed to be
///   electric: a solid offset rectangle in the accent at 20%, no blur, so the
///   displacement itself bleeds the same colour as the fill.
///
/// The shadow is painted by a [DecoratedBox] *behind* the button rather than by
/// `FilledButton.styleFrom`, because Material's `elevation` maps through
/// `kElevationToShadow` and can only ever produce a blurred halo — the exact
/// thing the brief bans. `DecoratedBox` paints its decoration first and then its
/// child, so only the 4px offset strip is visible around the opaque accent fill.
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
        boxShadow: AppShadows.stampedIn(AppPalette.error),
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
            backgroundColor: AppPalette.error,
            foregroundColor: AppPalette.onHue,
            // Both disabled colours keep the fill and the ink, so the button
            // does not grey out behind the spinner mid-write. It is still
            // disabled — `onPressed` is null — it just says so with its label
            // rather than by turning into a different button.
            disabledBackgroundColor: AppPalette.error,
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

/// The brief's `button-secondary`: the page fill behind a hairline, no shadow.
///
/// Used by the two actions inside the Background checks card and by Logout. It
/// sits on the card rather than on the page, so its fill is *darker* than its
/// surround — which is the brief's own relationship (`background` below
/// `surface`) applied one level down, and it reads as an action set into the
/// card without needing a second outline colour.
///
/// **48dp, not the brief's 56.** These are secondary actions inside a card that
/// is already dense, and 48 is the accessibility floor, so dropping to it costs
/// no reachability and buys 8dp per button on the two pages that stack them.
/// The primary CTA ([SaveSettingsButton]) keeps its 56 — the one button on the
/// screen that is allowed to be large is still large.
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
        // **Page ink on a page-coloured fill**, for the same reason the energy
        // report's period button gives up card ink: `AppSurfaces.page` is
        // near-black on the dark ramp and pale on the light one, so the ink has
        // to follow it. Card ink is navy in both ramps since the cards went
        // near-white and measured **1.22:1** against this fill in dark mode —
        // "Check now" and "Battery settings" were two black rectangles with no
        // visible label.
        foregroundColor: AppGlass.pageInkStrong,
        disabledBackgroundColor: AppSurfaces.page,
        disabledForegroundColor: AppGlass.pageInkSoft,
        side: AppBorders.hairline,
        textStyle: AppType.buttonLabel,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.all(AppRadius.card),
        ),
      ),
    );
  }
}
