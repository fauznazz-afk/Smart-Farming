import 'package:flutter/material.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
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
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular primary-coloured icon container used as a section/list leading.
class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: theme.colorScheme.onPrimary, size: 19),
    );
  }
}

/// Decimal text field that accepts negative values.
class NumberField extends StatelessWidget {
  const NumberField({super.key, required this.controller, this.label});

  final TextEditingController controller;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
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
            children: [
              Expanded(
                child: NumberField(
                  controller: setting.min,
                  label: 'Min (${setting.unit})',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NumberField(
                  controller: setting.max,
                  label: 'Max (${setting.unit})',
                ),
              ),
            ],
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
    return FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(saving ? 'Saving...' : 'Save settings'),
    );
  }
}
