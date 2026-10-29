/// Every surface, radius, edge, type, shadow, spacing and motion value in the
/// app.
///
/// **Rethemed to the WattVision system on 28 October 2026, and the app is
/// dark-only now.**
///
/// WattVision (designmd.ai, MIT) is a flat dark dashboard system:
/// - **Background**: #121212, **Cards**: #1E1E1E, borders/grid #2C2C2E,
///   hover tile #252525
/// - **Accent (data)**: #00E5FF cyan; **alert/red**: #FF453A;
///   **live/normal green**: #32D74B; warning amber stays for the stale tier
/// - **Text**: #FFFFFF / #98989D
/// - **Typography**: Inter (titles/body), JetBrains Mono (KPI figures), tabular
/// - **Alert box**: fill #3A1C1C, red ink, 4px red left border (banners.dart)
///
/// Both brightness ramps carry the same values: the ramp machinery stays, but
/// every mode resolves to WattVision dark.
library;

import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 1: COLORS (AppSurfaces)
// ═════════════════════════════════════════════════════════════════════════════

/// The three-layer surface stack, plus the deepest fill.
///
/// **Swappable, and every value here is read through an instance.**
class AppSurfaces {
  const AppSurfaces._();

  // Dark, so the first frame before [apply] cannot take the light leg.
  static AppSurfacesPalette _palette = AppSurfacesPalette.dark;

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

