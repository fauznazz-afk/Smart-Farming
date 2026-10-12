/// Every surface, radius, edge, type, shadow, spacing and motion value in the
/// app.
///
/// **This file was rewritten against the "Neon Brutalist Mobile" brief on 10
/// October 2026, and four of its load-bearing values changed.**
///
///   * **One accent, and it is red.** [AppPalette.error], `#FF6B6B`, is the only
///     hue the app spends on chrome: the primary CTA, the active chip, the
///     avatar ring, the live dot, the meter fill, every panel heading. Everything
///     else is a neutral from [AppSurfaces]. The lime, blue, violet, cyan and
///     green tokens are still in [AppPalette] because the chart-series order and
///     the status ramp read them, but none of them may be *decoration* — a hue
///     in a heading, a label, an icon or a border that is not carrying data is
///     the thing this rule exists to remove.
///   * **Elevation is a hard offset shadow, not a blur.** A card is stamped
///     `4px 4px 0 rgba(0,0,0,0.3)` — no blur, no spread, a solid displaced
///     rectangle. The primary button carries the tinted variant. The soft outer
///     glow is rare and accent-only, for a progress fill or a peak bar.
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
/// The hues that are not the accent are recorded where they are defined rather
/// than here: see [AppPalette] for which ones still have a reader and which are
/// retained only so a call site keeps compiling.
library;

import 'package:flutter/material.dart';

/// The three-layer surface stack, plus the deepest fill.
///
/// **Swappable, and every value here is read through an instance.**
///
/// The stack used to be `static const`, which was honest while there was one
/// appearance and impossible the moment there were two: a `const` cannot change
/// at runtime, so the only way in would have been rewriting all 148 call sites
/// into `Theme.of(context)` lookups — a mechanical change across 34 files with
/// no way to prove none of them was missed.
///
/// So the names stay where they were and the *values* become a pair of
/// immutable palettes behind a static accessor. A call site reads
/// `AppSurfaces.page` exactly as before; what it resolves to depends on
/// [AppTheme.brightness], which [AppTheme.apply] sets from the chosen theme
/// mode before the tree that reads it is rebuilt.
///
/// **The order is per-palette, not global.** Dark runs `page` < `surface` <
/// `surfaceAlt` < `surfaceMuted` going *up* out of the canvas; light runs the
/// same ladder the other way, because "a step off the paper" is a step *down*
/// into it. `bindingCaptionSurface` is the end that binds contrast — the
/// lightest fill a caption is drawn on in dark, the darkest in light — and it is
/// a getter for that reason.
class AppSurfaces {
  const AppSurfaces._();

  static AppSurfacesPalette _palette = AppSurfacesPalette.dark;

  /// Swaps the active palette. Called once per theme change, before the
  /// subtree that reads these values is rebuilt.
  ///
  /// Not a setter that notifies: there is nothing here to notify. The swap
  /// happens inside the `setState` that also rebuilds `MaterialApp`, so the
  /// tree that reads a static accessor is rebuilt by the same gesture.
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

  /// Every surface the app paints a caption or a status colour on, in the order
  /// a reader should check them.
  ///
  /// **Derived, never written down.** A literal here is the copy that went
  /// stale twice in this repo and left three captions under AA with the suite
  /// green.
  static List<Color> captionSurfaces() => [page, surface, surfaceAlt];

  /// The end of the ramp that still has to carry text.
  ///
  /// **`surfaceAlt` in both palettes, and that is measured rather than assumed.**
  /// In dark it is the lightest fill a caption lands on. In light it is the
  /// *darkest* — `surface` is a white card lifted off the paper and `surfaceAlt`
  /// is an inset tile below it — and a dark ink on the darkest surface is the
  /// same weakest pair, one step along the same ladder rather than the other
  /// way round. So the name does not have to know which palette it is in.
  ///
  /// A palette edit that makes a different surface the binding one fails
  /// `theme_palette_contrast_test.dart`, rather than letting every caption
  /// clear AA against a more forgiving surface than the one rendering — the
  /// failure this repo has already had twice.
  static Color get bindingCaptionSurface => surfaceAlt;
}

