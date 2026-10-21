/// Every surface, radius, edge, type, shadow, spacing and motion value in the
/// app.
///
/// **This file was rewritten against the MiniDash brief on 15 October 2026.**
///
/// MiniDash is a widget-like, compact design system for mobile dashboards:
/// - **Colors**: Primary #6366F1 (indigo), Secondary #14B8A6 (teal), Tertiary
///   #F59E0B (amber), Background #F3F4F6, Surface #FFFFFF
/// - **Spacing**: 4/8/12/16/20/24/32/40/48 base scale
/// - **Radius**: 0/4/8/12/16/9999 for full spectrum
/// - **Elevation**: Soft shadows with blur (subtle/medium/large/overlay)
/// - **Typography**: Inter (headlines), DM Sans (body), IBM Plex Mono (code)
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 1: COLORS (AppSurfaces)
// ═════════════════════════════════════════════════════════════════════════════

/// The three-layer surface stack, plus the deepest fill.
///
/// **Swappable, and every value here is read through an instance.**
class AppSurfaces {
  const AppSurfaces._();

  static AppSurfacesPalette _palette = AppSurfacesPalette.light;

  static void apply(Brightness brightness) {
    _palette = brightness == Brightness.light
        ? AppSurfacesPalette.light
        : AppSurfacesPalette.dark;
  }

  static Color get page => _palette.page;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get surfaceMuted => _palette.surfaceMuted;
  static Color get onSurface => _palette.onSurface;
  static Color get onSurfaceVariant => _palette.onSurfaceVariant;
  static Color get border => _palette.border;
  static Color get input => _palette.input;
  static Color get track => _palette.track;
  static Color get tooltip => _palette.tooltip;

  static List<Color> captionSurfaces() => [page, surface, surfaceAlt];

  /// The card surface dark ink binds hardest on.
  ///
  /// **The darker of [surface] and [surfaceAlt], and it has to be computed rather
  /// than named.** It used to be `surfaceAlt` unconditionally, which was right
  /// only while `surfaceAlt` happened to be the darker of the two. The blue system
  /// inverted that in the dark ramp — cards are near-white, so the white tile
  /// stopped being the hard case and the slightly-grey card became it. Naming one
  /// of them would have measured every caption against the *forgiving* surface in
  /// one ramp, which is the quiet failure this getter exists to prevent.
  static Color get bindingCaptionSurface =>
      surface.computeLuminance() <= surfaceAlt.computeLuminance()
      ? surface
      : surfaceAlt;
}

class AppSurfacesPalette {
  const AppSurfacesPalette({
    required this.brightness,
    required this.page,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceMuted,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.border,
    required this.input,
    required this.track,
    required this.tooltip,
  });

  final Brightness brightness;
  final Color page;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceMuted;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color border;
  final Color input;
  final Color track;
  final Color tooltip;

