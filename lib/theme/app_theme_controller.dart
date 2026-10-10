import 'package:flutter/material.dart';

/// The appearance controller, reduced to a notifier with nothing to notify.
///
/// **This class used to carry two settings — an `AppTheme` option and an accent
/// seed — and both are gone, on purpose and at the user's request.** The four
/// appearances (`light`, `dark`, `dracula`, `skeuo`) are one appearance now, and
/// the categorical palette in `design_tokens.dart` is a *vocabulary*: each
/// category of data owns a fixed hue, reused everywhere that category appears.
/// A user-selectable accent cannot coexist with that, because the two claims are
/// the same claim — "this colour means X" — and only one of them can be fixed.
///
/// Nothing was left in place as a no-op setter. A `setSeedColor` that discards
/// its argument would let the appearance section keep rendering an accent
/// picker that silently does nothing, which is worse than not compiling: a
/// control that looks live and is not. The setters are gone so the section that
/// owned them has to go with them.
///
/// ## Why the class survives at all
///
/// It is still a `ChangeNotifier` and `DashboardScreen` and `LoginScreen` still
/// subscribe to it, so deleting it would be a change to their constructors and
/// their `initState`/`dispose` pairs rather than to this file. It has no state
/// and will never notify. `load()` is kept only so the one call site in
/// `main.dart` survives and the class can be deleted later as a signature change
/// rather than as a behavioural one.
///
/// ## The migration, which needs no code
///
/// Existing installs still have `theme_mode` and `theme_seed` in
/// `SharedPreferences`. **Nothing reads them and nothing deletes them.** An
/// unread key costs nothing; removing it would be a migration with no
/// user-visible gain. The precedent is set in this file's own history by
/// `performance_mode`, whose reader was deleted when the `BackdropFilter` it
/// gated went away and whose key was left exactly where it was.
///
/// The consequence for the user is that a previously chosen theme or accent is
/// silently no longer applied — which is what was asked for, and is not
/// recoverable from within the app because there is nothing left to choose.
class AppThemeController extends ChangeNotifier {
  /// Retained for the call site in `main.dart`. Nothing is read.
  Future<void> load() async {}
}