  /// The card surface current ink binds hardest on.
  ///
  /// Light ink binds against the lighter surface; dark ink binds against the
  /// darker one. Compute it so a future ramp cannot measure captions against the
  /// forgiving card surface by name.
  static Color get bindingCaptionSurface {
    final textIsLight = onSurface.computeLuminance() > 0.5;
    final surfaceIsHarder = textIsLight
        ? surface.computeLuminance() >= surfaceAlt.computeLuminance()
        : surface.computeLuminance() <= surfaceAlt.computeLuminance();
    return surfaceIsHarder ? surface : surfaceAlt;
  }
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
    // WattVision: flat #121212 page (designmd spec).
    page: Color(0xFF121212),
    // WattVision: cards #1E1E1E.
    surface: Color(0xFF1E1E1E),
    // WattVision: hover tile #252525.
    surfaceAlt: Color(0xFF252525),
    surfaceMuted: Color(0xFF2C2C2E),
    onSurface: Color(0xFFFFFFFF),
    // WattVision: muted text #98989D.
    onSurfaceVariant: Color(0xFF98989D),
    // Same value as [surfaceMuted] — documented identity kept.
    border: Color(0xFF2C2C2E),
    // Input tracks surface identity.
    input: Color(0xFF1E1E1E),
    // The page — un-lit meter segment is a hole in the surface.
    track: Color(0xFF121212),
    // WattVision: tooltip #2C2C2E.
    tooltip: Color(0xFF2C2C2E),
  );

  static const AppSurfacesPalette light = AppSurfacesPalette(
    brightness: Brightness.light,
    // WattVision: flat #121212 page (designmd spec).
    page: Color(0xFF121212),
    // WattVision: cards #1E1E1E.
    surface: Color(0xFF1E1E1E),
    // WattVision: hover tile #252525.
    surfaceAlt: Color(0xFF252525),
    surfaceMuted: Color(0xFF2C2C2E),
    onSurface: Color(0xFFFFFFFF),
    // WattVision: muted text #98989D.
    onSurfaceVariant: Color(0xFF98989D),
    // Same value as [surfaceMuted] — documented identity kept.
    border: Color(0xFF2C2C2E),
    // Input tracks surface identity.
    input: Color(0xFF1E1E1E),
    // The page — un-lit meter segment is a hole in the surface.
    track: Color(0xFF121212),
    // WattVision: tooltip #2C2C2E.
    tooltip: Color(0xFF2C2C2E),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 2: THEME (AppTheme)
// ═════════════════════════════════════════════════════════════════════════════

class AppTheme {
  const AppTheme._();

  /// The brightness the app is running in.
  ///
  /// **Starts dark, not the platform's value.** It used to seed from
  /// `PlatformDispatcher.instance.platformBrightness`, which is read *before*
  /// `runApp` and before `applyMode` can clamp it - so on a device set to light
  /// the first frame took the light leg of every ramp-branching token:
  /// `pageInkStrong` came out `#0B2545` on a `#121212` page, `divider` black on
  /// black, `arrowUp` orange. WattVision is dark-only, so the initial value is
  /// the app's own value; nothing can disagree with it because nothing can
  /// change it but [apply].
  static Brightness _brightness = Brightness.dark;

  static Brightness get brightness => _brightness;

  /// Resolves a [ThemeMode] and a platform brightness to the one appearance.
  ///
  /// **Both arguments are ignored and that is the contract.** The signature is
  /// kept because `MaterialApp` owns a `themeMode` and the root widget has to
  /// answer it; the answer is always dark.
  static void applyMode(ThemeMode mode, Brightness platform) => apply();

  /// Re-resolves every ramp. **One appearance, so there is nothing to choose.**
  ///
  /// The parameter is kept rather than deleted because the test suite drives
  /// both ramps through this call to prove they are identical; the body clamps
  /// it, which is what makes "dark-only" true rather than merely intended.
  static void apply([Brightness? brightness]) {
    _brightness = Brightness.dark;
    AppSurfaces.apply(Brightness.dark);
    AppPalette.apply(Brightness.dark);
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

  // Dark, for the same reason [AppSurfaces] starts dark.
  static AppPaletteTheme _active = AppPaletteTheme.dark;

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

  /// The alert banner's fill. See [AppPaletteTheme.alertFill].
  static Color get alertFill => _active.alertFill;

  // The page twins. **Use these for anything drawn on the page gradient** — a
  // CCTV status pill, a banner with no card behind it, a live dot. The plain
  // `success` / `warning` / `statusBad` are for cards.
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
    required this.alertFill,
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

  /// The alert banner's fill, a deep desaturated red under [statusBad] ink.
  ///
  /// Its own token rather than a literal in `banners.dart`, because the fill and
  /// the 4px edge that sits on it are one recipe and the edge already reads
  /// [statusBad]. Both ramps carry the same value: it is a wash of the one red.
  final Color alertFill;
  final Color error;
  final Color statusBad;

  /// The page twins of [success], [warning] and [statusBad], per ramp.
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
    // WattVision: cyan data accent (designmd spec).
    primary: Color(0xFF00E5FF),
    // WattVision: live/normal lime green.
    secondary: Color(0xFF32D74B),
    // WattVision: warning amber.
    tertiary: Color(0xFFFBBF24),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFBBF24),
    // Orange, distinct from warning on purpose.
    statusAlert: Color(0xFFFF9F0A),
    // The alert banner's fill: a deep red that carries statusBad ink.
    alertFill: Color(0xFF3A1C1C),
    error: Color(0xFF00E5FF),
    // Spec alert red — the only red in the ramp.
    statusBad: Color(0xFFFF453A),
    successOnPage: Color(0xFF32D74B),
    warningOnPage: Color(0xFFFBBF24),
    statusBadOnPage: Color(0xFFFF453A),
    successOnPageLight: Color(0xFF32D74B),
    warningOnPageLight: Color(0xFFFBBF24),
    statusBadOnPageLight: Color(0xFFFF453A),
    info: Color(0xFF00E5FF),
    // Chart triad: alert red / chart green / 4th-series blue.
    chartRed: Color(0xFFFF453A),
    chartGreen: Color(0xFF30D158),
    chartBlue: Color(0xFF5E9EFF),
    // Measured: white on cyan #00E5FF ~1.4:1, dark ink ~10:1.
    onPrimary: Color(0xFF121212),
    onSecondary: Color(0xFF121212),
    onTertiary: Color(0xFF121212),
    onHue: Color(0xFF121212),
  );

  static const AppPaletteTheme dark = AppPaletteTheme(
    // WattVision: cyan data accent (designmd spec).
    primary: Color(0xFF00E5FF),
    // WattVision: live/normal lime green.
    secondary: Color(0xFF32D74B),
    // WattVision: warning amber.
    tertiary: Color(0xFFFBBF24),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFBBF24),
    // Orange, distinct from warning on purpose.
    statusAlert: Color(0xFFFF9F0A),
    // The alert banner's fill: a deep red that carries statusBad ink.
    alertFill: Color(0xFF3A1C1C),
    error: Color(0xFF00E5FF),
    // Spec alert red — the only red in the ramp.
    statusBad: Color(0xFFFF453A),
    successOnPage: Color(0xFF32D74B),
    warningOnPage: Color(0xFFFBBF24),
    statusBadOnPage: Color(0xFFFF453A),
    successOnPageLight: Color(0xFF32D74B),
    warningOnPageLight: Color(0xFFFBBF24),
    statusBadOnPageLight: Color(0xFFFF453A),
    info: Color(0xFF00E5FF),
    // Chart triad: alert red / chart green / 4th-series blue.
    chartRed: Color(0xFFFF453A),
    chartGreen: Color(0xFF30D158),
    chartBlue: Color(0xFF5E9EFF),
    // Measured: white on cyan #00E5FF ~1.4:1, dark ink ~10:1.
    onPrimary: Color(0xFF121212),
    onSecondary: Color(0xFF121212),
    onTertiary: Color(0xFF121212),
    onHue: Color(0xFF121212),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 4: SPACING (AppSpacing)
// ═════════════════════════════════════════════════════════════════════════════

/// The dashboard's horizontal page margin, in logical pixels.
///
/// **Public so a test can read it rather than restate it.** Every page is a
/// `ListView` whose padding is this value on each side, so a card on screen is
/// `screenWidth - 2 * kDashboardPageMargin` dp wide. `test/widget_text_helpers.dart`
/// needs that number to measure a card at the width it really has, and a test
/// that copied the literal would be a copy — the failure mode `FEATURE.md`
/// records twice already, where a list of surface hex values in
/// `color_helpers_test.dart` drifted from the fills it claimed to measure and
/// three colours sat under AA with the suite green.
///
/// 16, not 24: the brief's `spacing.gutter`. It is also the carousel's bleed on
/// each side, which is why it is written as the token rather than as a second
/// number — one value, one meaning.
///
/// **The old 24 was shadow clearance and it is gone with the shadow.** It had
/// been derived so the ambient half of a raised shadow pair would not be clipped
/// by the screen edge — 9dp offset plus 11dp at one sigma, 20dp of visible core
/// with 4dp to spare. WattVision's lift is `AppShadows.subtle`, one 24dp blur at
/// 10dp offset, and the card is separated by a hairline rather than by a halo, so
/// there is nothing left for the extra 8dp to protect. Dropping to the gutter
/// buys 16dp of card width back.
///
/// It lives here rather than on `dashboard_screen.dart` so a widget file can
/// read it without importing the screen back.
const double kDashboardPageMargin = AppSpacing.gutter;

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
  static const double cardPadding = 20;
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

  // Component radii that do not fit the 4/8/12/16 scale.
  //
  // **These four are read off the reference card by card, not picked.** The hero
  // is the roundest thing on the screen because it is the biggest; the sheet is
  // one step tighter because it is taller; the pills and the sheet rows are
  // tighter again because they are small enough that a 28 would read as a lozenge.
  static const double hero = 28;    // the gradient hero card
  static const double sheet = 24;   // the opaque bottom sheet
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
  /// of neutral black, two pixels wide. On a dark page that is not visible at
  /// all, which is why every card, tile and panel read as a flat rectangle with a
  /// hairline and nothing else. That is the "flat sekali" the surface system was
  /// reported as.
  ///
  /// A single shadow wide enough to see reads as a *float*: a dark halo around a
  /// shape, with nothing joining the shape to the page. So there are two. The
  /// tight one is the contact shadow — the dark line where the surface meets what
  /// it rests on — and the wide one is the ambient falloff away from it. This is
  /// the construction `AppGlass.heroShadow` already uses at hero scale; this tier
  /// is the one for a card.
  ///
  /// **Tinted with the hero's own deep blue rather than left neutral.** A
  /// neutral black shadow laid over a cool page desaturates it and reads as grey
  /// dirt rather than as shade; carrying the hero's hue keeps the lift in the
  /// app's colour family. The alphas sit one step under the hero's measured pair.
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

  /// A lift tinted with [hue] rather than neutral black, for a filled button
  /// that should read as its own colour. Material's `elevation` cannot carry a
  /// hue, so the call sites paint this through a `DecoratedBox` behind the fill.
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
    fontWeight: FontWeight.w600,
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
    fontFamily: mono,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.02 * 32,
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
// SECTION 9: GLASS (AppGlass) — WattVision glass + sheets
// ═════════════════════════════════════════════════════════════════════════════

/// WattVision extras: flat dark page, a gradient hero, translucent white glass
/// over it, and dark opaque sheets.
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
/// different layer of interface. [sheetRow] is a raised step rather than a tint
/// of the sheet, because a tint would let the page show through the one surface
/// that is supposed to be opaque.
class AppGlass {
  const AppGlass._();

  /// **Which ramp is live.** Dark-only: this always reports dark.
  static Brightness get brightness => AppTheme.brightness;

  static bool get isDark => brightness == Brightness.dark;

  /// Page gradient, top → bottom. **WattVision: flat #121212.**
  ///
  /// Kept as a three-stop list so every call site that paints a sweep still
  /// works; the stops are identical, so it renders flat.
  static const List<Color> pageGradientDark = <Color>[
    // WattVision: flat #121212 page (designmd spec).
    Color(0xFF121212),
    // WattVision: flat #121212 page.
    Color(0xFF121212),
    // WattVision: flat #121212 page — also the flat page (see AppSurfaces.page).
    Color(0xFF121212),
  ];

  /// **The page sweep for the active ramp.**
  ///
  /// A getter, so a call site never captures a stale list.
  static List<Color> get pageGradient =>
      isDark ? pageGradientDark : pageGradientLight;

  /// The light ramp's page: unused, kept identical to dark so the dark-only
  /// contract is literal rather than merely unused.
  static const List<Color> pageGradientLight = <Color>[
    Color(0xFF121212),
    Color(0xFF121212),
    Color(0xFF121212),
  ];

  /// Hero gradient, top-left → bottom-right, deep into deeper.
  static const List<Color> heroGradient = <Color>[
    Color(0xFF35619F),
    Color(0xFF1E3E75),
  ];

  /// **55% and 68%, and the number is a measurement.**
  ///
  /// The wash started at 14% / 34%, which is what "glass" looks like on a dark
  /// card over a dark page — and it is why the pair failed. A 14% white wash
  /// over a dark page lands on a **mid-tone**: too dark for dark ink and too
  /// light for white ink, so neither passes. Measured 2.41:1 for dark ink and
  /// 3.77:1 for white on the same pill.
  ///
  /// The wash has to carry the surface all the way to light, so that the dark
  /// label on it has something to read against. 55% reads as a tinted chip on
  /// the dark page; 68% is the selected state and the nav bar. The wash over the
  /// flat #121212 page must keep glass ink AA.
  static const double softAlpha = 0.55;
  static const double strongAlpha = 0.68;

  /// A resting glass surface: the stat card, a high/low pill, an hour pill.
  ///
  /// **Always white — and the ink on it is always dark.**
  ///
  /// **This is the reference's own rule and it is what makes the wash safe.**
  /// A translucent white pill over the dark page comes out *lighter* than the
  /// page: the wash decides the surface's lightness, not the page behind it. So
  /// the pill is a light chip and its label is dark — which is the only pairing
  /// that clears AA.
  ///
  /// It also means the wash must NOT invert. An earlier version used a black
  /// wash "so the tint would match the ink", which drags the pill toward the dark
  /// ink sitting on it. Inverting the wash is the wrong lever; the ink is the
  /// thing that follows the wash.
  static Color get fillSoft => Colors.white.withValues(alpha: softAlpha);

  /// The selected glass surface: the highlighted hour pill. A stronger white, so
  /// selection is a step in one axis rather than a second hue.
  static Color get fillStrong => Colors.white.withValues(alpha: strongAlpha);

  /// A third, middle strength for the high/low pills, which sit on the hero's
  /// lighter half and need more body than an hour pill on the page does.
  static Color get fill => Colors.white.withValues(alpha: 0.20);

  /// **The ink for content sitting on a [fillSoft] / [fillStrong] surface.**
  ///
  /// Dark, because the wash is white. This is deliberately *not*
  /// [pageInkStrong]: that is for content on the bare page. On glass the wash
  /// decides the ink.
  static const Color pageGlassInk = Color(0xFF0B2545);
  // **The same value as [pageGlassInk], and the measurement is why.**
  //
  // A tinted wash gives a label no headroom: a slightly lighter step lands under
  // the 4.5:1 the ink has to clear. The distinction a caption needs is carried by
  // size and weight, which is what the type scale is for — not by a fifth ink
  // value.
  static Color get pageGlassInkSoft => pageGlassInk;

  /// The ink on the **nav bar**, which is a strong glass wash over the page and
  /// therefore a light chip for the same reason the hour pills are.
  static Color get navInkSoft => pageGlassInkSoft;

  /// The divider between the stat card's three columns.
  static Color get divider =>
      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22);

  /// The two arrows on the high/low pills. Warm for the one that means "up", a
  /// cool blue for the one that means "down" — so the arrow is the only warm
  /// pixel in a cool screen, which is what makes it read as a direction rather
  /// than as a character.
  static Color get arrowUp => isDark ? arrowUpDark : arrowUpLight;
  static Color get arrowDown => isDark ? arrowDownDark : arrowDownLight;

  static const Color arrowUpDark = Color(0xFFFF8A5B);
  static const Color arrowDownDark = Color(0xFF7FB2FF);
  static const Color arrowUpLight = Color(0xFFE85D1F);
  static const Color arrowDownLight = Color(0xFF1D5FD6);

  /// The accent as a *graphic* drawn on the page, rather than on a card.
  ///
  /// WattVision's cyan clears 3:1 on #121212 for a live dot, a carousel dot and a
  /// section heading. Kept as its own token because a card accent and a page
  /// accent are measured against different grounds even when they are one hue.
  static const Color accentOnPage = Color(0xFF00E5FF);

  /// White ink at three strengths, which is what the **hero** needs: a title, a
  /// value, and a label. One colour at three alphas rather than three greys,
  /// because a grey chosen for a label on the hero reads flat against its
  /// gradient and this cannot.
  ///
  /// The hero is a deep gradient, so its ink is white. Everything drawn on the
  /// *page* instead uses [pageInkStrong] / [pageInk] / [pageInkSoft].
  static Color get inkStrong => Colors.white;
  static Color get ink => Colors.white.withValues(alpha: 0.92);
  static Color get inkSoft => Colors.white.withValues(alpha: 0.70);

  /// Ink for content sitting **directly on the page**, not inside the hero.
  ///
  /// White on #121212. The light branch stays for the dark-only clamp: if a
  /// future ramp ever ships, this token already answers it.
  static Color get pageInkStrong =>
      isDark ? Colors.white : const Color(0xFF0B2545);
  static Color get pageInk =>
      isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF10294D);
  static Color get pageInkSoft =>
      isDark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF24446F);

  /// The one opaque surface, and its two greys.
  static const Color sheet = Color(0xFF1E1E1E);
  static const Color sheetRow = Color(0xFF252525);
  static const Color sheetTitleInk = Color(0xFFFFFFFF);
  static const Color sheetRowInk = Color(0xFFFFFFFF);
  static const Color sheetRowInkMuted = Color(0xFF98989D);

  /// The sheet's grab handle, and the two page dots.
  static const Color handle = Color(0xFF4A4A50);
  static const Color dotInactive = Color(0xFF48484E);
  static const Color active = Color(0xFF00E5FF);

  /// The hero's own shadow. A gradient card on a dark page cannot be separated
  /// by a tonal step the way a lighter card could, so it carries a deep soft one
  /// instead — and it is the only shadow in the system, because glass is not
  /// a thing that gets a shadow, it is a thing that gets a border.
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
  static LinearGradient get pageSweep => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: pageGradient,
      );

  /// The flat colour the gradient's own top stop lands near.
  ///
  /// **This is the fallback, not the design.** It is what an overscroll bounce
  /// exposes above and below the sweep, and what shows for the one frame before
  /// the gradient resolves, so it must match the page or the seam is visible at
  /// exactly the moment the user is dragging.
  static Color get pageFallback =>
      isDark ? const Color(0xFF121212) : const Color(0xFF121212);
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 10: UTILITIES
// ═════════════════════════════════════════════════════════════════════════════

Color appDivider({double opacity = 1.0}) =>
    AppSurfaces.border.withValues(alpha: opacity);
