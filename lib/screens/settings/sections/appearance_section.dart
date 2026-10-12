import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../../../services/theme_mode.dart';

/// Light / dark / follow-the-phone.
///
/// **A `SegmentedButton` and not a `SwitchListTile`.** A switch can only carry
/// two states, and "follow the system" is a third one that means something
/// different from either: it is the only mode that changes on its own, when the
/// user toggles Android's own dark theme.
///
/// The widget reads the mode out of [ThemeModeScope] rather than taking it as a
/// parameter, so it rebuilds when the root rebuilds. The root owns the value —
/// see `main.dart`, where the same `setState` that swaps the palette is what
/// makes this re-render — and this screen only ever asks it to change.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ThemeModeScope.of(context);
    if (scope == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('Auto'),
              icon: Icon(Icons.phone_android_outlined),
            ),
          ],
          selected: {scope.mode},
          showSelectedIcon: false,
          onSelectionChanged: (modes) => scope.onChanged(modes.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _hintFor(scope.mode),
          style: AppType.bodySm.copyWith(color: AppSurfaces.onSurfaceVariant),
        ),
      ],
    );
  }

  /// One line saying what the chosen mode will actually do.
  ///
  /// **"Auto" is the only one that needs explaining**, and it is the default,
  /// so the sentence is written for someone who never opened this screen. The
  /// other two are named by their own buttons.
  String _hintFor(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Always light, whatever the phone is set to.',
        ThemeMode.dark => 'Always dark, whatever the phone is set to.',
        ThemeMode.system =>
          'Follows your phone. Change it in Android settings, not here.',
      };
}
