import 'package:flutter/material.dart';

/// The surface layer of the app: every opaque fill, hairline and dual-shadow
/// pair, in one file.
///
/// **Why this file exists.** Before it, the visual system had no token layer at
/// all. `LiquidGlassCard` was one primitive used at eight call sites, and around
/// it sat roughly thirty-five hand-written `BoxDecoration`s across eighteen
/// files, each choosing its own fill, its own border and its own radius. There
/// were six different card treatments, three different shadow vocabularies, and
/// twelve distinct radius values. A restyle had no single file to change and no
/// mechanical way to find the stragglers, and a missed one is a visual
/// regression that `flutter analyze` and the whole test suite pass.
///
/// **Why the fills are opaque.** They were not. Card fills were a gradient at
/// alpha 0.44 to 0.66, composited over a background painted with three large
/// radial-gradient orbs, so the actual rendered fill varied continuously with
/// the pixel and with the orb underneath. `test/color_helpers_test.dart` has
/// always asserted contrast against the *backdrop base* colours while its own
/// comments called them card fills. Soft-UI surfaces are opaque by definition —
/// the depth reads through shadow, not through translucency — so making the
/// fills opaque is what lets the contrast claim become true rather than
/// approximately true. The trade is that the orbs are gone, and with them the
/// only thing the translucency existed to reveal.
///
/// The whole app is two neutrals and one accent. Nothing here varies a hue
/// automatically: see `color_helpers.dart` for why a per-index rotation was
/// implemented and then reverted.
class AppSurfaces {
  const AppSurfaces._();

  /// The page backdrop, and also the card fill.
  ///
  /// A neumorphic surface is the *same colour* as what it sits on; that is what
  /// makes the shadow pair legible as a shadow rather than as a border. A card
  /// that was a step lighter than the page would read as flat Material, which is
  /// the look this is moving away from.
  static const Color pageLight = Color(0xFFF1F4F2);
  static const Color pageDark = Color(0xFF161B19);

  /// Chrome that sits above the page and must separate from it by fill rather
  /// than by shadow: the bottom navigation pill, the app bar scrim.
  ///
  /// One step off the page colour. These are the two surfaces where a
  /// dual-shadow pair would fight the scrim behind them.
  static const Color chromeLight = Color(0xFFFAFBFA);
  static const Color chromeDark = Color(0xFF1E2422);

  /// Input fills, and the reason the deboss is carried by an inner shadow
  /// rather than by a darker fill.
  ///
  /// A conventional inset treatment darkens the field. Here that is exactly
  /// the change that breaks the app: `0xFFEBEFEA`, the old light
  /// `InputDecorationTheme.fillColor`, was the *binding surface* for all five
  /// colour assertions in `test/color_helpers_test.dart`, and every one of them
  /// cleared 4.5:1 by less than 0.43. Darkening it would have dropped
  /// `faintColor`, `statusOk`, `statusWarn` and `statusAlert` below AA together.
  /// The field is therefore *lighter* than the page in light mode, which keeps
  /// the text contrast and still reads as inset once the inner shadow is added.
  static const Color inputLight = Color(0xFFFAFBFA);
  static const Color inputDark = Color(0xFF1B211F);

  /// Bars that show a quantity rather than a container: the power-flow split
  /// bar, the state-of-charge track, the energy forecast progress bar.
  static const Color trackLight = Color(0xFFDDE3E0);
  static const Color trackDark = Color(0xFF0F1412);

  /// The chart tooltip, which is opaque because it must stay readable over an
  /// arbitrary series crossing underneath it.
  static const Color tooltipLight = Color(0xFFFAFBFA);
  static const Color tooltipDark = Color(0xFF222A27);

  /// The page fill for the surfaces the chart is drawn on. Deliberately the page
  /// colour and nothing else, so grid lines are the only thing between the
  /// series and the background.
  static Color page(bool isDark) => isDark ? pageDark : pageLight;

  static Color card(bool isDark) => page(isDark);

  static Color chrome(bool isDark) => isDark ? chromeDark : chromeLight;

  static Color input(bool isDark) => isDark ? inputDark : inputLight;

  static Color track(bool isDark) => isDark ? trackDark : trackLight;

  static Color tooltip(bool isDark) => isDark ? tooltipDark : tooltipLight;
}

/// Corner radii, on one scale.
///
/// The app had twelve distinct values from 3 to 28, and the two largest ones
/// were the outliers: cards at 20 and the navigation pill at 28, with
/// everything else between 8 and 16. That is a default plus exceptions rather
/// than a scale. These are the same twelve uses, now named, and the card radius
/// is 16 so it joins the rest instead of sitting above it.
///
/// `bar` is not on the 8px grid on purpose: a 5px radius on an 8px-tall bar is
/// a stadium, and the old code had five different values for the same semantic
/// object.
class AppRadius {
  const AppRadius._();

  /// Cards, section cards, the energy report's cards, the CCTV info bar.
  static const double card = 16;

  /// The bottom navigation pill. Larger than a card because it is the one
  /// element that is meant to read as a separate physical object.
  static const double pill = 22;

  /// Tiles inside a card, the date strip chips, buttons, the CCTV status pill.
  static const double tile = 14;

  /// Banners, inputs, icon tiles, small readouts.
  static const double inset = 12;

  /// Badges and narrow tags.
  static const double badge = 10;

  /// Progress and split bars.
  static const double bar = 4;

