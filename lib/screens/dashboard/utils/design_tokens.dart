/// Every surface, radius, edge, type, shadow, spacing and motion value in the
/// app.
///
/// **This file was rewritten against the "Neon Brutalist Mobile" brief on 10
/// October 2026, and four of its load-bearing values changed.**
///
///   * **One accent, and it is acid lime.** The palette before this carried a
///     coral/periwinkle/butter set with no relationship to the brief. `primary`
///     is now `#C6FF00`, and it is reserved exactly as the brief reserves it:
///     the primary CTA, the active tab, the active chip, the live dot, the peak
///     bar, the focus ring. It is never a card background.
///   * **Elevation is a hard offset shadow, not a blur.** A card is stamped
///     `4px 4px 0 rgba(0,0,0,0.3)` — no blur, no spread, a solid displaced
///     rectangle. The primary button carries the tinted variant. The soft outer
///     glow is rare and lime-only, for a progress fill or a peak bar.
///   * **Radii are small.** Cards, inputs, buttons and list rows are 8px. Badges
///     are 2px. Filter pills are the only full-round shapes. The 24px card
///     radius this replaces was the previous system's; nothing in the brief
///     rounds past 8px.
///   * **Type is Inter, and it shouts.** 900 (Black) for displays, numerals and
///     button labels; 700 for the uppercase labels; 400 for the rare lowercase
///     body line. `fontFamily: 'Inter'` is the whole family list, and it is
///     bundled as three *static* instances — see `pubspec.yaml` for why a
///     variable file would render every weight at its default on older Android.
///
/// The two derived hues and the one deprecated token are recorded where they
/// are defined rather than here: see [AppPalette] for why green and cyan exist
/// in a palette whose categorical set is four.
library;

import 'package:flutter/material.dart';

/// The three-layer dark stack, plus the deepest fill.
///
/// Strictly ordered: `page` < `surface` < `surfaceAlt` < `surfaceMuted`.
/// Hierarchy is tonal; nothing here varies by theme, because there is one.
class AppSurfaces {
  const AppSurfaces._();

  /// The page canvas and the depressed track inside a progress bar, `#1A1A1A`.
  static const Color page = Color(0xFF1A1A1A);

  /// The card layer, `#222222` — every card, input and list row.
  ///
  /// **One step above [page], and the step is what the stamped shadow does its
  /// work against.** A hard offset shadow needs a wall to fall on: on a fill
  /// identical to the page the shadow reads as a second border rather than as a
  /// displacement. 15.9:1 for white text on it.
  static const Color surface = Color(0xFF222222);

  /// The secondary fill, `#2A2A2A` — chips and the tiles inside a card.
  ///
  /// **The binding surface for contrast.** It is the lightest of the three a
  /// caption is ever drawn on, so anything that clears AA here clears AA
  /// everywhere.
  static const Color surfaceAlt = Color(0xFF2A2A2A);

  /// The deepest fill, `#333333` — the empty state of a bar chart, the track of
  /// an un-filled bar, a legend dot.
  ///
  /// **Not in [captionSurfaces], and that is a statement about where text goes
  /// rather than about this value.** In this app nothing is read off a muted
  /// fill: the empty-state sentence is drawn on the card, and the muted colour
  /// is a shape. If a chip ever moves onto it, this comment is the thing to
  /// change first.
  static const Color surfaceMuted = Color(0xFF333333);

  /// Primary type, `#FFFFFF`.
  static const Color onSurface = Color(0xFFFFFFFF);

  /// Secondary type and metadata, `#A1A1A1`.
  ///
  /// **Measured, not asserted:** 11.8:1 on [page], 10.6:1 on [surface] and 4.9:1
  /// on [surfaceAlt] — the worst case anywhere in the app, and it clears AA with
  /// room to spare.
  static const Color onSurfaceVariant = Color(0xFFA1A1A1);

