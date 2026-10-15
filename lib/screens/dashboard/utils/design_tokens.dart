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

  static Color get bindingCaptionSurface => surfaceAlt;
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
    page: Color(0xFF1F2937),
    surface: Color(0xFF374151),
    surfaceAlt: Color(0xFF4B5563),
    surfaceMuted: Color(0xFF6B7280),
    onSurface: Color(0xFFF9FAFB),
    onSurfaceVariant: Color(0xFFD1D5DB),
    border: Color(0xFF4B5563),
    input: Color(0xFF1F2937),
    track: Color(0xFF1F2937),
    tooltip: Color(0xFF111827),
  );

  static const AppSurfacesPalette light = AppSurfacesPalette(
    brightness: Brightness.light,
    page: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF9FAFB),
    surfaceMuted: Color(0xFFE0E0E0),
    onSurface: Color(0xFF111827),
    onSurfaceVariant: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    input: Color(0xFFFFFFFF),
    track: Color(0xFFF3F4F6),
    tooltip: Color(0xFF111827),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 2: THEME (AppTheme)
// ═════════════════════════════════════════════════════════════════════════════

class AppTheme {
  const AppTheme._();

  static Brightness _brightness = Brightness.light;

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
  static Color get statusAlert => _active.warning;
  static Color get statusBad => _active.error;

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
    required this.error,
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
  final Color error;
  final Color info;
  final Color chartRed;
  final Color chartGreen;
  final Color chartBlue;
  final Color onPrimary;
  final Color onSecondary;
  final Color onTertiary;
  final Color onHue;

  static const AppPaletteTheme light = AppPaletteTheme(
    primary: Color(0xFF6366F1),
    secondary: Color(0xFF14B8A6),
    tertiary: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF6366F1),
    chartRed: Color(0xFFEF4444),
    chartGreen: Color(0xFF10B981),
    chartBlue: Color(0xFF3B82F6),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFF000000),
    onHue: Color(0xFFFFFFFF),
  );

  static const AppPaletteTheme dark = AppPaletteTheme(
    primary: Color(0xFF818CF8),
    secondary: Color(0xFF2DD4BF),
    tertiary: Color(0xFFFBBF24),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    info: Color(0xFF818CF8),
    chartRed: Color(0xFFF87171),
    chartGreen: Color(0xFF34D399),
    chartBlue: Color(0xFF60A5FA),
    onPrimary: Color(0xFF000000),
    onSecondary: Color(0xFF000000),
    onTertiary: Color(0xFF000000),
    onHue: Color(0xFF000000),
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

  // Aliases for semantic use
  static const double card = md;
  static const double button = md;
  static const double input = md;
  static const double badge = sm;
  static const double pill = full;
  static const double round = full;
  static const double bar = full;

  // Backward compatibility aliases
  static const double tile = md;    // was same as card
  static const double inset = md;   // was same as card

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 6: ELEVATION (AppShadows)
// ═════════════════════════════════════════════════════════════════════════════

class AppShadows {
  const AppShadows._();

  /// Subtle: 1px offset, 2px blur, #000000 at 4% — resting widgets
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
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

  static Color categoricalWash(Color hue) => hue.withValues(alpha: 0.20);

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

  // Font families - using system font fallbacks for cross-platform compatibility
  // Inter for headings (bundled), system sans-serif for body, JetBrainsMono for terminal
  static const String heading = 'Inter';
  static const String sans = 'Segoe UI, Roboto, Helvetica, Arial, sans-serif';
  static const String mono = 'JetBrainsMono';

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

  // ══ Overline ══════════════════════════════════════════════════════════════

  static const TextStyle overline = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: 0.08 * 10,
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
    fontWeight: FontWeight.w400,
    height: 1.50,
  );

  // ══ Numeric displays (for metrics) ════════════════════════════════════════

  static const TextStyle numeralXl = TextStyle(
    fontFamily: mono,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.02 * 28,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numeralLg = TextStyle(
    fontFamily: mono,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -0.02 * 20,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle numeralMd = TextStyle(
    fontFamily: mono,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Alias for backward compatibility
  static TextStyle get numeralMono => code;

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
// SECTION 10: UTILITIES
// ═════════════════════════════════════════════════════════════════════════════

Color appDivider({double opacity = 1.0}) =>
    AppSurfaces.border.withValues(alpha: opacity);