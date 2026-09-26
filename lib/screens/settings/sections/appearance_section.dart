import 'package:flutter/material.dart';

import '../settings_controller.dart';

/// Accent colours the user can pick from.
///
/// These are four explicit choices, and changing one changes what an existing
/// setting means. `Ocean cyan` and `Forest teal` do sit close in hue, which was
/// made worse by moving `Ocean cyan` to `0xFF2E9BD6` to separate them. That
/// separation was reverted: a user who already picked "Ocean cyan" would have
/// silently been given a different colour, which is worse than two swatches
/// looking similar. Picking a different accent is done in this screen, not by
/// the app deciding.
const Map<String, Color> kAccentPalette = {
  'EnerGrow green': Color(0xFF35A968),
  'Solar amber': Color(0xFFF4B942),
  'Ocean cyan': Color(0xFF2AA7A1),
  'Forest teal': Color(0xFF2E7D65),
};

/// Theme mode selector plus accent colour picker.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.settings_suggest_outlined),
            ),
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
          ],
          selected: {settings.themeController.themeMode},
          onSelectionChanged: (selection) {
            settings.themeController.setThemeMode(selection.first);
            settings.update(() {});
          },
        ),
        const SizedBox(height: 18),
        const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAccentPalette.entries.map((entry) {
            final selected =
                settings.selectedSeed.toARGB32() == entry.value.toARGB32();
            return ChoiceChip(
              label: Text(entry.key),
              selected: selected,
              avatar: CircleAvatar(radius: 9, backgroundColor: entry.value),
              onSelected: (_) {
                settings.update(() {
                  settings.selectedSeed = entry.value;
                  settings.themeController.setSeedColor(entry.value);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Toggle for the reduced glass-effect rendering mode.
class PerformanceSection extends StatelessWidget {
  const PerformanceSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final enabled = settings.themeController.performanceMode;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      // Named for what it does. It used to be called "Smooth Glass Mode", so
      // switching it *on* turned the blur *off*, which is the opposite of what
      // the name promises.
      title: const Text('Liquid glass blur'),
      subtitle: Text(
        enabled
            ? 'Off — flat cards, smoother scrolling'
            : 'On — frosted cards, may drop frames on low-end devices',
      ),
      value: enabled,
      onChanged: (value) {
        settings.themeController.setPerformanceMode(value);
        settings.update(() {});
      },
    );
  }
}
