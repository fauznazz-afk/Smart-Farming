import 'package:flutter/material.dart';

/// The complete appearance presets the user can pick between.
///
/// **This is a preset, not a brightness, and that is the whole design of it.**
/// The first two entries are a brightness plus whatever accent the user chose in
/// Settings. [dracula] is a brightness *and* an accent, because that is what
/// people mean by "Dracula": VS Code's Dracula is one palette, and a Dracula
/// that left the existing accent swatch in place would not be Dracula at all —
/// it would be the app's dark theme with a purple page, and the two halves
/// would fight. So while [dracula] is active the other accent choices do not
/// apply, and [usesPresetAccent] is how a caller finds that out without
/// hard-coding a comparison.
///
/// [AppTheme] replaced a `bool isDark` in every surface and elevation accessor,
/// and that is the one change in this enum that is not a preference. A boolean
/// cannot express "dark *and* purple": it can only say which half of the
/// existing light/dark pair to take, so the moment a third mode existed the
/// signature had nowhere to put it. The replacement happened before the call
/// sites were migrated, on purpose — a temporary bool-plus-flag signature is
/// the thing that gets shipped and then never removed, because by the time the
/// third mode is switched on by users the workaround looks load-bearing.
enum AppTheme {
  light,
  dark,
  dracula,
  skeuo;

  const AppTheme();

  /// Whether this theme paints with the dark text palette.
  ///
  /// This is the answer to the question `faintColor` and the four status
  /// colours are still asked, and it is `true` for **both** dark presets, not
  /// just for [dark]. That is a measured fact rather than a convenience: the
  /// app's existing dark text palette clears AA on Dracula's page unchanged —
  /// on `#282A36` the faint colour measures 6.58:1, `statusOk` 7.83, `statusWarn`
  /// 9.43, `statusBad` 6.24 and `statusAlert` 7.72, worst case 5.17:1 on the
  /// chrome step. So a Dracula variant of that palette would be five more
  /// constants protecting nothing, and the next reader would have no way to tell
  /// which ones were load-bearing.
  bool get isDark => this != AppTheme.light;

  Brightness get brightness => isDark ? Brightness.dark : Brightness.light;