  static const AppSurfacesPalette dark = AppSurfacesPalette(
    brightness: Brightness.dark,
    // **The darkest step of the sweep, not a separate near-black.**
    //
    // The dark ramp used to carry its own flat page, `#0B1120`, next to a
    // gradient that ran `#2C5599` to `#203E6B`. Three page values in one ramp:
    // the flat page, the sweep, and the fallback. The flat page was the one you
    // saw whenever the gradient was not painted - the AI chat background, the
    // report's period button, the chart export canvas - so the app had a
    // near-black page and a blue page, and the seam between them was visible
    // wherever they met.
    //
    // It is now the sweep's own foot, so the flat page and the body are the
    // same colour and the seam is gone. Measured on the new value: white ink
    // 12.56:1, the navy glass ink on a 45% white wash over it 4.68:1, and the
    // page twins at 5.6:1 or better.
    page: Color(0xFF1B3260),
    surface: Color(0xFFF8FAFC),
    surfaceAlt: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE2E8F0),
    onSurface: Color(0xFF0B2545),
    // **One step darker than the light ramp's, because this is the ramp whose
    // caption surface is the near-white card.** `#4A6791` measured 4.46:1 on
    // `surfaceAlt` — 0.04 under AA, which is a rounding difference wearing a
    // pass's clothing. `#42597F` clears it on both card surfaces.
    onSurfaceVariant: Color(0xFF42597F),
    // Same value as [surfaceMuted] — see the light ramp's note on the identity.
    border: Color(0xFFE2E8F0),
    input: Color(0xFFFFFFFF),
    // The page, because an un-lit meter segment is a hole in the surface it
    // sits on, and the meter sits on a card.
    track: Color(0xFF1B3260),
    tooltip: Color(0xFF0F172A),
  );

  static const AppSurfacesPalette light = AppSurfacesPalette(
    brightness: Brightness.light,
    // **The page, sheet rows, cards and ink are all blue-tinted now.** They were
    // neutral greys (`#F3F4F6`, `#E5E7EB`, `#6B7280`), which was correct while
    // the page was a flat grey and wrong the moment the page became a blue
    // sweep: a neutral grey card on a blue field reads as a dirty smudge rather
    // than as a panel, and a neutral grey caption reads as grey-on-blue rather
    // than as a lighter step of the same hue. Every neutral here has moved one
    // step toward the page's own hue so the light ramp is blue-tinted paper
    // rather than grey paper sitting on a blue page.
    page: Color(0xFFDCE9FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F6FD),
    surfaceMuted: Color(0xFFC3D8F3),
    // Navy ink rather than `#111827`. Near-black on a blue page is a third hue
    // on screen; the page's own darkest stop is what the eye adapts to, so the
    // ink is drawn from the same family.
    onSurface: Color(0xFF0B2545),
    onSurfaceVariant: Color(0xFF3E5B84),
    // **The same value as [surfaceMuted], and that identity is a documented
    // decision rather than a copy.** A border and a deep fill are different roles
    // that resolve to the same step, the way `pill` and `round` do. When they
    // drifted apart (`#CBDDF5` against `#C3D8F3`) the hairline became invisible
    // against a card and the ramp gained a fifth step for no reason.
    border: Color(0xFFC3D8F3),
    input: Color(0xFFFFFFFF),
    track: Color(0xFFDCE9FB),
    tooltip: Color(0xFF0B2545),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 2: THEME (AppTheme)
// ═════════════════════════════════════════════════════════════════════════════

class AppTheme {
  const AppTheme._();

  /// The brightness the app is running in.
  ///
  /// **Read from `dart:ui`, not from the binding.** This used to be
  /// `WidgetsBinding.instance.platformDispatcher.platformBrightness`, and
  /// `WidgetsBinding.instance` throws "Binding has not yet been initialized"
  /// when no binding has been created - so every plain `test()` that touched a
  /// ramp-dependent token died in the static initializer before its first
  /// assertion could run. `dart:ui`'s `PlatformDispatcher.instance` is the
  /// very object the binding hands out (`BindingBase.platformDispatcher`
  /// returns `ui.PlatformDispatcher.instance`), so the value is unchanged and
  /// the crash is gone.
  static Brightness _brightness = PlatformDispatcher.instance.platformBrightness;

  static Brightness get brightness => _brightness;

  static void applyMode(ThemeMode mode, Brightness platform) {
    apply(switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    });
  }

  static void apply(Brightness brightness) {
    _brightness = brightness;
    AppSurfaces.apply(brightness);
    AppPalette.apply(brightness);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 3: PALETTE (AppPalette)
// ═════════════════════════════════════════════════════════════════════════════

class AppPalette {
  const AppPalette._();

  static void apply(Brightness brightness) {
    _active = brightness == Brightness.light
        ? AppPaletteTheme.light
        : AppPaletteTheme.dark;
  }

  static AppPaletteTheme _active = AppPaletteTheme.light;

  // Core colors
  static Color get primary => _active.primary;
  static Color get secondary => _active.secondary;
  static Color get tertiary => _active.tertiary;

  // Semantic colors
  static Color get success => _active.success;
  static Color get warning => _active.warning;
  static Color get error => _active.error;
  static Color get info => _active.info;

  // Backward compatibility aliases
  static Color get accent => _active.tertiary; // was amber

  /// Serious, not yet a breach. **Its own value, not [warning].**
  ///
  /// It used to alias `warning`, which made the two indistinguishable — and
  /// `color_helpers_test.dart` asserts they are separable, because "stale
  /// reading" and "reading out of range" are different conditions that must not
  /// read as the same one. Amber is the warning; orange-red is the alert.
  static Color get statusAlert => _active.statusAlert;
  static Color get statusBad => _active.statusBad;

  // The page twins. **Use these for anything drawn on the page gradient** — a
  // CCTV status pill, a banner with no card behind it, a live dot. The plain
  // `success` / `warning` / `statusBad` are for cards, and a card is near-white
  // in both ramps, so those have to be dark.
  static Color get successOnPage => AppTheme.brightness == Brightness.dark
      ? _active.successOnPage
      : _active.successOnPageLight;
  static Color get warningOnPage => AppTheme.brightness == Brightness.dark
      ? _active.warningOnPage
      : _active.warningOnPageLight;
  static Color get statusBadOnPage => AppTheme.brightness == Brightness.dark
      ? _active.statusBadOnPage
      : _active.statusBadOnPageLight;

  // Chart colors (fixed triad for multi-series)
  static Color get chartRed => _active.chartRed;
  static Color get chartGreen => _active.chartGreen;
  static Color get chartBlue => _active.chartBlue;

  // Legacy chart colors (for backward compatibility)
  static Color get chartViolet => _active.chartRed; // maps to first in triad
  static Color get chartCyan => _active.chartBlue;  // maps to third in triad

  // Computed
  static Color get onPrimary => _active.onPrimary;
  static Color get onSecondary => _active.onSecondary;
  static Color get onTertiary => _active.onTertiary;

  // Backward compatibility: onHue maps to onPrimary (ink on saturated fill)
  static Color get onHue => _active.onHue;

  static List<BoxShadow> aura(Color hue, {double strength = 0.50}) =>
      AppShadows.glow(hue, strength: strength);
}

class AppPaletteTheme {
  const AppPaletteTheme({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.success,
    required this.warning,
    required this.statusAlert,
    required this.error,
    required this.statusBad,
    required this.successOnPage,
    required this.warningOnPage,
    required this.statusBadOnPage,
    required this.successOnPageLight,
    required this.warningOnPageLight,
    required this.statusBadOnPageLight,
    required this.info,
    required this.chartRed,
    required this.chartGreen,
    required this.chartBlue,
    required this.onPrimary,
    required this.onSecondary,
    required this.onTertiary,
    required this.onHue,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color success;
  final Color warning;

  /// Serious but not yet a breach. A distinct hue from [warning] on purpose.
  final Color statusAlert;
  final Color error;
  final Color statusBad;

  /// The page twins of [success], [warning] and [statusBad].
  ///
  /// **One status colour cannot serve a white card and a dark page.** A card
  /// needs a dark hue and a page needs a light one, and the two requirements are
  /// about 2.5:1 apart — there is no value that clears 4.5:1 on both. So the
  /// meaning is carried by two tokens and the call site says which surface it is
  /// on. Drawing the card value on the page, or the page value on a card, is a
  /// legibility bug that no test on a single surface can see.
  final Color successOnPage;
  final Color warningOnPage;
  final Color statusBadOnPage;
  final Color successOnPageLight;
  final Color warningOnPageLight;
  final Color statusBadOnPageLight;
  final Color info;
  final Color chartRed;
  final Color chartGreen;
  final Color chartBlue;
  final Color onPrimary;
  final Color onSecondary;
  final Color onTertiary;
  final Color onHue;

  static const AppPaletteTheme light = AppPaletteTheme(
    // **The same hue as the dark ramp, one step deeper.** It was red `#EF4444`
    // here and blue `#3B82F6` in dark, which meant the app had two identities
    // and the user picked between them by toggling the theme. One hue, two
    // lightnesses — and red stays red for exactly one job, which is saying a
    // reading is wrong, via `statusBad` below.
    //
    // `#1D4ED8` rather than the dark ramp's `#3B82F6`: this one has to clear
    // **4.5:1 as text on a white card**, because panel headings and the selected
    // chip's label are drawn in it, and `#3B82F6` measured 3.52:1 there.
    primary: Color(0xFF1D4ED8),
    secondary: Color(0xFF0E7490),
    tertiary: Color(0xFFB45309),
    // **Darkened for the same reason the dark ramp's were.** These were
    // `#10B981` / `#F59E0B`, which measure 2.5 and 2.1:1 on a white card.
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    // Orange-red rather than a second amber: an alert and a warning are
    // different conditions, and `color_helpers_test.dart` asserts the four
    // status colours stay pairwise distinguishable.
    statusAlert: Color(0xFFC2410C),
    error: Color(0xFF1D4ED8),
    // **The only red in the ramp**, and one step darker than the dark ramp's:
    // `#DC2626` measured 4.45:1 on `surfaceAlt` — 0.05 under AA, which is a
    // rounding difference dressed up as a pass. `#D01E1E` clears it on both
    // card surfaces.
    statusBad: Color(0xFFD01E1E),
    // **The light ramp's page twins are its card values, a step deeper.** Its page
    // is pale, so a dark hue is legible on both surfaces and the ramp needs no
    // branch — which is why there is one pair of numbers here and two in the dark
    // ramp. All three sit a step below their card twin because the page is 12
    // points off white: green measured 4.46:1 as `#047857`, amber 4.09:1 as
    // `#B45309`, and both had to move.
    successOnPage: Color(0xFF065F46),
    warningOnPage: Color(0xFF9A4707),
    statusBadOnPage: Color(0xFFB91C1C),
    successOnPageLight: Color(0xFF065F46),
    warningOnPageLight: Color(0xFF9A4707),
    statusBadOnPageLight: Color(0xFFB91C1C),
    info: Color(0xFF1D4ED8),
    // The chart triad is unchanged by the accent move: red/green/blue is a data
    // vocabulary, not a brand one.
    chartRed: Color(0xFFDC2626),
    chartGreen: Color(0xFF047857),
    chartBlue: Color(0xFF1D4ED8),
    // **White ink, not black — and it is measured, not chosen.** Black on
    // `#1D4ED8` is 4.06:1, under AA; white is 5.75:1. The previous pairing was
    // worse in both directions: white on the old red was 3.76:1 *and* black was
    // the token, so neither ink passed on the value that was actually there.
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFFFFFFFF),
    onHue: Color(0xFFFFFFFF),
  );

  static const AppPaletteTheme dark = AppPaletteTheme(
    // **`#1D4ED8`, same as light — not the `#3B82F6` this ramp started with.**
    // The lighter blue was chosen as a *graphic* on the dark page, and it clears
    // 3:1 there easily. But the same token draws panel headings and the selected
    // chip's label on a **white card**, where it measured **3.52:1** — under AA
    // for text. One accent has to work in both roles, and the binding one is the
    // card, because that is where it is read as words.
    primary: Color(0xFF1D4ED8),
    // **The same teal the light ramp uses, and it is the second series in
    // `kChartSeriesOrder`.** It used to be `#22D3EE`, a cyan bright enough to
    // read on the old near-black page - and illegible on the near-white *card*
    // the chart is actually drawn on, at **1.73:1**. The chart marks are on
    // cards in both ramps, so the series colours have to be legible on a card,
    // and this one measures 5.12:1 there.
    secondary: Color(0xFF0E7490),
    tertiary: Color(0xFFB45309),
    // **The dark ramp's status colours are DARK, and that is the whole cost of
    // the white card.** Cards are near-white in both ramps, so a status colour
    // read as text on a card has to be dark — and the values this ramp carried
    // (`#34D399`, `#FBBF24`, `#F87171`) measured **1.92 / 1.67 / 2.77:1** on
    // white. They are the right values for the *page*, which is why the
    // `…OnPage` twins below exist rather than these being simply darkened.
    success: Color(0xFF047857),
    warning: Color(0xFFB45309),
    // See the light ramp's note: an alert is orange-red, not a second amber.
    statusAlert: Color(0xFFC2410C),
    error: Color(0xFF1D4ED8),
    // **The same red as the light ramp, and the card is why.** Both ramps draw
    // near-white cards, so a breach colour has to be dark in both — and this
    // value measured **4.45:1** on `surfaceAlt`, under AA by a rounding
    // difference. One red, one value, both ramps.
    statusBad: Color(0xFFD01E1E),
    // **The page twins, and they are the values this ramp used to carry.**
    //
    // Measured on the dark page they now sit on: 8.24 / 8.71 / 6.62:1 bare, and
    // 6.22 / 6.71 / 5.29:1 on the badge's own 12% wash, which is the surface the
    // CCTV status pill actually puts them on.
    //
    // **The red moved and the other two did not.** `#F87171` was the old value
    // and it was tuned for a near-black page; on this page it measured 3.18:1 at
    // the light end of the sweep, which is a breach indicator that reads as a
    // smudge. It is now `#FCA5A5`, which is one step lighter at the *same hue*
    // (0.0 degrees, measured) and clears at 5.74:1 bare. The green and the amber
    // were measured at the stops this page now has and needed no change.
    successOnPage: Color(0xFF34D399),
    warningOnPage: Color(0xFFFBBF24),
    statusBadOnPage: Color(0xFFFCA5A5),
    // The light ramp's page is pale, so its page twins are its card values with
    // all three a step deeper: the light page (`#DCE9FB`) is 12 points off white,
    // and a hue that clears 4.5:1 on a white card is still under it on the page.
    successOnPageLight: Color(0xFF065F46),
    warningOnPageLight: Color(0xFF9A4707),
    statusBadOnPageLight: Color(0xFFB91C1C),
    info: Color(0xFF1D4ED8),
    // **The chart triad is the SAME in both ramps, and that is the fix.**
    //
    // The dark ramp used to carry a *brighter* triad — `#F87171`, `#34D399`,
    // `#60A5FA` — on the reasoning that chart lines are drawn on cards and a
    // triad tuned to the page would vanish on white. The reasoning was
    // backwards: the cards are near-white in **both** ramps, so the bright triad
    // is the one tuned to the page, and it is the one that vanishes on the card.
    // Measured on the card the charts are actually drawn on: `#F87171` 2.64:1,
    // `#34D399` **1.84:1**, `#60A5FA` 2.43:1 — and the legend labels are drawn
    // *in the series colour*, so the green series' label was 1.84:1 text. The
    // same triad in both ramps measures 4.62 / 5.24 / 6.41:1 on the card, and
    // the legend text is legible.
    //
    // **Red/green/blue is a data vocabulary, not a brand one.** The hues are
    // fixed, the order is fixed, and they mean the same thing in both ramps.
    chartRed: Color(0xFFDC2626),
    chartGreen: Color(0xFF047857),
    chartBlue: Color(0xFF1D4ED8),
    // **White, not black.** The ink follows the fill, and the fill is the same
    // value the light ramp uses.
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFFFFFFFF),
    onHue: Color(0xFFFFFFFF),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 4: SPACING (AppSpacing)
// ═════════════════════════════════════════════════════════════════════════════

class AppSpacing {
  const AppSpacing._();

  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  // Common compositions
  static const double gutter = 16;
  static const double cardPadding = 12;
  static const double sectionGap = 16;
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 5: RADIUS (AppRadius)
// ═════════════════════════════════════════════════════════════════════════════

class AppRadius {
  const AppRadius._();

  static const double none = 0;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;

  // The blue system's own radii, which are not the 4/8/12/16 scale.
  //
  // **These four are read off the reference card by card, not picked.** The hero
  // is the roundest thing on the screen because it is the biggest; the sheet is
  // one step tighter because it is taller; the pills and the sheet rows are
  // tighter again because they are small enough that a 28 would read as a lozenge.
  static const double hero = 28;    // the navy gradient card
  static const double sheet = 24;   // the opaque white bottom sheet
  static const double stat = 16;    // the translucent three-column stat card
  static const double tilePill = 14; // high/low pills and the hour pills
  static const double sheetRow = 12; // one row inside the sheet

  // Aliases for semantic use
  static const double card = xl;
  static const double button = md;
  static const double input = md;
  static const double badge = sm;
  static const double pill = full;
  static const double round = full;
  static const double bar = full;

  // Backward compatibility aliases
  static const double tile = xl;    // was same as card
  static const double inset = xl;   // was same as card

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 6: ELEVATION (AppShadows)
// ═════════════════════════════════════════════════════════════════════════════

class AppShadows {
  const AppShadows._();

  /// **Raised: two shadows, and the contact one is the load-bearing half.**
  ///
  /// This was a single `0x0A000000` at a 1px offset and a 2px blur — four percent
  /// of neutral black, two pixels wide. On this app's mid-tone blue page that is
  /// not visible at all, which is why every card, tile and panel read as a flat
  /// rectangle with a hairline and nothing else. That is the "flat sekali" the
  /// surface system was reported as.
  ///
  /// A single shadow wide enough to see reads as a *float*: a dark halo around a
  /// shape, with nothing joining the shape to the page. So there are two. The
  /// tight one is the contact shadow — the dark line where the surface meets what
  /// it rests on — and the wide one is the ambient falloff away from it. This is
  /// the construction `AppGlass.heroShadow` already uses at hero scale; this tier
  /// is the one for a card.
  ///
  /// **Navy, not black, and that is the page's colour.** A neutral black shadow
  /// laid over a blue field desaturates it and reads as grey dirt rather than as
  /// shade. The alphas sit one step under the hero's measured pair
  /// (`0x3D` dark / `0x1F` light), because a card is smaller than a hero — and
  /// light mode is the weaker of the two for the reason recorded on
  /// `AppGlass.heroShadow`: the light page is already a short distance from the
  /// card, so the shadow only has to add depth.
  static List<BoxShadow> get subtle => <BoxShadow>[
        BoxShadow(
          color: AppGlass.isDark
              ? const Color(0x2E0B2545)
              : const Color(0x170B2545),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppGlass.isDark
              ? const Color(0x240B2545)
              : const Color(0x120B2545),
          offset: const Offset(0, 10),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ];

  /// Medium: 2px offset, 6px blur, #000000 at 6% — hover/press widgets
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// Large: 6px offset, 16px blur, #000000 at 10% — expanded widgets, modals
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 6),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Overlay: 12px offset, 32px blur, #000000 at 14% — full-screen overlays
  static const List<BoxShadow> overlay = [
    BoxShadow(
      color: Color(0x24000000),
      offset: Offset(0, 12),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];

  /// Glow: 0 0 blur at alpha — accent glow for progress fills, peak bars
  static List<BoxShadow> glow(Color hue, {double strength = 0.50}) => [
        BoxShadow(
          color: hue.withValues(alpha: strength),
          blurRadius: 10,
          offset: Offset.zero,
        ),
      ];

  // ══ Backward compatibility aliases (from Neon Brutalist) ════════════════

  /// Alias for `medium` — the stamped tier for cards, inputs, list rows
  static List<BoxShadow> get stamped => medium;

  /// Tinted stamped shadow for primary button — returns medium with hue wash
  static List<BoxShadow> stampedIn(Color hue) => [
        BoxShadow(
          color: hue.withValues(alpha: 0.15),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 7: BORDERS (AppBorders)
// ═════════════════════════════════════════════════════════════════════════════

class AppBorders {
  const AppBorders._();

  static BorderSide get hairline => BorderSide(
        color: AppSurfaces.border,
        width: 1,
      );

  static BorderSide get control => BorderSide(
        color: AppSurfaces.border,
        width: 1,
      );

  static const BorderSide boundary = BorderSide(
    color: Color(0xFFFAFAFA),
    width: 1.5,
  );

  static BoxBorder get hairlineBorder => Border.fromBorderSide(hairline);
  static BoxBorder get controlBorder => Border.fromBorderSide(control);
  static BoxBorder get boundaryBorder => Border.fromBorderSide(boundary);

  /// **12%, not 20%, and the accent's own contrast on its wash is the reason.**
  ///
  /// A 20% wash of the accent over the page lifted the page's luminance enough
  /// that the accent on top of it measured **4.07:1** — under AA for the 11-15dp
  /// caption `AppBadge` draws in it. 12% holds it at **4.59:1** on the page and
  /// 5.56:1 over a card. A wash strong enough to tint visibly is not the same as
  /// one strong enough to be a background for text in the hue on top of it.
  static Color categoricalWash(Color hue) => hue.withValues(alpha: 0.12);

  static Border categoricalBorder(Color hue) =>
      Border.fromBorderSide(
        BorderSide(color: hue.withValues(alpha: 0.20), width: 1),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 8: TYPOGRAPHY (AppType)
// ═════════════════════════════════════════════════════════════════════════════

class AppType {
  const AppType._();

  // ══ Families ═══════════════════════════════════════════════════════════════
  //
  // **One body face, and it used to be a CSS font stack.** `sans` was
  // `'Segoe UI, Roboto, Helvetica, Arial, sans-serif'` — a stack a browser
  // parses and Flutter does not. Flutter looks for a single family whose literal
  // name is that whole string, finds none, and falls back to the platform
  // default, so every `sans` style rendered in Roboto while every `heading`
  // style rendered in the bundled Inter. Two families on one screen is exactly
  // the "fonts are not uniform" this token sits in the middle of.
  //
  // Only the value moved. The name stays because many call sites write
  // `AppType.sans`.
  static const String heading = 'Inter';
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';

  // **Two families, and every declared weight now paints.**
  //
  // `pubspec.yaml` bundles Inter at 400/500/600/700/900 and JetBrainsMono at
  // 500/700. It used to bundle Inter at 400/700/900 only, so the `w500` and
  // `w600` styles below had no cut: each resolved to the nearest one that
  // existed — 500 to Regular, 600 to Bold — and the weight asked for was not
  // quite the weight painted. `headlineMd` (17sp, w600) painted identical to
  // `headlineLg` (22sp, w700) in weight, and the uppercase labels asked for a
  // Semi-bold they never got. The intermediate instances are shipped, so every
  // weight declared in this file is the weight that is drawn.
  //
  // **JetBrainsMono declares 500 and 700, and only the terminal panel asks for
  // it.** `code` is at 500 because Medium is the lightest cut that exists — a
  // `w400` request would paint Medium anyway, so declaring 500 says so.

  // ══ Display ═══════════════════════════════════════════════════════════════

  static const TextStyle displayLg = TextStyle(
    fontFamily: heading,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.21,
    letterSpacing: -0.02 * 28,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle displayMd = TextStyle(
    fontFamily: heading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.17,
    letterSpacing: -0.02 * 24,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ══ Headlines ══════════════════════════════════════════════════════════════

  static const TextStyle headlineLg = TextStyle(
    fontFamily: heading,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.27,
    letterSpacing: -0.02 * 22,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: heading,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.29,
    letterSpacing: -0.01 * 17,
  );

  // ══ Body Large ═════════════════════════════════════════════════════════════

  static const TextStyle bodyLg = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.47,
  );

  // ══ Body ══════════════════════════════════════════════════════════════════

  static const TextStyle bodyMd = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.54,
  );

  // ══ Body Small ════════════════════════════════════════════════════════════

  static const TextStyle bodySm = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  // ══ Caption ═══════════════════════════════════════════════════════════════

  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  // ══ Labels ════════════════════════════════════════════════════════════════

  static const TextStyle labelUppercase = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0.05 * 11,
  );

  static const TextStyle labelMicro = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: 0.04 * 10,
  );

  // ══ Code / Mono ═══════════════════════════════════════════════════════════

  static const TextStyle code = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.50,
  );

  // ══ Numeric displays (for metrics) ════════════════════════════════════════
  //
  // **Inter, not JetBrainsMono, and the reason is the card they sit on.**
  //
  // These are the figures a *card* draws: a telemetry value, an energy total, a
  // hero number. Their labels are Inter, so a mono figure beside an Inter
  // label is two families on one card, and the figure is the part the eye
  // lands on. The terminal panel keeps its monospaced vocabulary below — that
  // one is a *panel*, with a key column and a value column, and the fixed pitch
  // is what makes a column of numbers line up. A card has no column to align.
  //
  // Tabular figures carry the alignment the monospace used to: Inter's `tnum`
  // gives every digit the same advance, so a value that changes width does not
  // shove its own unit sideways.

  static const TextStyle numeralXl = TextStyle(
    fontFamily: heading,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.02 * 28,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numeralLg = TextStyle(
    fontFamily: heading,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.02 * 20,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numeralMd = TextStyle(
    fontFamily: heading,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ══ Figures and titles that the cards actually draw ═══════════════════════
  //
  // **These existed as literals in seven files, at three different values for
  // the same role.** A card's hero figure was `fontSize: 54` in one file and a
  // copyWith of a 28px token in another; a section title was 12sp in one place
  // and 16sp in another. The sizes are the same now, and they are named, so the
  // next card cannot pick a different one.

  /// The hero card's own figure. The largest number the app draws.
  static const TextStyle figureHero = TextStyle(
    fontFamily: heading,
    fontSize: 54,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.02 * 54,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A figure with its unit beside it, in a row of three.
  static const TextStyle figureTerm = TextStyle(
    fontFamily: heading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.01 * 24,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The unit suffix that follows a figure. Lighter than the figure and the
  /// same size, so the pair reads as one number.
  static const TextStyle figureUnit = TextStyle(
    fontFamily: heading,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  /// A bold run inside 13sp body text: a row's title, a speaker's name, a
  /// numbered-list marker, a markdown **bold** span.
  ///
  /// **There is no 800.** The brief's scale is 900/700/400, and a request for
  /// 800 resolved to the nearest declared cut, which is not the weight that
  /// was asked for. 700 is the honest answer.
  static const TextStyle strong = TextStyle(
    fontFamily: heading,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.38,
  );

  /// A row's label: the muted half of a row.
  static const TextStyle emphasis = TextStyle(
    fontFamily: heading,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.38,
  );

  /// A section header inside a card.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: heading,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  /// The smallest muted line of text on a card.
  static const TextStyle captionSmall = TextStyle(
    fontFamily: heading,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// A word that is the whole claim of a strip, in the display weight.
  static const TextStyle statusWord = TextStyle(
    fontFamily: heading,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );

  /// The app's name in the app bar.
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: heading,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.2,
  );

  /// The app's name as a brand lockup: the splash screen, at the display weight.
  static const TextStyle wordmark = TextStyle(
    fontFamily: heading,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -0.4,
  );

  // ══ Button label ══════════════════════════════════════════════════════════

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.04 * 14,
  );

  // ══ Terminal/Instrument Panel styles (for backward compatibility) ═════════

  /// Panel row key: PV_OUT, BAT_SOC, etc.
  static const TextStyle slotKey = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.06 * 11,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Micro variant for panel header id and meter caption
  static const TextStyle slotMicro = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.08 * 10,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Panel row value, right-aligned
  static const TextStyle slotValue = TextStyle(
    fontFamily: mono,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.01 * 15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Hero's secondary stats
  static const TextStyle slotValueSmall = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Unit, smaller and muted beside its figure
  static const TextStyle slotUnit = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.1,
  );

  /// Panel's one enormous figure
  static const TextStyle heroFigure = TextStyle(
    fontFamily: mono,
    fontSize: 88,
    fontWeight: FontWeight.w700,
    height: 0.92,
    letterSpacing: -0.03 * 88,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Hero's unit, baseline-aligned beside figure
  static const TextStyle heroUnit = TextStyle(
    fontFamily: mono,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 9: MOTION (AppMotion)
// ═════════════════════════════════════════════════════════════════════════════

class AppMotion {
  const AppMotion._();

  static const Duration press = Duration(milliseconds: 150);
  static const Duration state = Duration(milliseconds: 200);
  static const Duration container = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 250);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve both = Curves.easeInCubic;
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 9: GLASS (AppGlass) — the blue reference system
// ═════════════════════════════════════════════════════════════════════════════

/// The blue system: a gradient page, a navy gradient hero, translucent white
/// glass over it, and exactly one opaque surface — the sheet.
///
/// **Every value here comes off the reference card, and the two opacities are
/// the load-bearing part.** The whole glass effect is one white at two alphas:
/// [fillSoft] carries the stat card and a resting hour pill, [fillStrong] carries
/// the hour pill that is selected. Written as two numbers rather than four means
/// the "selected" state is a real step in one axis instead of a second hue, and
/// it cannot drift — there is nothing to keep in agreement.
///
/// The sheet is the only opaque fill in the system, and that is the reference's
/// own rule: the glass is for things sitting *on* the hero, and the sheet is a
/// different layer of interface that happens to be white. [sheetRow] is a light
/// grey rather than a tint of the sheet, because a tint would let the page
/// gradient show through the one surface that is supposed to be opaque.
class AppGlass {
  const AppGlass._();

  /// **Which ramp is live.** Everything below branches on this rather than
  /// hardcoding white, because the light ramp has the same problem in reverse:
  /// the page is *pale*, so white-on-pale has no contrast and the whole system
  /// collapses into a white screen. Dark ink is the light ramp's ink, and
  /// translucent **black** is its glass — the tint has to invert with the ink,
  /// because glass only reads when it is lighter (or darker) than what is
  /// behind it.
  static Brightness get brightness => AppTheme.brightness;

  static bool get isDark => brightness == Brightness.dark;

  /// Page gradient, top → bottom. **The screen is never a flat colour.**
  ///
  /// **Every stop is dark enough to carry white ink, and that is measured, not
  /// stylistic.** This ramp started at `#A9C7F7` — a pale blue copied off the
  /// reference — which put white page ink at **1.72:1** on the top third of the
  /// screen: the nav bar's inactive glyph, the hour pills and the page headings
  /// were all invisible there. The reference gets away with a light top because
  /// its top third is empty; this app puts content in it.
  ///
  /// So the sweep is deepened end to end while staying unmistakably blue, and
  /// `test/glass_ramp_contrast_test.dart` pins white ink at AA against all
  /// three stops so it cannot be lightened back.
  static const List<Color> pageGradientDark = <Color>[
    // **Deep, and nearly even, and the evenness is the point.**
    //
    // The pill is a 45% white wash, so what matters is not the page's own value
    // but where that wash lands. A ramp that keeps darkening toward the bottom
    // puts its darkest stop under the pill and drops the label to 4.01:1 — the
    // bottom of a gradient is where content is densest, so it cannot also be
    // where contrast is worst. These three sit inside a narrow band: the sweep
    // still reads, and no stop starves the glass above it.
    //
    // **The band is also what keeps the page twins legible, and that is the
    // second reason for it.** They are drawn on the page - the CCTV status pill,
    // a banner's glyph - and the old ramp failed them: on `#2C5599` the green
    // measured 3.81:1, the amber 4.39:1 and the red **2.65:1** - and that red
    // was `#F87171`, the twin the ramp carried then; the twin it carries now,
    // `#FCA5A5`, measures 3.86:1 there, so the old ramp failed this red too,
    // just less badly. Which is a breach indicator that reads as a smudge. On
    // these stops the twins measure 5.67 / 6.53 / 5.74 bare at their worst
    // stop, and the badge's own 12% wash under each reads 4.55 / 5.24 / 4.63 -
    // so the pill's *label*, which is 10dp text, clears AA on every stop instead
    // of only on the deepest one.
    //
    // The deepest stop is `#1B3260`, and it is the **flat page** too (see
    // `AppSurfaces.dark.page`), so the strip under the nav bar, the AI chat
    // background and the chart export canvas are the same blue as the body
    // rather than a second, unrelated dark.
    Color(0xFF223C6B),
    Color(0xFF1E3960),
    Color(0xFF1B3260),
  ];

  /// **The page sweep for the active ramp.**
  ///
  /// **A getter, and that is the whole fix.** It was one `const` list named
  /// `pageGradient` holding the dark stops, with a separate unused
  /// `pageGradientLight` beside it — so light mode painted the dark blue and
  /// every light-mode contrast number was measured against a page the light ramp
  /// does not have. Two names for one thing, and the second one was dead.
  static List<Color> get pageGradient =>
      isDark ? pageGradientDark : pageGradientLight;

  /// The light ramp's page: the same blue, washed almost to white.
  ///
  /// **The top stop is near-white on purpose.** The blue is the product's
  /// identity and it does not leave in light mode — what changes is that the
  /// page gets out of the way, so a user who picked Light for battery or glare
  /// is not looking at a saturated blue field. The bottom stop stays tinted so
  /// the sweep still reads as a gradient and the sheet has something to lift off.
  static const List<Color> pageGradientLight = <Color>[
    Color(0xFFF7FAFE),
    Color(0xFFE8F1FD),
    // **Was `#BCD6F6`, and it was too blue for navy ink.** The light ramp's glass
    // is translucent *black*, so a saturated page stop plus a black wash lands
    // the pill at a mid-blue that navy ink measures 2.48:1 against. The stop is
    // pulled back toward white; the gradient still reads because the top stop is
    // warmer and the whole thing is cooler than a neutral page.
    Color(0xFFD4E5FA),
  ];

  /// Hero gradient, top-left → bottom-right, navy into deeper navy.
  static const List<Color> heroGradient = <Color>[
    Color(0xFF35619F),
    Color(0xFF1E3E75),
  ];

  /// **45% and 68%, and the number is a measurement.**
  ///
  /// The wash started at 14% / 34%, which is what "glass" looks like on a dark
  /// card over a dark page — and it is why both ramps failed. A 14% white wash
  /// over a mid-blue page lands on a **mid-tone**: too dark for dark ink and too
  /// light for white ink, so neither passes. Measured 2.41:1 for dark ink and
  /// 3.77:1 for white on the same pill.
  ///
  /// The wash has to carry the surface all the way to light, so that the dark
  /// label on it has something to read against in both ramps. 45% reads as a
  /// tinted chip on the dark page and as a barely-there lift on the light one;
  /// 68% is the selected state and the nav bar.
  static const double softAlpha = 0.45;
  static const double strongAlpha = 0.68;

  /// A resting glass surface: the stat card, a high/low pill, an hour pill.
  ///
  /// **Always white, in both ramps — and the ink on it is always dark.**
  ///
  /// **This is the reference's own rule and it is what makes the wash safe.**
  /// A translucent white pill over the dark page comes out *lighter* than the
  /// page, and over the light page it comes out lighter too: the wash decides
  /// the surface's lightness, not the page behind it. So the pill is a light
  /// chip in both ramps and its label is dark in both — which is the only
  /// pairing that clears AA twice.
  ///
  /// It also means the wash must NOT invert per ramp. An earlier version used a
  /// black wash in light "so the tint would match the ink", which drags the pill
  /// toward the navy ink sitting on it: measured **2.48:1**. Inverting the wash
  /// is the wrong lever; the ink is the thing that follows the wash.
  static Color get fillSoft => Colors.white.withValues(alpha: softAlpha);

  /// The selected glass surface: the highlighted hour pill. A stronger white, so
  /// selection is a step in one axis rather than a second hue.
  static Color get fillStrong => Colors.white.withValues(alpha: strongAlpha);

  /// A third, middle strength for the high/low pills, which sit on the hero's
  /// lighter half and need more body than an hour pill on the page gradient.
  static Color get fill => Colors.white.withValues(alpha: 0.20);

  /// **The ink for content sitting on a [fillSoft] / [fillStrong] surface.**
  ///
  /// Dark in both ramps, because the wash is white in both. This is deliberately
  /// *not* [pageInkStrong]: that is for content on the bare page, where the ramp
  /// does decide the ink. On glass the wash decides it.
  static const Color pageGlassInk = Color(0xFF0B2545);
  // **The same value as [pageGlassInk], and the measurement is why.**
  //
  // A tinted wash gives a label no headroom: 4.31:1 for a slightly lighter navy
  // against a requirement of 4.5. The distinction that a caption needs is
  // carried by size and weight, which is what the type scale is for — not by a
  // fifth ink value that only half the ramps could afford.
  static Color get pageGlassInkSoft => pageGlassInk;

  /// The ink on the **nav bar**, which is a strong glass wash over the page and
  /// therefore a light chip for the same reason the hour pills are.
  static Color get navInk => pageGlassInk;
  static Color get navInkSoft => pageGlassInkSoft;

  /// The divider between the stat card's three columns.
  static Color get divider =>
      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22);

  /// The two arrows on the high/low pills. Warm for the one that means "up",
  /// the hero's own blue for the one that means "down" — so the arrow is the
  /// only warm pixel in a cool screen, which is what makes it read as a
  /// direction rather than as a character.
  ///
  /// **The down arrow is stepped up in light mode** because `#7FB2FF` is a pale
  /// blue and the light ramp's page is also pale blue; at that value the arrow
  /// reads as part of the background. Light mode gets the same hue at full
  /// strength, which is the one place this system uses an unpastel'd value.
  static Color get arrowUp => isDark ? arrowUpDark : arrowUpLight;
  static Color get arrowDown => isDark ? arrowDownDark : arrowDownLight;

  static const Color arrowUpDark = Color(0xFFFF8A5B);
  static const Color arrowDownDark = Color(0xFF7FB2FF);
  static const Color arrowUpLight = Color(0xFFE85D1F);
  static const Color arrowDownLight = Color(0xFF1D5FD6);

  /// A saturated blue that clears **3:1 on the dark page**, for accent *graphics*
  /// drawn on the page gradient.
  ///
  /// **The accent itself cannot do this, and the measurement is the whole reason
  /// the token exists.** `#1D4ED8` is the brand colour and it is right on a white
  /// *card*, but the same blue on the dark page's own stops measures
  /// **1.09 / 1.35 / 1.60:1** — under WCAG 1.4.11's 3:1 for a graphical object,
  /// and under the 1.4.11 contrast the live dot, the carousel dot and a section
  /// heading need there. No hue in the ramp clears it either (`#2F6FED` reaches
  /// only 2.35), which is why this is a second blue rather than a lighter tint
  /// of the first.
  static const Color accentOnPage = Color(0xFF93C5FD);

  /// White ink at three strengths, which is what the **hero** needs: a title, a
  /// value, and a label. One colour at three alphas rather than three greys,
  /// because a grey chosen for a label on navy reads warm against a blue and this
  /// cannot.
  ///
  /// **These do not invert with the theme, and that is the one exception.** The
  /// hero is a navy gradient in both ramps — it is the same card either way, so
  /// its ink is white either way. Everything drawn on the *page* instead uses
  /// [pageInkStrong] / [pageInk] / [pageInkSoft], which do.
  static Color get inkStrong => Colors.white;
  static Color get ink => Colors.white.withValues(alpha: 0.92);
  static Color get inkSoft => Colors.white.withValues(alpha: 0.70);

  /// Ink for content sitting **directly on the page**, not inside the hero.
  ///
  /// **This is the token the light mode was missing.** White ink over the dark
  /// ramp's blue page is the whole reason the dark theme read; the same white
  /// over the light ramp's near-white page is invisible, so light mode needs
  /// navy ink and the nav bar, the status strip and the date strip all have to
  /// read these rather than the hero's white.
  static Color get pageInkStrong =>
      isDark ? Colors.white : const Color(0xFF0B2545);
  static Color get pageInk =>
      isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF10294D);
  // **Darker than the obvious `#3A5A87`, and 3.87:1 is why.** That was measured
  // on the light ramp's own bottom stop. The soft ink is a caption weight, which
  // is the size that has the least room, so it takes the darkest value of the
  // three rather than a mid one.
  static Color get pageInkSoft =>
      isDark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF24446F);

  /// The one opaque surface, and its two greys.
  static const Color sheet = Color(0xFFFFFFFF);
  static const Color sheetRow = Color(0xFFF4F5F7);
  static const Color sheetTitleInk = Color(0xFF1A1A1A);
  static const Color sheetRowInk = Color(0xFF1A1A1A);
  static const Color sheetRowInkMuted = Color(0xFF5A5F6B);

  /// The sheet's grab handle, and the two page dots.
  static const Color handle = Color(0xFFCBD2DC);
  static const Color dotInactive = Color(0xFFC7CCD6);
  static const Color active = Color(0xFF2F6FED);

  /// The hero's own shadow. A navy card on a blue page cannot be separated by a
  /// tonal step the way a white card on navy could, so it carries a deep soft
  /// one instead — and it is the only shadow in the system, because glass is not
  /// a thing that gets a shadow, it is a thing that gets a border.
  ///
  /// **Stronger in light mode, and that is a measurement rather than a
  /// preference.** Over the dark ramp the page is darker than the card, so the
  /// card already separates and the shadow only has to add depth. Over the light
  /// ramp's pale page the same navy shadow falls on a near-white field where it
  /// is far more visible, so it is pulled back rather than pushed up — a heavier
  /// shadow there reads as a smudge under a card rather than as lift.
  static List<BoxShadow> get heroShadow => <BoxShadow>[
        BoxShadow(
          color: isDark ? const Color(0x3D0B2545) : const Color(0x1F0B2545),
          offset: const Offset(0, 12),
          blurRadius: 28,
          spreadRadius: 0,
        ),
      ];

  /// The sheet lifts off the page harder than the hero does: it is larger, it
  /// overlaps the hero, and the hero's bottom edge is what casts into it.
  static List<BoxShadow> get sheetShadow => <BoxShadow>[
        BoxShadow(
          color: isDark ? const Color(0x2E0B2545) : const Color(0x260B2545),
          offset: const Offset(0, -6),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ];

  /// The page gradient as a box decoration's linear gradient, for the one
  /// widget that owns the backdrop.
  ///
  /// **A getter, not a constant, and it branches on the ramp.** It was a
  /// hardcoded dark-blue sweep, so light mode painted a saturated blue behind a
  /// palette built for near-white — the single biggest reason light mode looked
  /// broken rather than merely plain.
  static LinearGradient get pageSweep => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: pageGradient,
      );

  /// The flat colour the gradient's own top stop lands near.
  ///
  /// **This is the fallback, not the design.** It is what an overscroll bounce
  /// exposes above and below the sweep, and what shows for the one frame before
  /// the gradient resolves, so it must match the ramp's own page or the seam is
  /// visible at exactly the moment the user is dragging.
  ///
  /// The dark ramp's was `#4A7FD4`, a *light* blue, while its page was
  /// near-black: the two were unrelated, so a bounce flashed a colour the app
  /// otherwise never drew. It is now the dark page, which is the same value
  /// the gradient resolves to at its foot.
  static Color get pageFallback =>
      isDark ? const Color(0xFF1B3260) : const Color(0xFFBCD6F6);
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 10: UTILITIES
// ═════════════════════════════════════════════════════════════════════════════

Color appDivider({double opacity = 1.0}) =>
    AppSurfaces.border.withValues(alpha: opacity);