  /// Fully round, for dots and circular icon badges.
  static const double round = 999;

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

/// The dual-shadow pairs that carry all the depth in the app.
///
/// One light source, one direction, everywhere. The light comes from the top
/// left, so a raised surface has a *dark* shadow down and to the right and a
/// *light* shadow up and to the left. A surface that is pressed in does the
/// exact opposite. An inconsistent light direction is the single thing that
/// makes soft UI look broken rather than soft, and it cannot be checked by
/// looking at one widget — every card on every screen has to agree, which is
/// why these live in one file instead of at six call sites.
///
/// The old design had a different model: a `white @ 0.70` specular edge one
/// pixel above the top border, and a `black @ 0.38` drop shadow below. That
/// reads as glass. These read as a solid block sitting on the page, which is the
/// intended change.
class AppElevation {
  const AppElevation._();

  // The distances below are written per-role rather than shared. An earlier
  // version factored them into `_offset` / `_blur` constants, and the two lists
  // ended up not actually using them: raised and inset have different geometry
  // because a well is smaller than a block sitting on the page.

  /// A raised card: casts down-right, catches light up-left.
  ///
  /// Light mode's dark shadow is deliberately weak. On a light surface a strong
  /// drop shadow stops reading as depth and starts reading as dirt around the
  /// card; the light shadow is what does the work there. Dark mode inverts that,
  /// because on a dark surface it is the light shadow that defines the edge.
  static List<BoxShadow> raised(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0xFF000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x14FFFFFF),
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A3D4A44),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 10,
            offset: Offset(-3, -3),
          ),
        ];

  /// A pressed control: the light source is inside the well.
  ///
  /// Both shadows point inward, so the surface reads as cut into the page
  /// rather than sitting on it. Used for input fields and for the date chips
  /// that are not selected.
  static List<BoxShadow> inset(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 6,
            offset: Offset(2, 2),
          ),
          BoxShadow(
            color: Color(0x0DFFFFFF),
            blurRadius: 4,
            offset: Offset(-2, -2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1F3D4A44),
            blurRadius: 6,
            offset: Offset(2, 2),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 6,
            offset: Offset(-2, -2),
          ),
        ];

  /// A hairline, for the boundaries that shadow cannot carry.
  ///
  /// Soft UI expresses a container's edge through its shadow pair and drops the
  /// outline. That is mostly right, and it is also where the accessibility
  /// cost lands: WCAG 1.4.11 wants 3:1 for a UI component boundary and nothing
  /// in the suite measures it. The borders that already existed were at
  /// `alpha 0.06` to `0.28` of their own accent, which is far under 3:1, so
  /// "remove the hairline" would have removed the only edge cue a low-vision
  /// user had and left nothing measurable behind. The hairline therefore stays,
  /// and on interactive controls it is stronger than it was.
  static Color hairline({required Color accent, required bool isDark}) =>
      accent.withValues(alpha: isDark ? 0.22 : 0.20);

  /// The outline on a control the user can press, where 3:1 is a real
  /// requirement rather than a nicety.
  ///
  /// Measured, and this is the part that changes the design rather than just
  /// documenting it: on the light page the default accent `0xFF35A968` is
  /// **2.70:1 at full opacity**, so no alpha of it can reach the 3:1 that WCAG
  /// 1.4.11 wants — 0.45 gives 1.54, 0.70 gives 1.98, 1.00 gives 2.70. An
  /// accent-tinted edge therefore cannot be a compliant boundary, and this
  /// function is a tint for *legibility and grouping*, not a 1.4.11 guarantee.
  ///
  /// For a boundary that genuinely has to clear 3:1, use [boundaryEdge], which
  /// is a neutral. `0x3D4A44` at 0.60 measures 3.04:1 on the light page, which
  /// is a heavy grey line; the reason it is not the default everywhere is that
  /// an accent-tinted edge is what keeps the app looking themed, and a
  /// compliant-but-neutral outline on every control would put a grey frame
  /// around every element in an amber theme.
  static Color controlEdge({required Color accent, required bool isDark}) =>
      accent.withValues(alpha: isDark ? 0.55 : 0.45);

  /// A neutral edge that clears WCAG 1.4.11's 3:1 for a UI component boundary
  /// on the light page.
  ///
  /// Reserved for the two places where the control has no other affordance: the
  /// CCTV info bar, which sits over video, and the standby play button, which
  /// sits over a dimmed frame. Both were at 1.14:1 and 1.35:1 before.
  static Color boundaryEdge({required bool isDark}) => isDark
      ? Colors.white.withValues(alpha: 0.45)
      : const Color(0xFF3D4A44).withValues(alpha: 0.60);
}

/// A divider, on the same two-surface rule as everything else.
Color appDivider({required bool isDark, double opacity = 0.10}) =>
    isDark
        ? Colors.white.withValues(alpha: opacity)
        : const Color(0xFF3D4A44).withValues(alpha: opacity);

/// The durations and curves for everything that moves.
///
/// There were three distinct curves in the app before this, and the two
/// `AnimatedSwitcher`s in the navigation bar and the one in Settings used the
/// library default because no curve was passed. Three named curves that every
/// call site shares is the whole vocabulary: press feedback is fast and linear-
/// ish, state changes ease out, and nothing in the app moves on a spring.
class AppMotion {
  const AppMotion._();

  /// A press or a toggle. Short enough to feel like the surface responding
  /// rather than the app animating.
  static const Duration press = Duration(milliseconds: 150);

  /// A value changing or a control changing state.
  static const Duration state = Duration(milliseconds: 200);

  /// A container appearing or being replaced.
  static const Duration container = Duration(milliseconds: 320);

  /// A page arriving. Fading in without sliding reads as deliberate; a long
  /// slide on a dense dashboard reads as the layout catching up.
  static const Duration page = Duration(milliseconds: 260);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve both = Curves.easeInOutCubic;
}