  /// Whether this theme brings its own accent, ignoring the seed in Settings.
  ///
  /// Deliberately a question rather than a value. The accent itself lives in
  /// `color_helpers.dart` next to the contrast measurements that justify it;
  /// putting a `Color` on the enum would make this file own a colour decision
  /// that the AA test in `test/color_helpers_test.dart` is what actually checks.
  ///
  /// [skeuo] is here for the same reason as [dracula]: it is a *specified*
  /// palette with its own two accents rather than a hue the user picked in
  /// Settings, and letting the seed override it would produce a fourth theme
  /// that is not the one anybody asked for.
  bool get usesPresetAccent =>
      this == AppTheme.dracula || this == AppTheme.skeuo;
}

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

  /// Dracula's background, `#282A36`.
  ///
  /// **Dracula is a third dark preset, not a variant of [pageDark], and the two
  /// are only 1.7 stops apart at most.** It sits at relative luminance 0.0237
  /// against the app's dark page's 0.0141 — about 1.7x lighter, and materially
  /// lighter than it sounds, which is the reason [AppElevation] carries a
  /// separate Dracula set rather than reusing the dark one. See the note on
  /// [AppElevation.raised] for the alphas and the measurement behind them.
  static const Color pageDracula = Color(0xFF282A36);

  /// Chrome that sits above the page and must separate from it by fill rather
  /// than by shadow: the bottom navigation pill, the app bar scrim.
  ///
  /// One step off the page colour. These are the two surfaces where a
  /// dual-shadow pair would fight the scrim behind them.
  static const Color chromeLight = Color(0xFFE9EEEB);
  static const Color chromeDark = Color(0xFF232B28);

  /// Dracula's selection/hover step, `#343746` — officially "current line", and
  /// used here for the same job: the one surface that must separate from the
  /// page by fill rather than by shadow.
  ///
  /// It is the **lightest** surface in the Dracula ramp, at relative luminance
  /// 0.0390 against the page's 0.0237, which is why it is also the binding
  /// surface for every text measurement in this theme: anything that clears AA
  /// here clears it on all four others. The app's own dark palette is worst on
  /// exactly this one at 5.17:1 for `statusBad`.
  static const Color chromeDracula = Color(0xFF343746);

  // ── Skeuo ─────────────────────────────────────────────────────────────────
  //
  // **The one theme in the app that came from a specification rather than from
  // measurement.** Its page is the design brief's `background #0A0A0C` and its
  // chrome is its `surface #38383C`, with amber `primary #F59E0B` and lime
  // `accent #C4F042` living in `color_helpers.dart`. Everything below is a
  // *ramp step*, and none of the values are the brief's: `#0A0A0C` is nearly
  // black and the system needs five distinguishable levels between the page
  // and a track, which a brief with two neutrals does not have.
  //
  // **The card fill is the page fill, as everywhere else.** The brief's `surface
  // #38383C` becomes `chrome` rather than the card, because
  // `design_tokens_test.dart` pins "the card fill is still exactly the page
  // colour" and that invariant is what makes depth readable as shadow rather
  // than as a second flat colour. The brief's own value is therefore kept, one
  // level up the stack, instead of being spread across every surface.
  static const Color pageSkeuo = Color(0xFF0A0A0C);
  static const Color cardSkeuo = Color(0xFF0A0A0C);
  static const Color chromeSkeuo = Color(0xFF38383C);
  static const Color inputSkeuo = Color(0xFF141416);
  static const Color trackSkeuo = Color(0xFF1E1E22);
  static const Color tooltipSkeuo = Color(0xFF38383C);

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

  /// Dracula's input fill, `#21222C` — darker than the page, which is the
  /// *opposite* of what the light and dark inputs do.
  ///
  /// The reason those two are lighter than their page is documented on
  /// [inputLight]: a darker field would have dropped `faintColor` and four
  /// status colours below AA in light mode, and in dark mode the same
  /// measurement put the input at a step *below* the page so the inner shadow
  /// had something to bite into. Dracula has room to do it the conventional way
  /// because its own palette is built the conventional way: `#21222C` is
  /// Dracula's documented input background, and it measures 0.0165 against the
  /// page's 0.0237. Every colour in the app's dark text palette does *better*
  /// here than on the page — `faintColor` 7.30:1 rather than 6.58 — so the
  /// conventional direction costs nothing here, which is exactly the thing that
  /// was not true in either existing mode.
  static const Color inputDracula = Color(0xFF21222C);

  /// Bars that show a quantity rather than a container: the power-flow split
  /// bar, the state-of-charge track, the energy forecast progress bar.
  static const Color trackLight = Color(0xFFCFD6D2);
  static const Color trackDark = Color(0xFF131A18);

  /// Dracula's track, `#1E1F29`, the darkest surface in the ramp at relative
  /// luminance 0.0142 — just under the app's own dark track's 0.0077 by a wide
  /// margin, which is the point.
  ///
  /// The light track is the worst surface in the app for text: all five
  /// captions that carry [faintColor] and the four status colours measure
  /// 3.85 to 3.87:1 on it, which is five AA failures, and the resolution was
  /// *not* to darken the colours to suit a bar that has no text on it. Dracula's
  /// track has the same problem in reverse — it is the surface furthest from
  /// white, so it is the most forgiving one — and it is measured here for the
  /// same reason, so that the day someone puts a caption on a track the numbers
  /// are already known.
  static const Color trackDracula = Color(0xFF1E1F29);

  /// The chart tooltip, which is opaque because it must stay readable over an
  /// arbitrary series crossing underneath it.
  static const Color tooltipLight = Color(0xFFEDF1EF);
  static const Color tooltipDark = Color(0xFF262E2B);

  /// The Dracula tooltip, `#343746` — the same value as [chromeDracula], and on
  /// purpose rather than by omission.
  ///
  /// Dracula has no separate "raised overlay" colour, and inventing one is
  /// exactly the mistake documented on [trackLight]: a new token added to make
  /// a value look deliberate, with a contrast obligation attached that nobody
  /// measured. Reusing the chrome step means the tooltip is the same surface
  /// the nav pill is, which is a thing a reader can check, and it is the
  /// lightest surface in the theme, so a caption over it is the worst case
  /// anywhere in Dracula — 5.17:1 for `statusBad`.
  static const Color tooltipDracula = Color(0xFF343746);

  /// The page fill for the surfaces the chart is drawn on. Deliberately the page
  /// colour and nothing else, so grid lines are the only thing between the
  /// series and the background.
  static Color page(AppTheme theme) => switch (theme) {
    AppTheme.light => pageLight,
    AppTheme.dark => pageDark,
    AppTheme.dracula => pageDracula,
    AppTheme.skeuo => pageSkeuo,
  };

  static Color card(AppTheme theme) => page(theme);

  static Color chrome(AppTheme theme) => switch (theme) {
    AppTheme.light => chromeLight,
    AppTheme.dark => chromeDark,
    AppTheme.dracula => chromeDracula,
    AppTheme.skeuo => chromeSkeuo,
  };

  static Color input(AppTheme theme) => switch (theme) {
    AppTheme.light => inputLight,
    AppTheme.dark => inputDark,
    AppTheme.dracula => inputDracula,
    AppTheme.skeuo => inputSkeuo,
  };

  static Color track(AppTheme theme) => switch (theme) {
    AppTheme.light => trackLight,
    AppTheme.dark => trackDark,
    AppTheme.dracula => trackDracula,
    AppTheme.skeuo => trackSkeuo,
  };

  static Color tooltip(AppTheme theme) => switch (theme) {
    AppTheme.light => tooltipLight,
    AppTheme.dark => tooltipDark,
    AppTheme.dracula => tooltipDracula,
    AppTheme.skeuo => tooltipSkeuo,
  };

  /// Every surface the app paints a caption or a status colour on, for one
  /// theme, in the order a reader should check them.
  ///
  /// **This is derived, and it is the point.** `test/color_helpers_test.dart`
  /// measures WCAG AA against a list of surfaces, and that list used to be
  /// hand-written hex values, which then went stale twice — silently, and in
  /// opposite directions, so the test stayed green while three captions were
  /// below AA on the page that was actually rendering. A literal in a test that
  /// is meant to describe the app's own tokens is a copy, and copies drift.
  ///
  /// The track is deliberately **absent**, and that exclusion is scoped to the
  /// progress bars rather than to the token: an `AppTile` used to share it and
  /// every colour failed on it at 3.85 to 3.87:1, so the tile now paints
  /// [input] and the bars keep [track]. See the note on [trackDracula].
  static List<Color> captionSurfaces(AppTheme theme) => [
    page(theme), // page + card, which are the same colour
    chrome(theme), // nav pill, app bar scrim
    input(theme), // input fields, and the fill AppTile paints
    tooltip(theme), // chart tooltip
    if (theme == AppTheme.light) const Color(0xFFFFFFFF), // Material surfaces
  ];
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
///
/// **All four pairs take an [AppTheme] and Dracula has its own set of each.**
/// The reason is a measurement, and it is the same shape as the light-versus-dark
/// note on [raised] below: Dracula's page is lighter than the app's dark page,
/// so the same alpha produces a *larger absolute* luminance step and the
/// shadow stops reading as depth and starts reading as a dark halo. The
/// derivation and the two rules it has to satisfy are written out at length on
/// [raised]; the other three pairs are solved the same way and their answers
/// are on each one. What is **not** re-derived per pair is the geometry — the
/// offsets, the blur radii and which way each shadow points are shared verbatim
/// with the dark set, because those are what encode the light source and there
/// is no measurement that would justify a Dracula card that catches its light
/// from somewhere else.
/// **Measured on the device, and the first derivation was wrong by 1.9x.**
///
/// Dracula's alphas were originally solved so that each shadow's *nominal*
/// composited ΔLuminance on `#282A36` equals the ΔL the same shadow makes on the
/// dark page. That is a statement about arithmetic, and it was true as stated.
/// It did not survive contact with a screen.
///
/// Measured on the Xiaomi, same build, same card, right-hand edge, by scanline:
///
/// | | page | contact | measured ΔL |
/// |---|---|---|---|
/// | dark (`#1A211F`) | 31.4 | 15.5 | **15.9** |
/// | dracula (`#282A36`) | 42.4 | 34.2 | **8.2** |
///
/// So Dracula was delivering **52%** of the dark theme's drop, while the token
/// file claimed parity. The cause is that the alphas were solved against the
/// *composited* value and the blur then ate a different fraction of each: 28% on
/// the dark page, 38% on Dracula's, because a given mask-blur removes more of a
/// shadow's peak on a lighter background where the contrast it is being measured
/// against is smaller.
///
/// **The correction is a uniform 1.9x on every Dracula alpha**, which preserves
/// the light-to-dark ratio the original derivation was trying to hold and is the
/// only shape that can be applied to fourteen numbers without re-deriving each.
/// Contact `0x50` → `0x98`, ambient `0x42` → `0x7E`, and the inset, insetDeep and
/// pressed pairs by the same factor.
///
/// This is the check `FEATURE.md` §18.5 has asked for since it was written --
/// "elements really draw: measure pixel brightness in a screenshot" -- applied for
/// the first time to a token set that was derived rather than eyeballed. It took
/// one measurement to invalidate it, which is the argument for doing the
/// measurement.
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
  ///
  /// ── Dracula, and why it needs its own alphas ─────────────────────────────────
  ///
  /// Dracula's page `#282A36` is at relative luminance **0.0237** against the
  /// app's dark page `#1A211F` at **0.0141**. That is 1.7x lighter, and it is
  /// the reason this third mode cannot borrow the dark set. The trap is the
  /// intuitive measure: at the *same* alpha, black over Dracula drops
  /// proportionally *more* than it does over the app's dark page (83.4% against
  /// 79.7% at `0xB3`), which looks like the dark alphas being about right.
  ///
  /// ── Dracula, measured rather than solved ─────────────────────────────────────
  ///
  /// Dracula's page `#282A36` is at relative luminance **0.0237** against the
  /// app's dark page `#1A211F` at **0.0141** — 1.7x lighter — which is why it
  /// cannot simply borrow the dark alphas.
  ///
  /// **The first derivation of this set was wrong, and a scanline is what proved
  /// it.** It solved every shadow for an equal *composited* absolute luminance
  /// step on the two pages, which is a claim about `Color.lerp` and not about the
  /// screen: the mask blur removes a different fraction of each page's shadow, so
  /// the arithmetic was true and the pixels were not. `test/design_tokens_test.dart`
  /// asserted that equality to within 0.0007 and passed. The cards read flat.
  ///
  /// Measured on the Xiaomi, same build, same card, right-hand edge, 8-bit
  /// luminance scanline:
  ///
  /// | | page | contact | measured ΔL | as a fraction of the page |
  /// |---|---|---|---|---|
  /// | dark (`#1A211F`) | 31.4 | 15.5 | **15.9** | 51% |
  /// | dracula, solved (`0x50`) | 42.4 | 34.2 | **8.2** | 19% |
  ///
  /// Fifty-two percent of the dark theme's drop, while the composited steps agreed
  /// to within 0.0007. That is the whole argument for measuring: nothing in the
  /// source, the analysis or the suite could see it.
  ///
  /// **The correction is two measured data points, not a solve.** The relationship
  /// between alpha and *measured* ΔL is strongly convex — the blur eats most of a
  /// weak shadow's peak and little of a strong one's, so the same fractional
  /// increase in alpha buys far more ΔL when it starts from a low base:
  ///
  /// | contact alpha | measured ΔL |
  /// |---|---|
  /// | `0x50` | 8.2 |
  /// | `0x8C` | **20.0** |
  /// | `0x98` | 21.3 |
  ///
  /// A uniform 1.9x from `0x50` overshot to `0x98` and read *heavier* than the
  /// dark theme. `0x8C` is the interpolated landing, and 20.0 against the dark
  /// page's 15.9 is the right answer rather than a near miss: once the page
  /// luminance differs, the honest comparison is the fraction, and 20.0 is 47% of
  /// Dracula's page against dark's 51% of its own. Near parity, slightly softer.
  ///
  /// **Only the dark halves were corrected**, and that is deliberate rather than
  /// an oversight. Every alpha `0x??000000` across `raised`, `inset`, `insetDeep`
  /// and `pressed` moved; every alpha `0x??FFFFFF` is still the value the original
  /// solve produced. The dark half is the one that was measured and the one that
  /// was failing — a weak shadow on a lighter page is what flattened the cards —
  /// so it is the only one there is evidence to move. Scaling the light halves by
  /// the same factor on the strength of a number borrowed from the other half
  /// would repeat exactly the mistake this note exists to record: an arithmetic
  /// relationship standing in for a pixel that was never sampled.
  ///
  /// The visible consequence is that the light-to-dark relationship has inverted.
  /// On the dark theme the light half is what defines the edge, by a ratio of
  /// 3.80; on Dracula the corrected dark half now does most of the work, and the
  /// pair measures 2.41. `design_tokens_test.dart` asserts that as a band rather
  /// than the 3.80 it used to assert, and records there that the band is a real
  /// loss of precision bought on purpose.
  ///
  /// **What is still unmeasured is the light half.** A scanline across the *top*
  /// edge of a card would say whether the bounce needs the same treatment, and it
  /// has not been taken. What is claimed now is only what the scanline showed: the
  /// dark half of Dracula's contact shadow lands at 47% of its page against the
  /// dark theme's 51%, and the cards read as raised rather than flat.
  ///
  /// What is now claimed is measured. The scanline `FEATURE.md` §18.5 had asked
  /// for has been run, on this theme and on the dark one for comparison, on the
  /// same build and the same card.
  static List<BoxShadow> raised(AppTheme theme) => switch (theme) {
    AppTheme.skeuo => const [
        // **Skeuo's own pair, and it is not the dark theme's.**
        //
        // `pageSkeuo` is `#0A0A0C` — darker than the dark theme's `#1A211F` by
        // more than either is from white. A black shadow on a near-black page
        // is a small relative move, so the two dark halves are pulled *back*
        // rather than up, and the light bounce carries the edge instead. That
        // is the same inversion the notes record for Dracula, arrived at by a
        // different route: here it is not that only one half was measured, it
        // is that on this page the dark half cannot do the work.
        //
        // **Not measured on a device.** Stated as a first derivation from the
        // page luminance, which is the weakest thing in this file and is why
        // every number here is a guess a scanline would replace.
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 6,
          offset: Offset(3, 3),
        ),
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 22,
          offset: Offset(9, 9),
        ),
        // The bounce, strengthened well past the dark theme's 0x29: on a page
        // this dark the top-left highlight is the only edge a card has.
        BoxShadow(
          color: Color(0x3DFFFFFF),
          blurRadius: 14,
          offset: Offset(-6, -6),
        ),
      ],
    AppTheme.dracula => const [
        // contact -- measured, not solved: ΔL 20.0 against a page of 42.4, which
        // is 47% where the dark theme's 0xB3 reaches 51% of its own page.
        BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 6,
          offset: Offset(3, 3),
        ),
        // ambient -- same correction, same factor.
        BoxShadow(
          color: Color(0x71000000),
          blurRadius: 22,
          offset: Offset(9, 9),
        ),
        // bounce, up and to the left -- NOT corrected, because it was not
        // measured. Still the alpha the original solve produced. Composites to
        // #474953, just under Dracula's current-line #44475A.
        BoxShadow(
          color: Color(0x25FFFFFF),
          blurRadius: 14,
          offset: Offset(-6, -6),
        ),
      ],
    AppTheme.dark => const [
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
      ],
    AppTheme.light => const [
        // contact -- measured and reduced: right-edge scanline on Xiaomi
        // (build 1.8.0, 1220×2712, density 520, 23_dash_fresh.png) at y=1000,
        // card right edge ≈ x1137. Peak L=175.6 at d≈7px against page L=228.8.
        // ΔL = 53.2 (23% of page). Dark theme reference ΔL = 15.9 (51% of its page).
        // Targeting ~16-20 ΔL via interpolation, same method as the Dracula fix.
        // Convexity: alpha→ΔL is convex (blur eats weak peaks more). Scaling 1.9x
        // on Dracula overshot 2.6x; here we scale down by ~0.45 and must re-measure.
        // Original 0x66 (102/255 = 0.400) → 0x2E (46/255 = 0.180).
        BoxShadow(
          color: Color(0x2E3D4A44),
          blurRadius: 6,
          offset: Offset(3, 3),
        ),
        // ambient -- same factor as contact. Original 0x40 (64/255 = 0.251) → 0x1D (29/255 = 0.114).
        BoxShadow(
          color: Color(0x1D3D4A44),
          blurRadius: 22,
          offset: Offset(9, 9),
        ),
        // bounce, up and to the left -- NOT changed. The bounce was not measured
        // (no top-edge scanline exists). The rule this file exists to enforce:
        // correct only the half you measured. Scaling the light half by a number
        // borrowed from the dark half is the mistake the Dracula patch records.
        // Original 0xFFFFFFFF (1.0) kept.
        BoxShadow(
          color: Color(0xFFFFFFFF),
          blurRadius: 14,
          offset: Offset(-6, -6),
        ),
      ],
  };

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
  static List<BoxShadow> inset(AppTheme theme) => switch (theme) {
    AppTheme.skeuo => const [
        // Inverted for the same reason as `raised`: on `#0A0A0C` the light half
        // does the work. Unmeasured, like its raised pair.
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 6,
          offset: Offset(2, 2),
        ),
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 14,
          offset: Offset(5, 5),
        ),
        BoxShadow(
          color: Color(0x2EFFFFFF),
          blurRadius: 12,
          offset: Offset(-4, -4),
        ),
      ],
    AppTheme.dracula => const [
        // contact: -0.0112, the same target as the raised contact. Composites
        // to #1C1D25.
        BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 4,
          offset: Offset(2, 2),
        ),
        // ambient: -0.0083, the step 0x73 makes on #1A211F. Composites to
        // #1F212A.
        BoxShadow(
          color: Color(0x62000000),
          blurRadius: 10,
          offset: Offset(5, 5),
        ),
        // bounce: +0.0291, the step 0x1F makes. Composites to #3F414B, below
        // the raised bounce's #474953, which is right -- a well is a smaller
        // feature than a block standing on the page.
        BoxShadow(
          color: Color(0x1BFFFFFF),
          blurRadius: 8,
          offset: Offset(-4, -4),
        ),
      ],
    AppTheme.dark => const [
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
      ],
    AppTheme.light => const [
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
      ],
  };

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
  static List<BoxShadow> insetDeep(AppTheme theme) => switch (theme) {
    AppTheme.skeuo => const [
        // Unmeasured, like the rest of skeuo's ramp.
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 7,
          offset: Offset(3, 3),
        ),
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 18,
          offset: Offset(8, 8),
        ),
        BoxShadow(
          color: Color(0x24FFFFFF),
          blurRadius: 10,
          offset: Offset(-3, -3),
        ),
      ],
    AppTheme.dracula => const [
        // contact: -0.0126, the step 0xD9 makes on #1A211F. Composites to
        // #1A1B22, and it is the deepest anything in this theme is allowed to
        // go -- a well pushed this far should look like it is cut into the
        // page, not like it is a hole through it.
        BoxShadow(
          color: Color(0xA0000000),
          blurRadius: 3,
          offset: Offset(1, 1),
        ),
        // ambient: -0.0096, the same target as the raised ambient and
        // deliberately identical to it, so pressing a well deeper lengthens its
        // reach without changing how far the lip itself bites. Composites to
        // #1E1F28.
        BoxShadow(
          color: Color(0x71000000),
          blurRadius: 14,
          offset: Offset(7, 7),
        ),
        // bounce: +0.0166, the step 0x14 makes. Composites to #373844, which is
        // only just above the chrome step and reads as a lip rather than as a
        // second light source.
        BoxShadow(
          color: Color(0x11FFFFFF),
          blurRadius: 6,
          offset: Offset(-3, -3),
        ),
      ],
    AppTheme.dark => const [
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
      ],
    AppTheme.light => const [
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
      ],
  };

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
  static List<BoxShadow> pressed(AppTheme theme) => switch (theme) {
    AppTheme.skeuo => const [
        // A pressed block flattens into the page, so the light half retreats
        // here rather than the dark half advancing. Unmeasured.
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 4,
          offset: Offset(1, 1),
        ),
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 10,
          offset: Offset(3, 3),
        ),
        BoxShadow(
          color: Color(0x1FFFFFFF),
          blurRadius: 8,
          offset: Offset(-2, -2),
        ),
      ],
    AppTheme.dracula => const [
        // -0.0083, the step 0x73 makes, and the same value as the inset ambient
        // for the same reason: a press is a smaller event than a well going
        // deep. Composites to #1F212A.
        BoxShadow(
          color: Color(0x62000000),
          blurRadius: 3,
          offset: Offset(1, 1),
        ),
        // +0.0291, the step 0x1F makes. Composites to #3F414B.
        BoxShadow(
          color: Color(0x1BFFFFFF),
          blurRadius: 6,
          offset: Offset(-2, -2),
        ),
      ],
    AppTheme.dark => const [
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
      ],
    AppTheme.light => const [
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
      ],
  };

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
  /// So the hairline is now a neutral, aligned with the light source: it
  /// reinforces the top-left lip rather than framing the card. [accent] is kept
  /// in the signature so a call site that genuinely needs a themed edge can
  /// still ask for one via [controlEdge] — but no card does.
  ///
  /// **The dark alphas were cut from `0x14` to `0x0A` on 1 October 2026, because
  /// the scanline showed this line was the loudest thing on the card edge.**
  ///
  /// Measured on the Xiaomi, one card, one build, 8-bit luminance scanline:
  ///
  /// | | page | bounce peak | **hairline** | as a fraction of the page |
  /// |---|---|---|---|---|
  /// | light `#E1E7E4` | 229.5 | — | 244.5 (+15.0) | **+6.5 %** |
  /// | dark `#1A211F` | 31.4 | 51.6 (+20.2) | 48.7 (+17.3) | **+55 %** |
  /// | dracula `#282A36` | 42.4 | 58.4 (+16.0) | 59.4 (+17.0) | **+40 %** |
  ///
  /// The previous doc comment here claimed the dark hairline was "a whisper, not
  /// an outline", and the measurement contradicted it in the one way that
  /// matters: **on Dracula the hairline was brighter than the bounce.** 59.4
  /// against 58.4. On both dark pages it was the brightest element within two
  /// pixels of the card's edge, which means the eye reads a one-pixel outline
  /// rather than an embossed surface — and a drawn edge is precisely the thing
  /// this style exists to replace. That is not a subtlety; it is the same defect
  /// the accent-tinted hairline caused, one step further down the alpha scale,
  /// and it survived because nobody had ever put a ruler on it.
  ///
  /// **Why the same alpha reads so differently per theme.** `0x14` is white at
  /// 8 % over the page. White has 255 of headroom above every page in the app,
  /// but a page at 229.5 can only be lifted 25.5 units by going to pure white,
  /// while a page at 31.4 has 223.6. So one alpha yields +6.5 % on light and
  /// +55 % on dark. An alpha is not a perceptual quantity; the gap between the
  /// page and white is, and that gap differs by a factor of nine across the
  /// three presets. This is the same lesson as the Dracula shadow alphas in
  /// [AppElevation], arrived at from the other direction: **a constant in the
  /// token file is a claim about arithmetic, and the three pages do not share
  /// the arithmetic.**
  ///
  /// `0x0A` puts the dark hairline at roughly +8.7 on both dark pages — 28 % and
  /// 20 % of their page against the bounce's 64 % and 38 %, so the bounce is
  /// unambiguously the brightest thing on the light edge, which is what a dark
  /// surface is supposed to look like. Light is left at `0x99` because it is
  /// already doing that job.
  ///
  /// What the line still buys, on every theme, is the measurable edge a
  /// low-vision user has: the card fill is identical to the page fill, so without
  /// it the two have 1:1 contrast in fill terms. It is weaker on dark now, and
  /// the shadow halo is what carries the boundary there.
  static Color hairline({required Color accent, required AppTheme theme}) =>
      theme.isDark ? const Color(0x0AFFFFFF) : const Color(0x99FFFFFF);

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
  ///
  /// **Dracula uses the same 0.55, and here it is genuinely the best of the
  /// three rather than merely acceptable.** The measured light case above
  /// 2.70:1 is a *ceiling* the accent can never clear; Dracula's purple is
  /// 5.90:1 on its page at full opacity, so the same 0.55 alpha lands at
  /// **2.82:1** on the page and 2.54:1 on chrome. That is still short of 3:1 —
  /// the argument above is about the accent being too dark, not about the alpha
  /// — but a Dracula control is the only one in the app whose tinted edge
  /// comes within 0.18 of the requirement, and raising the alpha to 0.60 would
  /// put it *over* 3:1 on the page (3.08) while still failing on chrome. There
  /// is no single alpha that satisfies both surfaces, so it stays at the dark
  /// value rather than growing a theme-specific one.
  static Color controlEdge({required Color accent, required AppTheme theme}) =>
      accent.withValues(alpha: theme.isDark ? 0.55 : 0.45);

  /// A neutral edge that clears WCAG 1.4.11's 3:1 for a UI component boundary
  /// on the light page.
  ///
  /// Reserved for the two places where the control has no other affordance: the
  /// CCTV info bar, which sits over video, and the standby play button, which
  /// sits over a dimmed frame. Both were at 1.14:1 and 1.35:1 before.
  ///
  /// **Dracula reuses the dark alpha unchanged, and the reason is that this
  /// colour is not actually measured against the page.** It is drawn over
  /// camera frames, so the page luminance only decides how loud it is when the
  /// video is dark. For the record that is +0.1037 of step on `#282A36` against
  /// +0.0927 on `#1A211F`, 12% stronger, which is well inside the range a
  /// 0.45-alpha white has to span to be visible over arbitrary video.
  static Color boundaryEdge({required AppTheme theme}) => theme.isDark
      ? Colors.white.withValues(alpha: 0.45)
      : const Color(0xFF3D4A44).withValues(alpha: 0.60);
}