  /// The universal hairline, `#333333`.
  ///
  /// The brief has one border colour and it sits between `surface` and
  /// `surfaceAlt` tonally, which is what makes it read as an edge rather than as
  /// a line. **It is deliberately the same value as [surfaceMuted]**: a border
  /// and a deep fill are different roles that resolve to the same step, the way
  /// `pill` and `round` do.
  static const Color border = Color(0xFF333333);

  /// Text-input fill. Same value as [surface]: an input is a card.
  static const Color input = Color(0xFF222222);

  /// The depressed track inside a progress bar, `#1A1A1A` — the brief sets the
  /// track to the *background*, so the fill has to lift off the page rather than
  /// off a second grey.
  ///
  /// **Not the same value as [surfaceAlt], and that is the point.** A track
  /// carries no text; a tile does. The two used to resolve to one value, which
  /// is how this app's metric tiles once became invisible against the card.
  static const Color track = Color(0xFF1A1A1A);

  /// The tooltip, opaque because it must stay readable over an arbitrary series
  /// crossing underneath it.
  static const Color tooltip = Color(0xFF2A2A2A);

  /// Every surface the app paints a caption or a status colour on, in the order
  /// a reader should check them.
  ///
  /// **Derived, never written down.** A literal here is the copy that went
  /// stale twice in this repo and left three captions under AA with the suite
  /// green.
  static List<Color> captionSurfaces() => const [
    page,
    surface,
    surfaceAlt,
  ];

  /// The darkest step that still has to carry text. See [captionSurfaces].
  static Color get bindingCaptionSurface => surfaceAlt;
}

/// Corner radii, on the brief's scale.
///
/// Four values and two names for "fully round". **The card radius is 8, down
/// from 24** — the previous system's rounded-soft look is over, and the brief
/// is explicit that nothing rounds past 8 except the pills and the progress
/// track. The names the call sites already use are kept so that a change of
/// visual system was not also a rename of every widget in the app.
class AppRadius {
  const AppRadius._();

  /// Cards, inputs, buttons, list rows — the brief's `rounded.lg`, and the
  /// default.
  static const double card = 8;

  /// Tiles inside a card and chart-bar tops. Also 8: the brief says anything
  /// that is not a badge or a pill is 8.
  static const double tile = 8;

  /// A field set into a surface. Same value again — the brief has one radius
  /// for rectilinear things.
  static const double inset = 8;

  /// The near-square category badge, the brief's `rounded.xs`.
  static const double badge = 2;

  /// Rare small inline chips, the brief's `rounded.md`.
  static const double md = 6;

  /// Chart bar tops and secondary inline pills, the brief's `rounded.sm`.
  static const double sm = 4;

  /// Progress and split bars. A stadium: the brief's progress track is the only
  /// full-round shape that is not a filter chip.
  static const double bar = 999;

  /// Filter chips, buttons that pill, and anything else fully round.
  static const double pill = 999;

  /// Fully round, for dots and circular icon badges. Same value as [pill];
  /// both names are kept because they mean different things to a reader.
  static const double round = 999;

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

/// The brief's spacing scale.
///
/// Six values and two named roles. The page gutter is 16 (it was 24), the card
/// padding is 16 (it was 20) and the section gap is 24 — the brief's
/// "tight-but-breathing" density.
class AppSpacing {
  const AppSpacing._();

  /// The page edge inset, 16.
  static const double gutter = 16;

  /// Inside a card, 16.
  static const double cardPadding = 16;

  /// Between sections, 24.
  static const double sectionGap = 24;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Borders and edges — the silhouette the stamped shadow displaces.
///
/// A flat design has exactly one depth cue per axis: a 1px line around the
/// shape, and a hard shadow offset from it. The brief is explicit that the
/// shadow never blurs.
class AppBorders {
  const AppBorders._();