/// One appearance's worth of surfaces.
///
/// An immutable value rather than a theme extension, so that [AppSurfaces] can
/// publish it through static accessors with no `BuildContext` in sight.
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

  /// The canvas and the depressed track inside a progress bar.
  ///
  /// **Pitch black, and it is deliberate.** It was `#1A1A1A`, a value that came
  /// from light mode where the page had to stay a mid-tone for a shadow to fall
  /// on. The instrument panels take their depth from the hairline and the
  /// segmented bar instead, so that reason is gone and the reference won.
  static const AppSurfacesPalette dark = AppSurfacesPalette(
    brightness: Brightness.dark,
    page: Color(0xFF000000),
    surface: Color(0xFF222222),
    surfaceAlt: Color(0xFF2A2A2A),
    surfaceMuted: Color(0xFF333333),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFA1A1A1),
    border: Color(0xFF333333),
    input: Color(0xFF222222),
    track: Color(0xFF000000),
    tooltip: Color(0xFF2A2A2A),
  );

  /// The light counterpart: paper, not white.
  ///
  /// **`#F2F3F0` and not `#FFFFFF`, measured rather than chosen.** A pure white
  /// page next to a white card gives the tonal step nowhere to go, which is the
  /// same failure the previous dark system had when the page was near-black
  /// with a near-black card. Every value below is scaled by one factor per
  /// channel where it had to move, so hue holds.
  ///
  /// The ladder runs the other way from [dark]: `page` is the *lightest* and
  /// `surfaceMuted` the darkest, so a card is a step down into the paper rather
  /// than a step up out of it. `track` is the page value, the same rule dark
  /// follows — an un-lit meter segment is a hole in the surface it sits on.
  static const AppSurfacesPalette light = AppSurfacesPalette(
    brightness: Brightness.light,
    page: Color(0xFFF2F3F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFDFE2DE),
    // `border` and `surfaceMuted` are the same value, as in the dark ramp and
    // as the token documents: the brief has one border colour, and a border and
    // a deep fill are different roles that resolve to the same step.
    surfaceMuted: Color(0xFFB9BFB8),
    onSurface: Color(0xFF111311),
    onSurfaceVariant: Color(0xFF595F59),
    border: Color(0xFFB9BFB8),
    input: Color(0xFFFFFFFF),
    track: Color(0xFFF2F3F0),
    tooltip: Color(0xFFDFE2DE),
  );
}

/// Which appearance is active, and the switch that changes it.
///
/// **A static, not an `InheritedWidget`, and that is the whole trick.** The
/// surface stack is read through static accessors (`AppSurfaces.page`) so that
/// 148 call sites in 34 files did not have to become `Theme.of(context)`
/// lookups. A static needs somewhere to live, and this is it.
///
/// The swap is deliberately *not* reactive on its own. [apply] is called from
/// the same `setState` that rebuilds `MaterialApp`, so the tree reading these
/// accessors is rebuilt by the same gesture — a `ValueNotifier` here would be a
/// second source of truth for something `MaterialApp` already rebuilds.
class AppTheme {
  const AppTheme._();

  static Brightness _brightness = Brightness.dark;

  /// The brightness the palette is currently resolved for.
  ///
  /// **`dark` until something says otherwise, on purpose.** The first frame
  /// paints before the stored preference is read, and a light flash on launch
  /// for a user who chose dark is the more visible of the two wrong answers.
  static Brightness get brightness => _brightness;