/// A divider, on the same theme-ramp rule as everything else.
///
/// Dracula uses the dark white, for the same measurement as [AppElevation.hairline]
/// and not for the same reason: a divider carries a caller-supplied opacity on
/// top of this one, and at every opacity the app actually passes — 0.06 to 0.50
/// — a white at a given alpha is a slightly larger absolute step on Dracula's
/// lighter page than on `#1A211F`. Again the error is in the harmless
/// direction, and the light value has to stay the dark neutral because a black
/// divider at 0.10 on a page this dark is invisible.
Color appDivider({required AppTheme theme, double opacity = 0.10}) =>
    theme.isDark
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

/// The skeuomorphic layer: gradient fills, bevelled edges and a gloss band.
///
/// **Added on 7 October 2026, on top of the soft-UI system rather than instead
/// of it.** The user asked for the whole app to read as skeuomorphic. A first
/// attempt rewrote the surface tokens wholesale and was reverted: it moved the
/// light page to near-white `#F5F5F4`, which the notes above name as the one
/// value not to brighten, and it failed three contrast guarantees in
/// `color_helpers_test.dart` and three guards in `design_tokens_test.dart`.
/// Skeuomorphism is a matter of *material* — light falling across a surface,
/// a chamfered edge, a reflection — and none of that needs the surfaces
/// themselves to move. So the tokens stay, and this class decorates them.
///
/// **One rule makes the whole layer contrast-safe, and every method here
/// enforces it: a fill may only move *away* from the colour drawn on it.**
/// "Depth belongs in the shadow, never in the fill" was written because a
/// gradient that darkens a light card darkens the background of its caption,
/// and `faintColor` has roughly 0.05 of headroom over AA. The constraint is not
/// on gradients; it is on their *direction*. Lightening behind dark text, or
/// darkening behind light text, can only raise the ratio.
///
/// The consequence is the useful part: the token itself is always the stop
/// closest to the text, so it is the worst case, and the worst case is exactly
/// the value `color_helpers_test.dart` already measures. Nothing about the
/// existing contrast proofs changes. `skeuomorphic_test.dart` pins the rule.
///
/// The light still comes from the top left, like every shadow in the app. On a
/// light theme that reads as a lit top edge fading to the token; on a dark
/// theme as the token at the top falling off into shade at the bottom. Both
/// are a surface lit from above, which is the only claim a gradient makes.
class AppSkeuo {
  const AppSkeuo._();