  /// The 1px hairline on a card. [AppSurfaces.border], un-tinted.
  ///
  /// **Neutral on purpose.** An earlier revision tinted this with the theme
  /// accent, which put a coloured outline on every card. A coloured border is a
  /// drawn edge, and hue is spoken for.
  static const BorderSide hairline = BorderSide(
    color: AppSurfaces.border,
    width: 1,
  );

  /// The outline on a control the user can press.
  ///
  /// Same value as [hairline]: the brief has one border colour. Kept as a
  /// separate name because a tappable thing and a labelled thing are different
  /// roles, and a future revision is allowed to separate them.
  static const BorderSide control = BorderSide(
    color: AppSurfaces.border,
    width: 1,
  );

  /// A neutral edge that clears WCAG 1.4.11's 3:1 for a UI component boundary.
  ///
  /// Reserved for the two controls that sit over camera content, where neither
  /// the tonal step nor the hairline can promise the boundary is visible.
  static const BorderSide boundary = BorderSide(
    color: Color(0xFFFAFAFA),
    width: 1.5,
  );

  // ── The same three, as a `BoxBorder` ─────────────────────────────────────────
  //
  // **These exist because `BorderSide` and `BoxBorder` are not interchangeable,
  // and the mistake is silent at the call site and loud in the analyzer.**
  // `BoxDecoration.border` takes a `BoxBorder`, and `Border.all(color:)` does
  // not compile. Both shapes are named so no call site has to convert.
  static const BoxBorder hairlineBorder = Border.fromBorderSide(hairline);
  static const BoxBorder controlBorder = Border.fromBorderSide(control);
  static const BoxBorder boundaryBorder = Border.fromBorderSide(boundary);

  /// The brief's categorical recipe: a 20%-alpha wash of the hue behind a
  /// full-strength foreground of the same hue.
  ///
  /// The one sanctioned way to put a hue behind text. A hand-written
  /// `hue.withValues(alpha: 0.3)` behind a caption is the mistake that cost
  /// contrast in three previous design systems in this app.
  static Color categoricalWash(Color hue) => hue.withValues(alpha: 0.20);

  /// The 20%-alpha border that goes with [categoricalWash].
  ///
  /// Returned as a [Border] rather than a [BorderSide], because every caller
  /// feeds a `BoxDecoration`.
  static Border categoricalBorder(Color hue) =>
      Border.fromBorderSide(
        BorderSide(color: hue.withValues(alpha: 0.20), width: 1),
      );
}

/// The hard shadows.
///
/// **This is the most distinctive move in the brief and it is the one the
/// previous system had wrong in every direction.** Elevation is a solid black
/// rectangle displaced down-and-right: no blur, no spread, no gradient. It
/// reads as a stamped sticker rather than as a floating surface, and it only
/// works because the card is lighter than the page.
///
/// Three tiers, as the brief defines them:
///
///  * **Flat** — the app bar, the tab bar, badges, chips. No shadow at all.
///  * **Stamped** — cards, inputs, list rows, and the primary button (with the
///    tinted displacement).
///  * **Glow** — rare, lime-only: a progress fill or a peak bar, so the accent
///    visibly emits.
class AppShadows {
  const AppShadows._();

