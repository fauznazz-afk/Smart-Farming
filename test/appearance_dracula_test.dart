import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/settings/sections/appearance_section.dart';
import 'package:plts_monitoring/screens/settings_screen.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Dracula control in Settings, and the three promises it makes.
///
/// **Why this file exists separately from `settings_screen_test.dart`.** That file
/// is a navigator test — it opens a section and asserts a string is on it. The
/// claims here are about *state*: which `ThemeOption` the controller holds, which
/// `AppTheme` the swatch row resolves to, and what the stored seed is after a
/// round trip. None of them is observable from a `find.text`, which is exactly
/// the kind of assertion that let the three label regressions in AGENTS.md
/// through. So these assertions read the controller and the store.
///
/// **What the three promises are, and why each one is a separate risk.**
///
///  1. *Selecting Dracula sets the option.* The write has to go through
///     `setOption` and not through `setThemeMode`. `setThemeMode` converts out
///     through `ThemeOption.fromThemeMode`, which is deliberately lossy —
///     `ThemeMode.dark` cannot say whether the user chose dark or Dracula — so a
///     brightness-only write would leave the controller reading `dark` while the
///     user is looking at a purple page, and the drift would be invisible until
///     the next launch re-read the stored string.
///
///  2. *The accent is not user-settable while the preset is active.* Dracula
///     carries its own accent, and the swatch row saying otherwise is a control
///     that looks like it works. `onSelected: null` is what makes a `ChoiceChip`
///     render as disabled, and it is a *rendering* fact, so the assertion is on
///     the widget rather than on the notice text — a notice that says the right
///     thing while the chips stay live is still the defect.
///
///  3. *Leaving Dracula restores the stored accent.* The whole reason the seed is
///     stored rather than overwritten is this, and it is the one claim that can
///     pass while the UI is correct: the accent is a getter over the option, so
///     `accent` returns the right colour whether or not the seed survived. Only
///     reading the store after the round trip tells you whether a later write
///     still has something to restore.
void main() {
  const seedKey = 'theme_seed';
  const modeKey = 'theme_mode';

  late AppThemeController themeController;

  /// Pumps the whole Settings screen at a phone-sized surface, because the
  /// Appearance section is a scrollable page inside it and the behaviour under
  /// test is on that page rather than on the category list.
  ///
  /// [pageColor] is the scaffold colour. That is the contract `appThemeOf` reads
  /// the active [AppTheme] out of, and it is also the only way a widget with no
  /// controller — which is every widget in the Appearance section except the one
  /// holding `settings` — can know it is in Dracula. Passing
  /// [AppSurfaces.pageDracula] is what the app's own `main.dart` does, so this
  /// is a reproduction of the real frame rather than a special case for the
  /// test.
  Future<void> pumpSettings(
    WidgetTester tester, {
    Color? pageColor,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: themeController.accent),
          scaffoldBackgroundColor:
              pageColor ?? AppSurfaces.page(AppTheme.dark),
        ),
        home: SettingsScreen(
          themeController: themeController,
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
  }

  /// Taps a segment of the theme control, scrolling it into view first.
  ///
  /// **This helper is load-bearing, and it used to hide a release blocker.**
  /// The control was a horizontal `SingleChildScrollView`, and `ensureVisible`
  /// made every tap on Dracula and Skeuo succeed. Meanwhile the real device
  /// showed three segments and about 3dp of the fourth, with no scrollbar, no
  /// fade and no hint: the options were reachable only by a swipe nothing
  /// advertised, so a user could not find Skeuo at all. Every assertion in this
  /// file passed against a control that shipped two of its five options
  /// off-screen.
  ///
  /// That is why `find.text(label)` is not enough on its own anywhere near this
  /// control — a widget test finds a widget that is laid out, not one the user
  /// can see — and why the group below asserts the geometry rather than the
  /// presence of labels. The control is now stacked, so this only scrolls the
  /// page vertically; it is kept because a test that taps by bare text would
  /// break the moment the control is ever taller than the viewport again.
  Future<void> tapSegment(WidgetTester tester, String label) async {
    final target = find.descendant(
      of: find.byType(SegmentedButton<ThemeOption>),
      matching: find.text(label),
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> boot({Map<String, Object> stored = const {}}) async {
    SharedPreferences.setMockInitialValues(stored);
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'EnerGrow',
      packageName: 'tech.mbkm.energrow',
      version: '1.3.1',
      buildNumber: '9',
      buildSignature: '',
    );
    themeController = AppThemeController();
    await themeController.load();
  }

  group('the theme control offers Dracula', () {
    setUp(() => boot());

    testWidgets('the control has five options, not four', (tester) async {
      await pumpSettings(tester);

      // The claim is a *count*, not the presence of one label: a control that
      // grew a second widget for a preset would show the word without making
      // these five one choice, and that is the arrangement that says the others
      // are more fundamental than the preset.
      for (final label in [
        'System',
        'Light',
        'Dark',
        'Dracula',
        // Skeuo, added 7 October 2026 as a fourth preset beside Dracula rather
        // than as a replacement for the three the user can still choose.
        'Skeuo',
      ]) {
        expect(
          find.descendant(
            of: find.byType(SegmentedButton<ThemeOption>),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: 'the theme control must offer $label',
        );
      }
    });

    testWidgets('every segment is on screen, with nothing to scroll',
        (tester) async {
      // The presence test above is the claim that hid the release blocker.
      // `find.text` succeeds on a widget that is laid out *outside* the visible
      // area, so a control that parks two of its five options off the right
      // edge passes it — and then ships Skeuo, the headline of the release,
      // where no user can reach it.
      //
      // The cause is a `SegmentedButton` implementation detail worth pinning
      // here, because it is not obvious and it is not a padding problem:
      // `_calculateHorizontalChildSize` takes a `max` over the segments'
      // intrinsic widths and gives that one width to *every* segment, so a
      // horizontal row of N segments is N times its widest segment. Five
      // icon-and-label segments are about 515dp against 375dp of phone, and
      // each segment additionally carries a 64dp `minimumSize` that
      // `segmentStyleFor` drops on the way through, so no amount of tightening
      // gets under 320dp. A horizontal five simply does not fit.
      await pumpSettings(tester);

      final screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final control = find.byType(SegmentedButton<ThemeOption>);

      final controlRect = tester.getRect(control);
      expect(
        controlRect.right <= screen.width,
        isTrue,
        reason: 'the control measures ${controlRect.width}dp wide against a '
            '${screen.width}dp screen, so it can only be showing part of '
            'itself. Five segments in one horizontal row cannot fit a phone.',
      );

      for (final label in const [
        'System',
        'Light',
        'Dark',
        'Dracula',
        'Skeuo',
      ]) {
        final rect = tester.getRect(
          find.descendant(of: control, matching: find.text(label)),
        );
        expect(
          rect.left >= 0 && rect.right <= screen.width,
          isTrue,
          reason: '$label is laid out from x=${rect.left} to x=${rect.right}, '
              'which is off a ${screen.width}dp screen. It is laid out, so '
              'every find.text in this file still passes — and the user cannot '
              'see it. An option that has to be discovered by swiping is an '
              'option they do not have.',
        );
      }
    });

    testWidgets('tapping Dracula sets the option and stores it', (tester) async {
      await pumpSettings(tester);

      expect(themeController.option, ThemeOption.dark,
          reason: 'the app has always defaulted to dark, so the control has to '
              'start there or this test proves nothing about the tap');

      await tapSegment(tester, 'Dracula');

      expect(
        themeController.option,
        ThemeOption.dracula,
        reason: 'the control reads `option` and writes `setOption`; a write '
            'through `setThemeMode` would store "dark" and leave the controller '
            'reading a brightness the user never chose',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(modeKey),
        'dracula',
        reason: 'read off the store rather than off the controller, because the '
            'controller in memory is the thing under test',
      );
    });

    testWidgets('the selected segment follows the stored option', (tester) async {
      // The other half of the same contract, and the one that fails silently: a
      // control whose `selected` set is built from `themeMode` shows "Dark"
      // highlighted while the app is in Dracula, and that is a lie on the one
      // screen where the user is choosing.
      SharedPreferences.setMockInitialValues({modeKey: 'dracula'});
      themeController = AppThemeController();
      await themeController.load();
      await pumpSettings(
        tester,
        pageColor: AppSurfaces.page(AppTheme.dracula),
      );

      final selected = tester
          .widget<SegmentedButton<ThemeOption>>(
            find.byType(SegmentedButton<ThemeOption>),
          )
          .selected;
      expect(
        selected,
        {ThemeOption.dracula},
        reason: 'ThemeMode.dark cannot express Dracula, so a selected set built '
            'from the brightness would highlight the wrong segment',
      );
    });
  });

  group('Dracula owns the accent while it is active', () {
    setUp(() => boot());

    testWidgets('every swatch is disabled', (tester) async {
      await pumpSettings(tester);
      await tapSegment(tester, 'Dracula');

      final chips = find
          .byType(ChoiceChip)
          .evaluate()
          .map((element) => element.widget as ChoiceChip)
          .toList();
      expect(
        chips.length,
        kAccentPalette.length,
        reason: 'all four swatches must still be laid out. Hiding them would '
            'also stop the user seeing which accent comes back, and the row '
            'moving as the preset is switched on and off is the same thing the '
            'Performance section was deleted for.',
      );
      for (final chip in chips) {
        expect(
          chip.onSelected,
          isNull,
          reason: 'a live chip under a preset is the "looks like it works" '
              'defect. ${chip.label} must be inert.',
        );
      }
    });

    testWidgets('tapping a disabled swatch does not change the seed',
        (tester) async {
      await pumpSettings(tester);
      await tapSegment(tester, 'Dracula');

      final before = themeController.seedColor;
      await tester.tap(find.text('Solar amber'));
      await tester.pumpAndSettle();

      expect(
        themeController.seedColor,
        before,
        reason: 'even if a tap reached the handler, a preset is not a place '
            'where the user\'s accent is being re-chosen',
      );
    });

    testWidgets('the reason is stated, and the swatches are shown greyed',
        (tester) async {
      await pumpSettings(tester);
      await tapSegment(tester, 'Dracula');

      // The notice is the other half of requirement 1: a disabled control with
      // no explanation is a control the user has to guess about, and the guess
      // they are most likely to make is "the app is broken".
      expect(find.text(kPresetAccentNotice), findsOneWidget);
      expect(
        find.textContaining('do not apply'),
        findsOneWidget,
        reason: 'the notice has to say the swatches are inert, not merely that '
            'Dracula has a colour of its own',
      );
      expect(
        find.textContaining('returns'),
        findsOneWidget,
        reason: 'the notice has to say the choice is kept. Without that half the '
            'user is being told their accent setting has been taken away, and '
            'the natural response is to stop using the picker at all.',
      );
    });

    testWidgets('the notice is absent for the other three options',
        (tester) async {
      // A notice that is always on screen is a caption nobody reads, and it
      // would describe a state the app is not in.
      // Navigated once and then driven through the control, rather than
      // re-pumping a fresh screen per option. Re-pumping would put two
      // "Appearance" labels on screen — the category tile and the open
      // section's own title — and the second iteration's tap would be
      // ambiguous. Driving the same control through all three values is also the
      // honest shape of the claim: it is about the control's reaction to a
      // change, not about three independent launches.
      await pumpSettings(tester);

      for (final option in [
        ThemeOption.system,
        ThemeOption.light,
        ThemeOption.dark,
      ]) {
        await tapSegment(tester, option == ThemeOption.system
            ? 'System'
            : option == ThemeOption.light
            ? 'Light'
            : 'Dark');
        expect(
          themeController.option,
          option,
          reason: 'the control must actually apply $option for the assertions '
              'below to be about that option',
        );

        expect(
          find.text(kPresetAccentNotice),
          findsNothing,
          reason: '$option does not own the accent, so the notice is wrong',
        );
        final chips = find.byType(ChoiceChip).evaluate();
        expect(chips, hasLength(kAccentPalette.length));
        for (final element in chips) {
          expect((element.widget as ChoiceChip).onSelected, isNotNull,
              reason: 'the swatches must be live when no preset is active');
        }
      }
    });

    testWidgets('the notice colour clears AA on light and on Dracula',
        (tester) async {
      // The claim is measured rather than asserted, and it is measured against
      // the real surfaces out of `AppSurfaces` rather than against a hex written
      // here — the mistake `test/color_helpers_test.dart` documents twice.
      //
      // The copy is 12sp, which is under the 18.66px large-text floor, so 4.5:1
      // is the requirement and not 3:1.
      const required = 4.5;
      final onLight = _contrast(
        faintColor(false),
        AppSurfaces.page(AppTheme.light),
      );
      final onDracula = _contrast(
        faintColor(true),
        AppSurfaces.page(AppTheme.dracula),
      );

      expect(
        onLight,
        greaterThanOrEqualTo(required),
        reason: 'the notice lands on the light page in light mode',
      );
      expect(
        onDracula,
        greaterThanOrEqualTo(required),
        reason: 'the notice lands on Dracula\'s page, and Dracula is the mode it '
            'exists for',
      );
    });
  });

  group('leaving Dracula gives the accent back', () {
    setUp(() => boot());

    testWidgets('the stored seed survives a round trip through the preset',
        (tester) async {
      await pumpSettings(tester);

      // Choose a seed the user would actually recognise as theirs. The default
      // green is excluded on purpose: with the default, "the accent came back"
      // and "the accent fell back to the default" are indistinguishable, so the
      // test would pass against a controller that discards the seed.
      await tester.tap(find.text('Ocean cyan'));
      await tester.pumpAndSettle();
      final chosen = themeController.accent;
      expect(chosen, const Color(0xFF2AA7A1));

      await tapSegment(tester, 'Dracula');
      expect(themeController.accent, draculaAccent,
          reason: 'Dracula paints its own accent, which is the whole point');

      await tapSegment(tester, 'Light');
      expect(
        themeController.accent,
        chosen,
        reason: 'switching back must restore the colour the user picked, not '
            'the app default',
      );
    });

    testWidgets('the seed is still in storage after the round trip',
        (tester) async {
      // The round trip above reads `accent`, which is a *getter over the option*.
      // A controller that never stored the seed would still pass it. This is
      // the assertion that says the value is genuinely there for a later write.
      await pumpSettings(tester);
      await tester.tap(find.text('Forest teal'));
      await tester.pumpAndSettle();

      await tapSegment(tester, 'Dracula');
      await tapSegment(tester, 'Dark');

      final prefs = await SharedPreferences.getInstance();
      expect(
        Color(prefs.getInt(seedKey)!),
        const Color(0xFF2E7D65),
        reason: 'the stored seed is the user\'s accent; a preset must not clear '
            'it, or the next launch has nothing to restore',
      );
    });

    testWidgets('the swatches become live again and the old one is ticked',
        (tester) async {
      // The UI half of the round trip. The controller being correct does not
      // make a greyed-out row correct, and a row that stayed disabled would
      // leave the user with no way back to their accent at all.
      await pumpSettings(tester);
      await tester.tap(find.text('Solar amber'));
      await tester.pumpAndSettle();

      await tapSegment(tester, 'Dracula');
      expect(find.text(kPresetAccentNotice), findsOneWidget);

      await tapSegment(tester, 'System');

      expect(find.text(kPresetAccentNotice), findsNothing);
      for (final element in find.byType(ChoiceChip).evaluate()) {
        expect((element.widget as ChoiceChip).onSelected, isNotNull);
      }
      final amber = find
          .byType(ChoiceChip)
          .evaluate()
          .map((e) => e.widget as ChoiceChip)
          .firstWhere((chip) => (chip.label as Text).data == 'Solar amber');
      expect(
        amber.selected,
        isTrue,
        reason: 'the tick marks the stored preference, which is what will be '
            'painted again — it is the one piece of information the user needs '
            'to know their choice is still theirs',
      );
    });
  });

  group('existing installs', () {
    testWidgets('a stored light theme is untouched and still editable',
        (tester) async {
      // The migration case, end to end through the UI. An existing user has
      // 'light' on disk and a seed they chose; neither may change because a
      // fourth option was added.
      SharedPreferences.setMockInitialValues({
        modeKey: 'light',
        seedKey: 0xFF2AA7A1,
      });
      themeController = AppThemeController();
      await themeController.load();
      await pumpSettings(
        tester,
        pageColor: AppSurfaces.page(AppTheme.light),
      );

      expect(themeController.option, ThemeOption.light);
      for (final element in find.byType(ChoiceChip).evaluate()) {
        expect((element.widget as ChoiceChip).onSelected, isNotNull,
            reason: 'the accent must stay pickable in light mode — an existing '
                'user is the one most likely to be changing it');
      }
      final cyan = find
          .byType(ChoiceChip)
          .evaluate()
          .map((e) => e.widget as ChoiceChip)
          .firstWhere((chip) => (chip.label as Text).data == 'Ocean cyan');
      expect(cyan.selected, isTrue,
          reason: 'their stored accent is read back and shown as selected');
    });

    testWidgets('an unrecognised stored value is not silently rewritten',
        (tester) async {
      // A value this build does not know must fall back the way the controller
      // already does — to dark — and must not be written back, or a user who
      // downgrades and re-upgrades would have had their key rewritten by the
      // build in between. Asserted on the store because the controller would
      // hide it.
      SharedPreferences.setMockInitialValues({modeKey: 'solarized'});
      themeController = AppThemeController();
      await themeController.load();
      await pumpSettings(tester);

      expect(themeController.option, ThemeOption.dark,
          reason: 'the fallback is dark because that is what it has always '
              'been; "improving" it to system would change what a fresh install '
              'sees for no reason connected to this change');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(modeKey),
        'solarized',
        reason: 'nothing in this screen may rewrite a value it did not write. '
            'Opening Appearance is not consent to be migrated.',
      );
    });
  });
}

/// WCAG relative-luminance contrast, so the AA claim in the notice test is a
/// measurement and not a restatement of the constant it is checking.
///
/// `dart:math`'s `pow`, deliberately. A hand-rolled integer-power loop was tried
/// here to keep the return type `double` and it silently truncated the 2.4
/// exponent to 2, which reported `faintColor` on the light page at 3.66:1 — a
/// value that looks like a genuine contrast failure and is not one. The measured
/// value is 4.56:1, and the bug would have sent someone off to re-tune a colour
/// that is already correct.
double _contrast(Color a, Color b) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color color) =>
      0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);

  final la = luminance(a);
  final lb = luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