  /// Resolves [mode] against the platform and applies it.
  static void applyMode(ThemeMode mode, Brightness platform) {
    apply(switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    });
  }

  /// Swaps the palette. See [AppSurfaces.apply].
  static void apply(Brightness brightness) {
    _brightness = brightness;
    AppSurfaces.apply(brightness);
    AppPalette.apply(brightness);
  }
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
  static BorderSide get hairline => BorderSide(
        color: AppSurfaces.border,
        width: 1,
      );

  /// The outline on a control the user can press.
  ///
  /// Same value as [hairline]: the brief has one border colour. Kept as a
  /// separate name because a tappable thing and a labelled thing are different
  /// roles, and a future revision is allowed to separate them.
  static BorderSide get control => BorderSide(
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
  static BoxBorder get hairlineBorder => Border.fromBorderSide(hairline);
  static BoxBorder get controlBorder => Border.fromBorderSide(control);
  static BoxBorder get boundaryBorder => Border.fromBorderSide(boundary);

  /// The brief's categorical recipe: a 20%-alpha wash of the hue behind a
  /// full-strength foreground of the same hue.
  ///
  /// The one sanctioned way to put a hue behind text. A hand-written
  /// `hue.withValues(alpha: 0.3)` behind a caption is the mistake that cost
  /// contrast in three previous design systems in this app.
  ///
  /// **The hue is nearly always [AppPalette.error] now.** The wash exists for a
  /// badge whose foreground is the accent, and `color_helpers_test.dart` measures
  /// the result; the function takes a parameter rather than hardcoding red
  /// because the status ramp still washes its own colour.
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
///  * **Glow** — rare, accent-only: a progress fill or a peak bar, so the accent
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

  /// The one glow in the app: `0 0 10px` at 50%.
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

  /// Tabular data in the Overview instrument panel: slot keys, values, and the
  /// hero figure.
  ///
  /// **This one is genuinely mono, and it is the only token in the app whose name
  /// now means what it says.** Every other token here was Inter, so
  /// `fontFamily: mono` was Inter and the token was a comment. The Overview
  /// panel's argument is that its rows read as instrumentation, and that is a
  /// monospaced claim: in a proportional face a column of `PV_OUT` / `SKY_LUX` /
  /// `BAT_SOC` is three different widths and looks ragged, and the underscore
  /// vocabulary that signals instrumentation stops signalling anything.
  ///
  /// Only the `slot*` and `hero*` styles below read this. Everything else — the
  /// nav bar, the settings screens, the other three tabs — stays Inter, so a
  /// stray `AppType.numeralMono` in old code still resolves to Inter and looks
  /// unchanged rather than suddenly turning monospaced in five places.
  static const String mono = 'JetBrainsMono';

  // ── Displays ─────────────────────────────────────────────────────────────────

  /// The panel's own type scale, matched to the Power page's card.
  ///
  /// **24 / 11 / 11 is `TelemetryCard`'s figure, label and unit, verbatim.** The
  /// user asked for the Overview, Environment and Fish panels to look like the
  /// Power page, and they are the same app on the same phone: Power's numbers
  /// read at 24 and the panels' at 15. "Too small" was the report, twice, and it
  /// was a difference of scale rather than a difference of taste - which is the
  /// one kind of difference a reader cannot argue with.
  ///
  /// **The mono family is the one thing that stays.** Power's card inherits
  /// `DefaultTextStyle` and lands on Inter; these five tokens are mono and
  /// `design_tokens_test.dart` pins that. Matching the *scale* is what the eye
  /// reads as "same app"; matching the typeface would erase the one thing that
  /// says a panel is instrumentation rather than a list of readings, and it
  /// would take the meters, the hero figure and the `TerminalTag` out of the
  /// comparison anyway - `TelemetryCard` has none of those, so swapping to it
  /// would be a deletion dressed as a restyle.
  ///
  /// **These five tokens are the only type in the Overview, Environment and Fish
  /// panels**, so this is one edit that moves all three together rather than
  /// three edits that could drift apart.
  ///
  /// The scale went 15/11/11 -> 18/12/12 -> 24/11/11. The middle step was me
  /// guessing at "a bit bigger"; 24 is the number that was actually on the other
  /// page, which is why it is written down here.
  ///

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

  // ── The terminal panel's own scale ───────────────────────────────────────────
  //
  // **These exist only for `terminal_panel.dart`, and none of them is a retune of
  // an existing token.** The panel's whole visual argument is that its text looks
  // like instrumentation rather than like a consumer dashboard, and that is a
  // *monospace* claim: the existing scale is Inter end to end, and Inter at 11
  // px with 0.1 em tracking reads as a small bold caption, not as a slot name.
  //
  // They are separate tokens rather than overrides for one specific reason:
  // `labelMicro` is used in about forty places, and changing it to satisfy one
  // page would change all forty. A per-page scale is the cheap way to be wrong
  // in one place instead of forty.

  /// A panel row's key: `PV_OUT`, `BAT_SOC`, `SKY_LUX`.
  ///
  /// **Monospace, tracked wide, and at 11 px rather than 10.** The underscore in
  /// the vocabulary only reads as instrumentation if the glyphs are monospaced —
  /// in a proportional face `PV_OUT` and `SKY_LUX` are different lengths and the
  /// column of keys looks ragged. JetBrains Mono also gives every key the same
  /// advance width, so a stack of them aligns without any layout work.
  static const TextStyle slotKey = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.06 * 11,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The micro variant, for the panel header's id and a meter caption.
  static const TextStyle slotMicro = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.08 * 10,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A panel row's value, right-aligned.
  ///
  /// **Weight 700 where the rest of the app's small text is 500, and that is the
  /// panel's hierarchy doing its work without colour.** A key at 500 and a value
  /// at 700 in the same monospace face is a legible contrast; two weights of 500
  /// would be a wall of grey.
  static const TextStyle slotValue = TextStyle(
    fontFamily: mono,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.01 * 15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The hero's secondary stats.
  static const TextStyle slotValueSmall = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A unit, set smaller and muted beside its figure.
  static const TextStyle slotUnit = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.1,
  );

  /// The panel's one enormous figure.
  ///
  /// **88 px, and it is the only thing in the app set this large.** The Overview
  /// has exactly one question, so it has exactly one hero — and after the caption
  /// was removed it became the page's entire opening statement, which is what
  /// "88" is for. Tabular figures are not decoration here either: this value
  /// changes digit count as the day progresses, and a proportional 88 px figure
  /// would shift the whole row under it on every poll.
  ///
  /// **It has to fit four digits.** `10000 W` is the largest the panel can draw
  /// (a 10 kW array at noon), and JetBrains Mono at 88 px is about 53 px per
  /// digit — 212 px for five, against the ~379 dp the hero's content box has on
  /// a 411 dp phone. That is the real constraint on this number, and it is why
  /// this is not 110.
  ///
  /// The tracking is `-0.03 em`, *not* the `-0.04 em` on [displayLg]. JetBrains
  /// Mono is already monospaced, so a display-tuned negative tracking that looks
  /// right on Inter visibly closes up the digits here — at 88 px that reads as
  /// kerning error rather than as tightness.
  static const TextStyle heroFigure = TextStyle(
    fontFamily: mono,
    fontSize: 88,
    fontWeight: FontWeight.w700,
    height: 0.92,
    letterSpacing: -0.03 * 88,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The hero's unit, baseline-aligned beside an 88 px figure.
  ///
  /// **20 px, up from 18** — a unit set in the same grey as every caption on the
  /// panel disappears entirely next to a figure that grew by a quarter. It is
  /// still a third the size of the number, which is the whole point of a unit.
  static const TextStyle heroUnit = TextStyle(
    fontFamily: mono,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.0,
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
/// ## One accent: red
///
/// | token         | hex       | role                                          |
/// |---------------|-----------|-----------------------------------------------|
/// | [error]       | `#FF6B6B` | **the accent**, and the breach fill           |
///
/// In a chrome, heading, label, icon or border, colour is either this red or a
/// neutral from [AppSurfaces]. There is no second accent. That is not a
/// preference: a hue the user did not choose is a hue they cannot predict, and
/// an app that spent lime on a CTA and blue on an avatar ring was showing four
/// brands at once. The instrument-panel reading is what the Overview page
/// established — `terminal_panel.dart` argues it at length — and it is now the
/// whole app.
///
/// ## The other five, and why they still exist
///
/// None of these is an accent any more. Each is retained because something
/// still reads it, and deleting a token that a call site or a test still names
/// is a separate, deliberate change — not something to do as a side effect of a
/// colour conversion.
///
/// | token          | hex       | still read by                                    |
/// |----------------|-----------|--------------------------------------------------|
/// | [primary]      | `#C6FF00` | `kChartSeriesOrder`, position 0                  |
/// | [secondary]    | `#4A9EFF` | `kChartSeriesOrder`, position 1                  |
/// | [chartViolet]  | `#C084FC` | `kChartSeriesOrder`, position 2                  |
/// | [chartCyan]    | `#22D3EE` | `kChartSeriesOrder`, position 3                  |
/// | [accent]       | `#FFB84D` | `statusWarn`, the stale/warning severity         |
/// | [success]      | `#4ADE80` | `statusOk`, "a problem is absent"                |
///
/// **A chart series is data, not decoration.** A group with more than one series
/// draws them in the fixed order above, because three lightness steps of one hue
/// are indistinguishable on a phone and dash patterns to compensate read as
/// broken lines. A group with a single series takes the accent instead, because
/// there is nothing to distinguish it from. That boundary is the only place a
/// non-red hue is allowed on screen outside the status ramp.
///
/// **The status ramp keeps its hues** for the same reason: green means a problem
/// is absent and amber means it is stale, and both always ship with the word that
/// says which. They are conditions rather than identities, which is exactly the
/// distinction the accent rule rests on.
class AppPalette {
  const AppPalette._();

  /// Swaps the active palette. See [AppSurfaces.apply].
  static void apply(Brightness brightness) {
    _active = brightness == Brightness.light
        ? AppPaletteTheme.light
        : AppPaletteTheme.dark;
  }

  static AppPaletteTheme _active = AppPaletteTheme.dark;

  static Color get error => _active.error;
  static Color get primary => _active.primary;
  static Color get secondary => _active.secondary;
  static Color get accent => _active.accent;
  static Color get statusAlert => _active.statusAlert;
  static Color get statusBad => _active.statusBad;
  static Color get success => _active.success;
  static Color get chartViolet => _active.chartViolet;
  static Color get chartCyan => _active.chartCyan;
  static Color get onHue => _active.onHue;

  /// **Deprecated: use [AppShadows].** `aura` was a blurred halo, and the brief
  /// bans blur outright. Kept as a name because a call site may still reach
  /// for it, and it now returns the one legal glow.
  static List<BoxShadow> aura(Color hue, {double strength = 0.50}) =>
      AppShadows.glow(hue, strength: strength);
}

/// One appearance's worth of the hue set.
///
/// Immutable, so that [AppPalette] can publish it through static accessors with
/// no `BuildContext` in sight — the same trick [AppSurfacesPalette] plays for
/// the surface stack.
///
/// **The hues had to become per-palette, and this is the finding of the light
/// theme.** One red cannot serve both: on the dark ramp the accent is pinned at
/// `#FF6B6B` because the AA floor against `surfaceMuted` caps how dark it may
/// go, and against a light page that same red measures **2.49:1** — under the
/// 3:1 even a graphic needs. The solver that produced the light column scales
/// every channel of each hue by one factor until it clears AA on that palette's
/// caption surfaces, which is the same rule this repo already states for caption
/// colours: scaling preserves hue and saturation exactly, where stepping in HSL
/// does not.
///
/// The accent is the one hand-picked light value — `#B3261E`, Material 3's own
/// error red, at 5.72 / 6.53 / 4.73 — because the solver's `#A34444` is a
/// maroon and the accent is the one hue that has to still read as red.
class AppPaletteTheme {
  const AppPaletteTheme({
    required this.error,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.statusAlert,
    required this.statusBad,
    required this.success,
    required this.chartViolet,
    required this.chartCyan,
    required this.onHue,
  });

  /// **The accent.** Red, and the only colour the app spends on chrome.
  ///
  /// It is not a claim that something is wrong — `terminal_panel.dart` states
  /// that deliberately, and the panel's hero figure, its section headings and
  /// its meter fills are all this value on a day when every reading is nominal.
  final Color error;

  /// **No longer an accent.** Acid lime. Retained for the chart-series order and
  /// the PV category; a call site that reaches for it as decoration is the bug
  /// this doc exists to prevent.
  final Color primary;

  /// **No longer an accent.** Blue. Retained for the chart-series order and the
  /// AC category; see [primary].
  final Color secondary;

  /// Amber. The stale/warning severity. **A condition, not an identity** — it
  /// only appears beside the word that says what is stale.
  final Color accent;

  /// An alert: serious, not yet a breach.
  ///
  /// **The one hue that is not in the brief's palette**, because the brief has
  /// two semantic hues and the app has four severities. Collapsing alert into
  /// `error` would have been the alternative and it loses information the alarm
  /// history actually carries.
  final Color statusAlert;

  /// A breach, as **ink**.
  ///
  /// **Derived by scaling every channel of `#EF4444` by 1.35** — see
  /// `color_helpers.dart` for the measurement that chose the factor, and for
  /// why scaling preserves hue where stepping HSL does not.
  final Color statusBad;

  /// Green. A healthy reading. **A condition, not an identity** — it is
  /// `statusOk` and nothing else, and it is never a page's own colour.
  final Color success;

  /// Violet. Retained for the chart-series order and the battery category; see
  /// [primary].
  ///
  /// **The brief's `#A855F7` scaled up 1.28x per channel, and the direction is
  /// the whole point.** The obvious fix for a colour that fails contrast on a
  /// dark surface is to darken it, and that takes it further from white. Scaled
  /// rather than stepped in HSL, so the hue is preserved exactly.
  final Color chartViolet;

  /// Cyan. Retained for the chart-series order and the water category; see
  /// [primary].
  final Color chartCyan;

  /// Ink on a saturated fill. The brief's `on-primary`.
  ///
  /// **Dark in dark mode and white in light, and the flip is the point.**
  /// On the dark ramp the fills are bright, so this is black and white would
  /// measure 2.78:1 on the accent — under AA by 1.6x. On the light ramp the
  /// fills are dark, so it is white and black would fail by the same factor.
  /// Both the primary button (`banners.dart`) and the selected date chip
  /// (`liquid_glass.dart`) reach for this token rather than
  /// `AppSurfaces.onSurface`, and that is only defensible while the ratio holds
  /// in the palette that is active.
  ///
  /// The name is misleading — `onHue` was written for lime, where black reads
  /// 14:1 — but what it has always meant is *the ink that clears AA on this
  /// palette's fills*, and that is a rule rather than a leftover.
  ///
  /// `color_helpers.dart`'s `onPrimaryInk` derives the same answer from the
  /// fill's measured luminance instead of from its palette, and
  /// `accent_graphic_contrast_test.dart` holds that function to 4.5:1 for every
  /// fill. Use this token when the fill is a known constant; use `onPrimaryInk`
  /// when a caller supplies the fill.
  final Color onHue;

  /// The hues as shipped: bright, for ink on a near-black page.
  ///
  /// Every one of these is unchanged from the single-palette app, and that is
  /// deliberate — the dark ramp is the one the values were originally solved
  /// for.
  static const AppPaletteTheme dark = AppPaletteTheme(
    error: Color(0xFFFF6B6B),
    primary: Color(0xFFC6FF00),
    secondary: Color(0xFF4A9EFF),
    accent: Color(0xFFFFB84D),
    statusAlert: Color(0xFFFB923C),
    statusBad: Color(0xFFFF5C5C),
    success: Color(0xFF4ADE80),
    chartViolet: Color(0xFFC084FC),
    chartCyan: Color(0xFF22D3EE),
    onHue: Color(0xFF000000),
  );

  /// The same hues, each scaled by one factor per channel until it clears AA on
  /// the light caption surfaces. See the class doc for the derivation.
  ///
  /// **`onHue` inverts to white**, because every fill here is dark rather than
  /// bright. That is the whole reason these are two sets and not one.
  static const AppPaletteTheme light = AppPaletteTheme(
    error: Color(0xFFB3261E),
    primary: Color(0xFF536B00),
    secondary: Color(0xFF2F65A3),
    accent: Color(0xFF805C27),
    statusAlert: Color(0xFF925523),
    statusBad: Color(0xFFAD3F3F),
    success: Color(0xFF256F40),
    chartViolet: Color(0xFF77529C),
    chartCyan: Color(0xFF126E7C),
    onHue: Color(0xFFFFFFFF),
  );
}
