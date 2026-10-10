import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsIconBadge(icon: icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 8),
              child: AppDivider(opacity: 0.12),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

/// Circular accent icon container used as a section/list leading.
///
/// Flat circle with [AppSurfaces.surface] fill, [AppBorders.control] border,
/// and [AppPalette.accent] icon.
class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppSurfaces.surface,
        shape: BoxShape.circle,
        border: AppBorders.controlBorder,
      ),
      child: Icon(icon, color: AppPalette.accent, size: 19),
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
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: inactive
          ? theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            )
          : null,
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
          Text(setting.label, style: Theme.of(context).textTheme.labelLarge),
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
    final theme = Theme.of(context);
    // **Counting fields, not ranges. This said "3 limits" while the screen showed
    // five.** It counted the ranges that had at least one prefilled side, and the
    // Environment screen has three of those -- temperature, humidity, TDS -- with
    // five prefilled *fields* between them, because temperature and humidity
    // prefill both ends and TDS prefills only its minimum.
    //
    // Found on an emulator: the sentence at the bottom of the card read "3 limits
    // are shown as defaults" directly under five fields each captioned "Not saved
    // yet". A count that contradicts the thing it is counting is worse than no
    // count, and it is exactly the failure `FEATURE.md` records for
    // `_history` being reported dead: a number that looks authoritative and is not.
    final count = ranges.fold<int>(
      0,
      (sum, r) => sum + (r.minIsPrefill ? 1 : 0) + (r.maxIsPrefill ? 1 : 0),
    );
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              count == 1
                  ? '1 limit is shown as a default. It is not monitored until '
                      'you save.'
                  : '$count limits are shown as defaults. They are not '
                      'monitored until you save.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
          .map((option) => DropdownMenuItem(
                value: option,
                child: Text('$option$suffix'),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Primary save action shown while browsing the settings list.
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
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(saving ? 'Saving...' : 'Save settings'),
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: AppPalette.onHue,
          textStyle: AppType.labelUppercase,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.all(AppRadius.pill),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
