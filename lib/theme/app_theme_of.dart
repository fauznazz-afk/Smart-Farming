import 'package:flutter/material.dart';

import '../screens/dashboard/utils/design_tokens.dart';

/// The [AppTheme] the tree is being painted in, for a screen that has no
/// [AppThemeController].
///
/// **Why a screen cannot derive this from a `Brightness`.** The three screens
/// this exists for — Alarm History, CCTV and the energy report — are pushed by
/// `DashboardScreen` and were never given the controller, so every one of them
/// reads its appearance from the context. That was exact while there were two
/// modes. It stopped being exact when Dracula landed, because
/// `AppTheme.dracula` hands `MaterialApp` [ThemeMode.dark] — Material has no
/// third brightness — so `Theme.of(context).brightness` reports the *same*
/// [Brightness.dark] the app's own dark theme reports, and a bool cannot tell
/// them apart. Each of those screens calls `AppBackground(theme:)`, whose
/// parameter is required precisely because the backdrop is the one surface that
/// *is* the page, so a wrong guess there puts every card in the frame on the
/// wrong ramp.
///
/// **Where the answer comes from, and why.** The same way `MaterialApp`
/// published it: the active theme's `scaffoldBackgroundColor` *is*
/// `AppSurfaces.page(theme)`, so the surface set can be searched rather than the
/// answer guessed. That compares against a token constant and not a hex written
/// here, which is the rule `test/color_helpers_test.dart` already exists to
/// enforce for its surface lists and the reason this cannot go stale the way a
/// hand-written hex did.
///
/// The contract this depends on belongs to whoever owns `main.dart`: the theme
/// in force must set `scaffoldBackgroundColor` to `AppSurfaces.page(theme)` for
/// all three presets, which is what the file already does for light and dark.
/// If Dracula is ever wired up without it, this returns [AppTheme.dark] and
/// Dracula renders as the app's dark mode — on the wrong page colour, the wrong
/// shadow alphas and the wrong elevation geometry. That is a loud, obvious
/// failure rather than a subtle one, which is the right way round.
///
/// **This started as the second implementation of that rule and is now the only
/// one.** `lib/widgets/liquid_glass.dart` grew a private `_appThemeOf` for its
/// own null-[theme] fallbacks while this file was being written, because that
/// file belonged to another agent mid-flight and duplicating a private helper
/// into a public one beat a merge. Both were consolidated here once the tree
/// settled, and this version won because it *searches* [AppTheme.values] rather
/// than hardcoding one preset: a fourth theme needs no edit to this function,
/// where the other version would have silently fallen through to
/// [AppTheme.dark].
///
/// If you change the rule here, `liquid_glass.dart` changes with it — that file
/// holds a one-line delegate for its three internal null-[theme] fallbacks and
/// nothing else.
AppTheme appThemeOf(BuildContext context) {
  final scaffold = Theme.of(context).scaffoldBackgroundColor;
  for (final candidate in AppTheme.values) {
    if (AppSurfaces.page(candidate) == scaffold) return candidate;
  }
  // No match: a theme that painted a page colour this app does not know. Fall
  // back on brightness, which is the answer the app gave before any of this.
  return Theme.of(context).brightness == Brightness.dark
      ? AppTheme.dark
      : AppTheme.light;
}
