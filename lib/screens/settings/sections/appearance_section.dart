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

/// The Performance section, and why it no longer exists.
///
/// It held a single switch called "Liquid glass blur", promising "frosted
/// cards, may drop frames on low-end devices", backed by a `BackdropFilter`
/// and a `performanceMode` flag threaded through eight widgets. Every part of
/// that became false when the surface system was replaced: the blur is gone,
/// the card fills are opaque so there is nothing behind them to frost, and the
/// three full-screen ambient orb gradients — the most expensive paint in the
/// app, and the only thing the flag ever meaningfully gated — were deleted. The
/// blur branch had exactly one caller in the entire app, the login screen.
///
/// The section and the switch are removed rather than relabelled. A switch
/// that says it does nothing is still a switch: it occupies a row the user
/// reads as meaningful, it is one more thing to understand, and the next
/// person to read the code has to work out whether the flag is honoured. The
/// stored `performance_mode` preference is left in SharedPreferences
/// untouched — a key nobody reads is harmless, and removing it would mean
/// reasoning about a migration for no user-visible gain.
// Nothing follows this comment. The class that used to be here was removed, and
// this line is the marker so the next reader finds the reasoning above rather
// than an unexplained gap in the section list.
