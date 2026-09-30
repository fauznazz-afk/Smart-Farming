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
  /// that was a step lighter than the page would read as flat Material.
  ///
  /// **Light mode is a mid-tone on purpose, and this is the most consequential
  /// value in the file.** The first version was `#F1F4F2`, close enough to
  /// white that the result on the device was not neumorphism at all. The light
  /// half of every shadow pair is white, so on a near-white page it had nowhere
  /// to be lighter *to*; only the dark half showed, and every card read as flat
  /// Material with a grey edge. A mid-tone is what gives both halves somewhere
  /// to go.
  ///
  /// A darker surface also means *more* contrast for dark text on it, so this
  /// helps the AA numbers rather than hurting them.
  static const Color pageLight = Color(0xFFE1E7E4);
  static const Color pageDark = Color(0xFF1A211F);

  /// Chrome that sits above the page and must separate from it by fill rather
  /// than by shadow: the bottom navigation pill, the app bar scrim.
  ///
  /// One step off the page colour. These are the two surfaces where a
  /// dual-shadow pair would fight the scrim behind them.
  static const Color chromeLight = Color(0xFFE9EEEB);
  static const Color chromeDark = Color(0xFF232B28);

  /// Input fills, and the reason the deboss is carried by an inner shadow
  /// rather than by a darker fill.
  ///
  /// A conventional inset treatment darkens the field. Here that is exactly
  /// the change that breaks the app: `0xFFEBEFEA`, the old light
  /// `InputDecorationTheme.fillColor`, was the *binding surface* for all five
  /// colour assertions in `test/color_helpers_test.dart`, and every one of them
  /// cleared 4.5:1 by less than 0.43. Darkening it would have dropped
  /// `faintColor`, `statusOk`, `statusWarn` and `statusAlert` below AA together.
  /// The field is therefore *lighter* than the page, which keeps the text
  /// contrast and still reads as inset once the inner shadow is added.
  static const Color inputLight = Color(0xFFEDF1EF);
  static const Color inputDark = Color(0xFF1E2623);

  /// Bars that show a quantity rather than a container: the power-flow split
  /// bar, the state-of-charge track, the energy forecast progress bar.
  static const Color trackLight = Color(0xFFCFD6D2);
  static const Color trackDark = Color(0xFF131A18);

  /// The chart tooltip, which is opaque because it must stay readable over an
  /// arbitrary series crossing underneath it.
  static const Color tooltipLight = Color(0xFFEDF1EF);
  static const Color tooltipDark = Color(0xFF262E2B);

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

  /// **Why a raised surface has three shadows and not two, and why the third is
  /// the one that makes it look deep.**
  ///
  /// A pair of equal shadows reads as a *float*: one dark blur and one light
  /// blur of the same size, and the eye gets two soft halos with no surface
  /// between them. What real extruded objects have is a *contact shadow* — the
  /// tight, dark line right where the object meets what it sits on — and only
  /// then the soft ambient one spreading away from it. Two distinct distances
  /// is what makes the card read as a solid block with a measurable thickness
  /// rather than as a glowing rectangle.
  ///
  /// So the dark half is now two shadows at different scales:
  ///
  ///  * **contact**, small offset and small blur. This is the lip. It is what
  ///    the eye uses to find the edge of the card, and it is the only one of the
  ///    three that is nearly opaque.
  ///  * **ambient**, roughly twice the offset and three times the blur. This
  ///    gives the card weight and makes it feel like it is standing off the
  ///    page.
  ///
  /// and the light half is one broad shadow up and to the left, doing the job
  /// the ambient one does on the other side. The asymmetry is deliberate: a
  /// light source produces a small hard highlight and a wide soft bounce, and
  /// mirroring the dark pair exactly is what makes CSS neumorphism look like a
  /// 1990s bevel.
  ///
  /// **This costs nothing in contrast, and that is the whole reason the work
  /// went here rather than into the fill.** A `BoxShadow` is painted outside
  /// the decoration's rect — it is impossible for it to darken the card's own
  /// interior, which is where every caption in the app is drawn.
  ///
  /// By contrast, a gradient across the card fill was measured and rejected: at
  /// just 4% the light mode worst case falls to 4.15:1, and AA is 4.5. Depth in
  /// this style is a shadow property, not a fill property, and the measurement is
  /// the reason that is a design rule here rather than a preference.
  ///
  /// **The light-mode alphas were raised once more after a pixel measurement,
  /// and the measurement is the argument.** At `0x4D` / `0x33` the dark half was
  /// only reaching a luminance of 219 against a 229.5 page — a 4.6% drop, which
  /// the blur spreads so thin that the light half was doing nearly all the work
  /// and the card read as *lit* rather than as standing off the surface. The
  /// dark half is now `0x66` / `0x40`. Dark mode needed no equivalent change and
  /// was left alone: it already measured 17.6 against a 31.4 page, a 44% drop,
  /// because a black shadow over an almost-black surface is still a large
  /// relative move.
  ///
  /// The asymmetry is worth knowing about rather than averaging away. Light mode
  /// is the harder of the two for this style, because a mid-tone page is by
  /// definition a small distance from both the white light half and the dark
  /// half, so both have to work harder than they do on a near-black page.
  ///
  /// Dark mode inverts which half does the work, because on a dark surface it
  /// is the light shadow that defines the edge and the black one that is
  /// merely absence.
  static List<BoxShadow> raised(bool isDark) => isDark
      ? const [
          // contact
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
          // ambient
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 22,
            offset: Offset(9, 9),
          ),
          // bounce, up and to the left
          BoxShadow(
            color: Color(0x29FFFFFF),
            blurRadius: 14,
            offset: Offset(-6, -6),
          ),
        ]
      : const [
          // contact
          BoxShadow(
            color: Color(0x663D4A44),
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
          // ambient
          BoxShadow(
            color: Color(0x403D4A44),
            blurRadius: 22,
            offset: Offset(9, 9),
          ),
          // bounce, up and to the left
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 14,
            offset: Offset(-6, -6),
          ),
        ];

  /// A pressed control: the light source is inside the well.
  ///
  /// Both shadows point inward, so the surface reads as cut into the page
  /// rather than sitting on it. Used for input fields and for the date chips
  /// that are not selected.
  ///
  /// The inset pair is scaled *down* from the raised one rather than being
  /// independently chosen, and the relationship is the point: a well is a
  /// smaller feature than a block standing on the page, so its contact shadow
  /// sits closer and its ambient one barely reaches. A well with the raised
  /// geometry reads as a block that has fallen *into* the page, which is a
  /// different and wrong impression.
  static List<BoxShadow> inset(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 10,
            offset: Offset(5, 5),
          ),
          BoxShadow(
            color: Color(0x1FFFFFFF),
            blurRadius: 8,
            offset: Offset(-4, -4),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x593D4A44),
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
          BoxShadow(
            color: Color(0x2E3D4A44),
            blurRadius: 10,
            offset: Offset(5, 5),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 10,
            offset: Offset(-5, -5),
          ),
        ];

  /// A well that is being pushed *further in*.
  ///
  /// This exists because "pressed" is not one state, it is two, and using one
  /// pair for both was the mistake in the first version of the press vocabulary.
  /// A raised block being pressed flattens — it comes up off the page. A well
  /// being pressed goes *down*, deeper into the page, so its contact shadow
  /// tightens and its ambient one reaches further.
  ///
  /// The light still comes from inside, so the sign of every offset is the
  /// same as [inset]; only the magnitudes change. Using [pressed] here would
  /// have inverted the offsets and turned a chip being pushed into a chip
  /// popping out, which is the opposite of what the finger is asking for.
  static List<BoxShadow> insetDeep(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0xD9000000),
            blurRadius: 3,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 14,
            offset: Offset(7, 7),
          ),
          BoxShadow(
            color: Color(0x14FFFFFF),
            blurRadius: 6,
            offset: Offset(-3, -3),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x733D4A44),
            blurRadius: 3,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0x3D3D4A44),
            blurRadius: 14,
            offset: Offset(7, 7),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 8,
            offset: Offset(-4, -4),
          ),
        ];

  /// The pair a control animates *to* while it is held down.
  ///
  /// Not [inset] with a different radius — the opposite one. A press in this
  /// style is the surface reversing: the block that was standing off the page
  /// sinks into it, the light source moves from outside to inside, and the
  /// bounce that was up-left goes down-right. Animating between the two pairs is
  /// what makes a soft-UI button feel physical, and it is a swap rather than a
  /// fade because a shadow pair that cross-fades halfway through reads as two
  /// shadows at once, which is the exact artefact a light-source rule exists to
  /// prevent.
  ///
  /// It is exported separately because `AppCard.pressed` had no caller anywhere
  /// in the app, which meant the whole press vocabulary was written and never
  /// switched on. See `pressable.dart`.
  static List<BoxShadow> pressed(bool isDark) => isDark
      ? const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 3,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0x1FFFFFFF),
            blurRadius: 6,
            offset: Offset(-2, -2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x333D4A44),
            blurRadius: 3,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 5,
            offset: Offset(-2, -2),
          ),
        ];

  /// The hairline on a card, and the reason it is **neutral**.
  ///
  /// Soft UI expresses a container's edge through its shadow pair and drops the
  /// outline. This file kept one, for an accessibility reason that still holds:
  /// WCAG 1.4.11 wants 3:1 for a UI component boundary and no test measures it,
  /// so removing the only edge cue a low-vision user had would have left
  /// nothing measurable behind.
  ///
  /// What was wrong was the *colour*, not the existence. It was tinted with the
  /// theme accent, so every card in the app wore a green outline, and that is
  /// the one thing that stops a surface reading as soft UI: a coloured border
  /// is a drawn edge, and a drawn edge is what this style exists to replace.
  /// On the device it was unmistakable — five green-outlined cards reading as
  /// Material, which is the exact look this migration was for.
  ///
  /// So the hairline is now a very light neutral, aligned with the light source:
  /// it reinforces the top-left lip rather than framing the card. It is a
  /// whisper, not an outline. [accent] is kept in the signature so a call site
  /// that genuinely needs a themed edge can still ask for one via
  /// [controlEdge] — but no card does.
  static Color hairline({required Color accent, required bool isDark}) =>
      isDark ? const Color(0x14FFFFFF) : const Color(0x99FFFFFF);

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