  /// How far a surface's fill travels from its token. Small on purpose: past
  /// roughly 8% a gradient stops reading as light and starts reading as a
  /// second colour.
  static const double fillTravel = 0.06;

  /// The stronger travel used by controls that are *meant* to look pressable —
  /// a selected chip, a primary button. Same direction rule.
  static const double controlTravel = 0.12;

  /// Whether [foreground] is the darker of the pair, which decides the
  /// direction every method here moves in.
  static bool foregroundIsDarker(Color base, Color foreground) =>
      foreground.computeLuminance() < base.computeLuminance();

  /// A top-to-bottom fill for a surface whose text is [foreground].
  ///
  /// Returns two stops, one of which is always exactly [base]. Dark text gets a
  /// lightened top; light text gets a darkened bottom. See the class note for
  /// why that is what keeps AA intact.
  static List<Color> fill(
    Color base, {
    required Color foreground,
    double travel = fillTravel,
  }) {
    if (foregroundIsDarker(base, foreground)) {
      return [Color.lerp(base, const Color(0xFFFFFFFF), travel)!, base];
    }
    return [base, Color.lerp(base, const Color(0xFF000000), travel)!];
  }

  /// The same fill as a ready-made [LinearGradient].
  static LinearGradient fillGradient(
    Color base, {
    required Color foreground,
    double travel = fillTravel,
  }) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: fill(base, foreground: foreground, travel: travel),
      );

  /// The usual text colour for a themed surface: the side [fill] moves away
  /// from. Black and white rather than the real body colour, because only the
  /// *direction* is used and both real colours sit on the same side.
  static Color textSide(AppTheme theme) =>
      theme.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// A gloss band — the reflection along a polished top edge — or null when
  /// there must not be one.
  ///
  /// **Painted *beneath* the content, never over it.** A white wash drawn over a
  /// card's header is a white wash over its text, whatever the alpha. Beneath,
  /// it is a fill, so the direction rule applies: it lightens, so it is allowed
  /// only behind dark text. On a dark surface the top bevel line carries the
  /// highlight instead, and this returns null.
  static LinearGradient? gloss(Color base, {required Color foreground}) {
    if (!foregroundIsDarker(base, foreground)) return null;
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
    );
  }

  /// The width of the chamfered rim, in logical pixels. One, like the hairline
  /// it replaced, so no surface changes size.
  static const double rimWidth = 1;

  /// A chamfered edge, as a gradient painted *behind* the fill and showing
  /// [rimWidth] past it: highlight at the top left, shade at the bottom right,
  /// the same light as every shadow in the app.
  ///
  /// **A gradient and not a `Border`, because Flutter cannot paint the obvious
  /// version.** A `Border` with a light top and a dark bottom has sides of
  /// different colours, and Flutter rejects that combined with a `borderRadius`
  /// or a circle: `A borderRadius can only be given on borders with uniform
  /// colors`. `flutter analyze` cannot see it. The first skeuomorphic pass on
  /// 7 October 2026 shipped exactly that on `AppCard`, which threw on every card
  /// in the app in a debug build and painted square edges on rounded cards in a
  /// release one; `skeuo_paint_test.dart` now pumps every surface to catch it.
  /// The gradient also reads better: light travels around the rim continuously
  /// instead of changing colour at the corners.
  ///
  /// **Blended from [base], toward white and toward black.** The old hairline
  /// was once tinted with the accent and put a green outline on every card — a
  /// drawn edge rather than a lit one. Mixing the surface with neutral light
  /// adds no hue the surface did not already have.
  ///
  /// [inverted] lights the rim from inside, for a well.
  static LinearGradient rim(
    Color base,
    AppTheme theme, {
    bool inverted = false,
    double strength = 1,
  }) {
    final highlight = Color.lerp(
      base,
      const Color(0xFFFFFFFF),
      ((theme.isDark ? 0.12 : 0.65) * strength).clamp(0.0, 1.0),
    )!;
    final shade = Color.lerp(
      base,
      const Color(0xFF000000),
      ((theme.isDark ? 0.45 : 0.14) * strength).clamp(0.0, 1.0),
    )!;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: inverted ? [shade, highlight] : [highlight, shade],
    );
  }

  /// The tinted badge wash, top and bottom, never stronger than [alpha].
  ///
  /// The wash is a tint of a status colour laid on the surface, and a stronger
  /// wash moves the background *toward* the status text — `AppBadge` records
  /// 0.08 at 4.63:1 and 0.12 at 4.39:1. So the gradient is made by *weakening*
  /// one end, never strengthening the other, and [alpha] stays the worst case.
  /// Which end weakens follows the same light-from-the-top rule as [fill].
  static List<Color> badgeWash(
    Color color, {
    required double alpha,
    required AppTheme theme,
  }) {
    final weak = color.withValues(alpha: alpha * 0.55);
    final full = color.withValues(alpha: alpha);
    // A weaker wash is lighter on a light page and darker on a dark one.
    return theme.isDark ? [full, weak] : [weak, full];
  }
}
