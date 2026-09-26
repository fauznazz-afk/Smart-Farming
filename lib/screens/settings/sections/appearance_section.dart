import 'package:flutter/material.dart';

import '../settings_controller.dart';

/// Accent colours the user can pick from.
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
      title: const Text('Smooth Glass Mode'),
      subtitle: Text(
        enabled
            ? 'Optimized rendering is enabled'
            : 'Full backdrop blur is enabled',
      ),
      value: enabled,
      onChanged: (value) {
        settings.themeController.setPerformanceMode(value);
        settings.update(() {});
      },
    );
  }
}
