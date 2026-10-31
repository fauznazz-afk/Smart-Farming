import 'package:flutter/material.dart';

import '../../../services/theme_mode.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../widgets/settings_fields.dart';

/// System / Gelap / Terang, read from and written to the root's own
/// [ThemeModeScope].
///
/// **No save button and no controller field.** The mode is not part of the
/// ThingsBoard settings payload: `AppTheme` is a static that 148 call sites
/// read without a `BuildContext`, so the choice has to be applied and persisted
/// by the root widget that owns it, which `onChanged` already does. Writing it
/// into `SettingsController` as well would put a second writer in the app and
/// make the two disagree after a failed save.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  static const Map<ThemeMode, String> _labels = {
    ThemeMode.system: 'Ikuti sistem',
    ThemeMode.light: 'Terang',
    ThemeMode.dark: 'Gelap',
  };

  @override
  Widget build(BuildContext context) {
    final scope = ThemeModeScope.of(context);
    return SectionCard(
      title: 'Tema',
      subtitle: 'Warna terang atau gelap untuk seluruh aplikasi.',
      icon: Icons.palette_outlined,
      child: Column(
        children: [
          // RadioGroup rather than the deprecated per-tile `groupValue` /
          // `onChanged` pair, which Flutter 3.32 moved onto the ancestor.
          RadioGroup<ThemeMode>(
            groupValue: scope?.mode,
            onChanged: (value) {
              if (value != null) scope?.onChanged(value);
            },
            child: Column(
              children: [
                for (final entry in _labels.entries)
                  RadioListTile<ThemeMode>(
                    value: entry.key,
                    // A tree built outside the root's builder has no scope, and
                    // a radio that silently does nothing is worse than one
                    // that is visibly disabled.
                    enabled: scope != null,
                    title: Text(entry.value),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mode terang masih dalam penyempurnaan: beberapa kartu memakai '
            'isi kaca yang dirancang untuk latar gelap.',
            style: AppType.captionSmall.copyWith(
              color: AppSurfaces.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
