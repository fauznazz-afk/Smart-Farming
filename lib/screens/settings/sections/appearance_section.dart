import 'package:flutter/material.dart';

import '../../../theme/app_theme_controller.dart';
import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
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

/// The copy shown under a swatch row that a preset has taken over.
///
/// **It exists because "the control is greyed out" is not a reason.** A disabled
/// row tells the user the picker is unavailable and nothing else; it does not
/// tell them *why*, whether the choice they make will be remembered, or what they
/// have to do to get a pickable accent back. All three are things a user is
/// entitled to know before they touch a control, and all three are things that
/// are otherwise invisible. The wording is deliberately concrete about the
/// second one — "your choice is saved and returns" — because the alternative
/// failure is a user who concludes the swatches are broken and gives up on the
/// accent entirely.
///
/// A caption in `faintColor`, which is the palette this app measures for AA on
/// every caption surface: 4.56:1 on the light page and 6.58:1 on Dracula's
/// `#282A36`, both asserted in `test/color_helpers_test.dart`. No new colour was
/// introduced for it, and no status colour is used either — a preset being
/// active is not a condition anything is wrong about, and `statusWarn` for a
/// deliberate choice would be the "two palettes on screen at once" failure the
/// status palette exists to prevent.
const String kPresetAccentNotice =
    'Dracula brings its own accent color, so these swatches do not apply while '
    'it is on. Your choice is saved and returns when you pick Light or Dark.';

/// Theme mode selector plus accent colour picker.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final themeController = settings.themeController;
    // `option` and not `themeMode`. They are the same for `system`, `light` and
    // `dark`, and they are *not* the same for Dracula: `themeMode` collapses it
    // to [ThemeMode.dark], because Material has no third brightness. A control
    // built on `themeMode` could not show Dracula as selected, and one built on
    // `option` cannot lose it — which is the drift this call site is written to
    // avoid. `setOption` below is the write half of the same rule.
    final option = themeController.option;
    // Whether the swatches are inert. Asked as *the resolved theme* rather than
    // as `option == ThemeOption.dracula`, because `usesPresetAccent` is the
    // property that actually matters and it is the thing a second preset would
    // set. Comparing the option directly would hard-code the one preset this
    // file knows about, which is the same trap as `kAccentPalette` growing a hue
    // to accommodate a new chip.
    final presetOwnsAccent = resolveAppTheme(
      option,
      Theme.of(context).brightness,
    ).usesPresetAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Four segments rather than three plus a switch elsewhere. The control
        // *is* "which of these appearances", and Dracula is one of them — a
        // second control for it would say the other three are more fundamental,
        // which is exactly backwards. A brightness-only caller cannot express
        // the fourth option at all, which is the whole reason the enum exists.
        //
        // The horizontal scroll is there because four icon-and-label segments do
        // not fit the content column of a 360dp phone: the segments measure
        // about 368dp together, and `SegmentedButton` has no scrolling of its
        // own, so a `Row` of the four would overflow and Flutter would draw the
        // striped box over the control the user is reaching for. The same
        // treatment the alarm-history filter row uses for the same reason.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<ThemeOption>(
            showSelectedIcon: false,
            // No new colour for the selected state. The existing
            // `SegmentedButtonThemeData` in `main.dart` paints the selected
            // segment as a low-alpha wash of the accent, and it is inherited
            // here exactly as it was for the three existing segments. Adding a
            // Dracula-specific selected colour would break the rule in
            // `main.dart`'s own comment — the selected segment is the user's
            // accent, at a weight that does not compete with the numbers — and
            // it would be the second place the app decides a colour for the
            // user.
            segments: const [
              ButtonSegment(
                value: ThemeOption.system,
                label: Text('System'),
                icon: Icon(Icons.settings_suggest_outlined),
              ),
              ButtonSegment(
                value: ThemeOption.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeOption.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeOption.dracula,
                label: Text('Dracula'),
                icon: Icon(Icons.auto_awesome_outlined),
              ),
              ButtonSegment(
                value: ThemeOption.skeuo,
                label: Text('Skeuo'),
                icon: Icon(Icons.view_in_ar_outlined),
              ),
            ],
            selected: {option},
            onSelectionChanged: (selection) {
              themeController.setOption(selection.first);
              settings.update(() {});
            },
          ),
        ),
        const SizedBox(height: 18),
        const Text('Accent color', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAccentPalette.entries.map((entry) {
            // The *stored* seed, so the tick marks what will come back rather
            // than what is painted right now. That distinction is the point: the
            // selection here is a stored preference, and Dracula not honouring it
            // is the one thing about a preset that would otherwise be a lie on
            // screen.
            final selected =
                settings.selectedSeed.toARGB32() == entry.value.toARGB32();
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.all(AppRadius.pill),
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          entry.value.withValues(alpha: 0.25),
                          entry.value.withValues(alpha: 0.12),
                        ],
                      )
                    : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: entry.value.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ChoiceChip(
                label: Text(entry.key),
                selected: selected,
                avatar: CircleAvatar(radius: 9, backgroundColor: entry.value),
                // `onSelected: null` is what a `ChoiceChip` renders as disabled,
                // and it is the same disabled treatment Material would give a
                // disabled control from any other cause. A `IgnorePointer` over an
                // enabled chip was the alternative and was rejected: it leaves the
                // chip *looking* live, so the user discovers the rule by tapping
                // something that silently does nothing — which is the "a control
                // that looks like it works" failure the accent picker would
                // otherwise be.
                onSelected: presetOwnsAccent
                    ? null
                    : (_) {
                        settings.update(() {
                          settings.selectedSeed = entry.value;
                          themeController.setSeedColor(entry.value);
                        });
                      },
              ),
            );
          }).toList(),
        ),
        if (presetOwnsAccent) ...[
          const SizedBox(height: 10),
          Text(
            kPresetAccentNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              // `faintColor` rather than `onSurfaceVariant`, which is what the
              // rest of this screen's secondary text uses. The difference matters
              // here: this sentence is the only place the user is told the
              // swatches are inert, so it has to be on the measured palette. The
              // `onSurfaceVariant` values come from `ColorScheme.fromSeed` and
              // nobody has measured them on any of the six surfaces in
              // `AppSurfaces.captionSurfaces`.
              color: faintColor(
                resolveAppTheme(option, Theme.of(context).brightness).isDark,
              ),
            ),
          ),
        ],
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