  /// `4px 4px 0 rgba(0,0,0,0.3)`, the stamped tier.
  ///
  /// `blurRadius: 0` and `spreadRadius: 0` are the whole point — a `BoxShadow`
  /// with a blur would be the soft Material shadow this replaced.
  static const List<BoxShadow> stamped = [
    BoxShadow(
      color: Color(0x4D000000),
      offset: Offset(4, 4),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// `4px 4px 0` in the hue at 20%, for the primary button.
  static List<BoxShadow> stampedIn(Color hue) => [
    BoxShadow(
      color: hue.withValues(alpha: 0.20),
      offset: const Offset(4, 4),
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// The rare lime-only glow: `0 0 10px` at 50%.
  ///
  /// For a progress fill or a chart's peak bar. Nothing else in the app is
  /// allowed to glow.
  static List<BoxShadow> glow(Color hue, {double strength = 0.50}) => [
    BoxShadow(
      color: hue.withValues(alpha: strength),
      blurRadius: 10,
      offset: Offset.zero,
    ),
  ];
}

/// The three typefaces: one.
///
/// **Inter is the entire system** — the display family is loaded but unused in
/// chrome, and the brief's mono slot is reserved for raw data dumps that this
/// app does not have. The trick is weight rather than family: 900 (Black) for
/// everything that matters, 700 for the uppercase labels, 400 for the rare
/// lowercase body line. There is almost no 500.
///
/// All three static instances are bundled; see `pubspec.yaml`.
class AppType {
  const AppType._();

  /// Numerals and headlines.
  static const String heading = 'Inter';

  /// Labels, captions, metadata, body. Same family — the weight does the work.
  static const String sans = 'Inter';

  /// Ratios and tabular data. Same family again; nothing in this app dumps raw
  /// data, so the brief's mono slot stays empty.
  static const String mono = 'Inter';

  // ── Displays ─────────────────────────────────────────────────────────────────

  /// The screen-defining headline, two-line stacked, `display-lg`.
  static const TextStyle displayLg = TextStyle(
    fontFamily: heading,
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 0.95,
    letterSpacing: -0.04 * 48,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A secondary display, `display-md`. Same size as [numeralXl] on purpose:
  /// in this system numerals are display copy.
  static const TextStyle displayMd = TextStyle(
    fontFamily: heading,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.04 * 36,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A card title inside a list row, `headline-lg`.
  static const TextStyle headlineLg = TextStyle(
    fontFamily: heading,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -0.04 * 24,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A card sub-headline, `headline-md`.
  static const TextStyle headlineMd = TextStyle(
    fontFamily: heading,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -0.035 * 20,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── Numerals ─────────────────────────────────────────────────────────────────

  /// The hero figure on a card, `numeral-xl`. Same weight and tracking as the
  /// displays.
  ///
  /// **Tabular figures, and that is not decoration.** A live value that changes
  /// width as it changes digit count makes the whole card twitch on every poll,
  /// and the previous system solved it by setting numerals in a *different
  /// family*. The brief allows one family, so the fix moves to the feature that
  /// actually causes it.
  static const TextStyle numeralXl = TextStyle(
    fontFamily: heading,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.04 * 36,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A secondary figure, `numeral-lg`.
  static const TextStyle numeralLg = TextStyle(
    fontFamily: heading,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -0.035 * 24,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── Labels ───────────────────────────────────────────────────────────────────

  /// The workhorse muted ALL CAPS line, `label-uppercase-md`.
  ///
  /// The motif the whole system is identified by: uppercase, wide-tracked, bold.
  static const TextStyle labelUppercase = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.1 * 12,
  );

  /// Tiny tags: badge text, tab labels, micro-metadata, `label-uppercase-sm`.
  static const TextStyle labelMicro = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.12 * 10,
  );

  /// Button labels — `button-label`: Black weight, smaller, wide-tracked.
  ///
  /// **Buttons shout.** The brief gives them the display weight at 13px.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: 0.1 * 13,
  );

  // ── Body ─────────────────────────────────────────────────────────────────────

  /// The rare lowercase line, 400. Used sparingly: the brief prefers uppercase
  /// even for body.
  static const TextStyle bodyMd = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Small print under a chart, a footnote.
  static const TextStyle bodySm = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// A ratio or a tabular pair, where digit alignment has to be exact.
  static const TextStyle numeralMono = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// The durations and curves for everything that moves.
///
/// Unchanged by the restyle, because nothing here was about how a surface
/// looks. Press feedback is fast, state changes ease out, and nothing in the app
/// moves on a spring.
class AppMotion {
  const AppMotion._();

  /// A press or a toggle. Short enough to feel like the surface responding
  /// rather than the app animating.
  static const Duration press = Duration(milliseconds: 150);

  /// A value changing or a control changing state.
  static const Duration state = Duration(milliseconds: 200);

  /// A container appearing or being replaced.
  static const Duration container = Duration(milliseconds: 320);

  /// A page arriving.
  static const Duration page = Duration(milliseconds: 260);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve both = Curves.easeInCubic;
}

/// A divider, for the rare place that needs a rule rather than a border.
Color appDivider({double opacity = 1.0}) =>
    AppSurfaces.border.withValues(alpha: opacity);

/// The palette.
///
/// **One brand accent and four categorical markers, plus two hues the brief
/// does not have and this app needs.**
///
/// | token          | hex       | role                                            |
/// |----------------|-----------|-------------------------------------------------|
/// | [primary]      | `#C6FF00` | acid lime: the CTA, the active tab, the live dot |
/// | [secondary]    | `#4A9EFF` | blue — the AC / house category                  |
/// | [accent]       | `#FFB84D` | amber — the stale/warning status                 |
/// | [error]        | `#FF6B6B` | red — the environment category, breach fills     |
/// | [chartViolet]  | `#C084FC` | violet — the battery category                   |
/// | [chartCyan]    | `#22D3EE` | cyan — the water category                        |
/// | [success]      | `#4ADE80` | green — healthy                                  |
///
/// ### The two that are not in the brief
///
/// **Green.** The brief's palette has no green, and this app needs one colour
/// that means "a problem is absent" — it is the one remaining semantic role the
/// old system had and the brief has no equivalent for. `#4ADE80` measures 8.6:1
/// on [AppSurfaces.surfaceAlt].
///
/// **Cyan.** The brief's categorical set is four and the app has five data
/// categories. Water is the fifth, and it is the one category that never shares
/// a screen with another — the Fish tab is the only place it appears — so it
/// takes the one hue with no rival claim rather than doubling up on a brief
/// colour and breaking the "a hue never means two things" rule.
///
/// ### The one that is shared
///
/// [primary] is both the brand accent and the PV category. That is the brief's
/// own reuse pattern applied to the app's hero metric: it sanctions lime as the
/// "peak bar in charts", and PV power is the peak data this app charts. It is
/// used as an icon, a border and a series line — never as a fill — so it never
/// becomes a card background, which is the one thing the brief forbids outright.
class AppPalette {
  const AppPalette._();

  /// Acid lime. The focal hue, and the PV category.
  static const Color primary = Color(0xFFC6FF00);

  /// Blue. The AC / house category.
  static const Color secondary = Color(0xFF4A9EFF);

  /// Amber. The stale/warning status.
  static const Color accent = Color(0xFFFFB84D);

  /// Green. A healthy reading. Derived: see the class doc.
  static const Color success = Color(0xFF4ADE80);

  /// Red. The environment category, and the breach fill. Derived shade of the
  /// brief's `accent-red`, which is used as the categorical marker here.
  static const Color error = Color(0xFFFF6B6B);

  /// Violet. The battery category.
  ///
  /// **The brief's `#A855F7` scaled up 1.28x per channel, and the direction is
  /// the whole point.** The obvious fix for a colour that fails contrast on a
  /// dark surface is to darken it, and that takes it further from white. Scaled
  /// rather than stepped in HSL, so the hue is preserved exactly.
  static const Color chartViolet = Color(0xFFC084FC);

  /// Cyan. The water category. Derived: see the class doc.
  static const Color chartCyan = Color(0xFF22D3EE);

  /// Ink on a saturated fill. The brief's `on-primary`: black on lime.
  static const Color onHue = Color(0xFF000000);

  /// **Deprecated: use [AppShadows].** `aura` was a blurred halo, and the brief
  /// bans blur outright. Kept as a name because a call site may still reach
  /// for it, and it now returns the one legal glow.
  static List<BoxShadow> aura(Color hue, {double strength = 0.50}) =>
      AppShadows.glow(hue, strength: strength);
}
