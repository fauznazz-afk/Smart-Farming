/// Every surface, radius, edge, type and motion value in the app.
///
/// **This file replaced a soft-UI token layer on 9 October 2026, and the change
/// inverts three of its central rules.** The previous system was neumorphic: a
/// card was painted *the same colour as the page* and all of its depth came
/// from a three-shadow pair, with a white bounce on the light side and a dark
/// contact plus ambient on the other. The system now is flat and categorical:
/// tonal layering and a 1px hairline do the work that shadows used to, and hue
/// carries meaning.
///
/// The three inversions, recorded because each one is load-bearing and each one
/// cost something to learn:
///
///  * **Card fill is no longer the page fill.** `AppSurfaces.card` used to be
///    *defined as* `AppSurfaces.page`, and a test asserted that identity for
///    four themes. It exists to make a shadow legible as a shadow. Under a flat
///    system the shadow is gone and that identity has nothing left to protect —
///    it was only ever true because depth had to come from somewhere else.
///  * **Elevation is gone.** `AppElevation` returned contact, ambient and bounce
///    shadows, and roughly 400 lines of test prose described how many there were,
///    which way they pointed, and how the two halves of each pair related. There
///    is no flat-system equivalent of any of that, so the class is gone rather
///    than emptied. Its three edge helpers moved to [AppBorders].
///  * **Colour is categorical.** The old rule was that the app never varies a
///    hue automatically: `metricColor` accepted an `index` and ignored it, and a
///    test failed loudly if it ever started using it, because "a colour the user
///    did not choose is a colour they cannot predict". That reasoning was sound
///    for a single-accent app. It does not survive a design whose whole premise
///    is that each category of data owns a fixed hue that is reused everywhere
///    that category appears, so it has been reversed deliberately — see
///    `color_helpers.dart` for the new rule and the collision analysis.
///
/// **What did not change.** Depth still cannot be bought with the fill. A
/// `BoxShadow` paints outside the decoration rect and so cannot darken a card's
/// own interior, which is where every caption is drawn; a gradient across the
/// fill can, and at 4% the light-mode worst case measured 4.15:1 against an AA
/// requirement of 4.5. Under the flat system the equivalent trap is a tonal wash
/// on the fill for its own sake, and [AppBorders.categorical] exists so that the
/// sanctioned version — a wash paired with a full-strength foreground — is one
/// named function rather than something each call site reinvents.
library;

import 'package:flutter/material.dart';

/// The three-layer dark stack.
///
/// Strictly ordered: `page` < `surface` < `surfaceAlt`. Hierarchy is tonal.
/// No value here varies by theme, because there is one theme.
class AppSurfaces {
  const AppSurfaces._();

  /// The page canvas, `#0F0F11` — nearly black, slightly cool.
  ///
  /// This is where the old system needed a *mid-tone* (`#E1E7E4` in light mode)
  /// so that both halves of every shadow pair had somewhere to go. That
  /// constraint is gone with the shadows: a flat system gets its depth from
  /// `surface` sitting above `page`, and the canvas is free to be as dark as the
  /// design asks for. So the light-mode mid-tone rule does not survive, and
  /// neither does the reasoning attached to it.
  static const Color page = Color(0xFF0F0F11);

  /// The card layer, `#1A1A1C`, lifted only by the hairline [border].
  ///
  /// **One step above [page], and the step is small on purpose.** `#1A1A1C` is
  /// relative luminance 0.0104 against `#0F0F11`'s 0.0048 — a ratio of 2.17,
  /// which is a *fill* step you can see on a phone at arm's length but not one
  /// that shouts. The hairline does the actual boundary work, so a large tonal
  /// jump here would double up on it.
  static const Color surface = Color(0xFF1A1A1C);

  /// The deepest tonal step, `#27272A` — used inside cards.
  ///
  /// Input fills, progress-bar tracks, category icon tiles, chart tooltips. It
  /// is the only surface a caption sits on that is *lighter* than the card it
  /// lives in, which is why it is also the binding surface for the whole app's
  /// contrast measurements: anything that clears AA here clears AA on
  /// `surface` and on `page`, which are both darker.
  static const Color surfaceAlt = Color(0xFF27272A);

  /// Primary type, `#FAFAFA`.
  static const Color onSurface = Color(0xFFFAFAFA);

  /// Secondary type and metadata, `#A1A1AA`.
  ///
  /// **The binding caption colour, and it clears AA on every surface with room
  /// to spare** — 7.47:1 on [page], 6.78:1 on [surface], and 5.81:1 on
  /// [surfaceAlt], the worst case anywhere in the app. That margin is
  /// deliberately larger than the old system's was (three captions sat at 4.55 to
  /// 4.59 against an AA requirement of 4.5, so a surface tweak was a
  /// text-contrast change even when nothing about the text changed). The reason
  /// it can breathe here is that a dark canvas has more headroom than a mid-tone
  /// one did: the whole palette now sits in the top of the range rather than
  /// being squeezed around 229.
  static const Color onSurfaceVariant = Color(0xFFA1A1AA);

  /// The 1px hairline that encloses every card, `#3F3F46`.
  ///
  /// **This is doing the job elevation used to do**, which is why it is a real
  /// token and not a `withValues(alpha:)` at each call site. It measures 1.83:1
  /// against [page] and 1.66:1 against [surface], so it is *not* a WCAG 1.4.11
  /// boundary and is not claimed to be — 1.4.11 wants 3:1 and this is less than
  /// two thirds of that. The cards also differ from the page by fill, and the two
  /// cues together are the affordance. Where a control has no other affordance
  /// and genuinely needs 3:1, that is [AppBorders.boundary], not this.
  static const Color border = Color(0xFF3F3F46);

  /// Input fills. Same value as [surface]: a text field is a surface, and the
  /// hairline is what separates it from the page it sits on.
  static const Color input = Color(0xFF1A1A1C);

  /// Progress-bar and split-bar tracks. [surfaceAlt], for the same reason it is
  /// the chart tooltip: a track is an inset well and the fill has to read
  /// against it.
  static const Color track = Color(0xFF27272A);

  /// The chart tooltip, opaque because it must stay readable over an arbitrary
  /// series crossing underneath it. [surfaceAlt] is the lightest surface in the
  /// ramp, so a caption over it is the worst case anywhere in the app.
  static const Color tooltip = Color(0xFF27272A);

  /// Every surface the app paints a caption or a status colour on, in the order
  /// a reader should check them.
  ///
  /// **Derived, not written down.** This list used to be six hand-written hex
  /// values in `test/color_helpers_test.dart`. They were copied in when the glass
  /// fills were replaced, the fills changed again without touching the test, and
  /// because the stale values happened to be *lighter* than the real ones the
  /// test measured against a more forgiving surface than the one rendering:
  /// three captions sat below AA with the suite green. It survived two commits.
  /// A literal in a test whose job is to describe the app's own tokens is a
  /// copy, and copies drift.
  ///
  /// [surfaceAlt] is deliberately listed **last and separately** because it is
  /// the binding surface — it is listed at all, and the tests that consume this
  /// take the worst, but a reader scanning the list should see that the deepest
  /// tonal step is the hardest one, not the first one.
  static List<Color> captionSurfaces() => const [
    page,
    surface,
    surfaceAlt,
  ];

  /// The darkest step that still has to carry text. See [captionSurfaces].
  static Color get bindingCaptionSurface => surfaceAlt;
}

/// Corner radii, on one scale.
///
/// The design brief specifies exactly five values, and the app had twelve from
/// 3 to 28 before this. These are the brief's, renamed onto the roles the
/// existing call sites already use, so that a change of visual system did not
/// also become a rename of every widget in the app.
///
/// **The card radius doubled, from 16 to 24.** That is the brief's `rounded.xl`
/// and it is what makes this "chunky-soft" rather than merely soft; the old
/// value was chosen to join a scale that no longer exists.
class AppRadius {
  const AppRadius._();

  /// The canonical card radius, the brief's `rounded.xl`.
  static const double card = 24;

  /// Category icon tiles, square icon buttons, top-bar accessory chips — the
  /// brief's `rounded.md`.
  static const double tile = 12;

  /// Text inputs and smaller content tiles — the brief's `rounded.lg`.
  static const double inset = 16;

  /// Badge pills and chart bar tops — the brief's `rounded.sm`.
  static const double badge = 4;

  /// Progress and split bars. A stadium, not a 4px radius: a 4px radius on an
  /// 8px-tall bar is visually a stadium anyway, and saying so is clearer.
  static const double bar = 999;

  /// The bottom navigation, chips, buttons, pills. The brief's `rounded.full`.
  static const double pill = 999;

  /// Fully round, for dots and circular icon badges. Same value as [pill]; both
  /// names are kept because they mean different things to a reader even when
  /// they resolve to the same number.
  static const double round = 999;

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

/// Borders and edges — the replacement for the elevation system.
///
/// **A flat design has exactly one depth cue and this is it.** Everything the
/// three-shadow pair used to say about a surface is now said by a 1px line
/// around it, and by the tonal step from [AppSurfaces.page] to
/// [AppSurfaces.surface].
///
/// The old `AppElevation` also produced *press* geometry — `pressed` flattened
/// a raised block and `insetDeep` pushed a well further in, and there was a test
/// asserting that a press had to reach a smaller offset than its resting state
/// or the control read as lifting off the page. None of that survives: a flat
/// surface has no thickness to collapse. Press feedback here is opacity and
/// colour, which is what [AppMotion.press] drives.
class AppBorders {
  const AppBorders._();

  /// The 1px hairline on a card. [AppSurfaces.border], un-tinted.
  ///
  /// **Neutral on purpose, and the reason is worth keeping.** An earlier
  /// revision tinted this with the theme accent, which put a coloured outline on
  /// every card and silently undid the whole migration: a coloured border is a
  /// drawn edge, and under the old system a drawn edge was the one thing the
  /// style existed to replace. Under the new system a drawn edge *is* the style,
  /// but it still should not carry hue — hue is spoken for, and a coloured
  /// hairline would make every card claim a category it does not have.
  static const BorderSide hairline =
      BorderSide(color: AppSurfaces.border, width: 1);

  /// The outline on a control the user can press.
  ///
  /// Distinct from [hairline] only in being stronger: 2.48:1 against [page] and
  /// 2.25:1 against [surface], so a tappable thing does not look like a label.
  /// Still short of WCAG 1.4.11's 3:1, and the honest statement is that this is
  /// a grouping cue rather than a compliance claim. It is not pushed to 3:1
  /// because a compliant grey frame around every control in the app is a
  /// heavier visual than the design brief asks for, and the brief's own answer
  /// to "how is a control bounded" is its fill plus the hairline.
  static const BorderSide control =
      BorderSide(color: Color(0xFF52525B), width: 1);

  /// A neutral edge that clears WCAG 1.4.11's 3:1 for a UI component boundary.
  ///
  /// Reserved for the places where a control has no other affordance: the CCTV
  /// info bar, which sits over video, and the standby play button, which sits
  /// over a dimmed frame. `onSurface` at full strength clears it comfortably
  /// against arbitrary camera content, which nothing else in the palette can be
  /// relied on to do.
  static const BorderSide boundary =
      BorderSide(color: Color(0xFFFAFAFA), width: 1.5);

  // ── The same three, as a `BoxBorder` ─────────────────────────────────────────
  //
  // **These exist because `BorderSide` and `BoxBorder` are not interchangeable,
  // and the mistake is silent at the call site and loud in the analyzer.**
  // `BoxDecoration.border` takes a `BoxBorder`, so a decoration that wants a
  // hairline has to write `Border.fromBorderSide(AppBorders.hairline)` — which is
  // correct but wordy, and it appears at roughly forty decoration sites. A
  // `Border.all(color: AppBorders.hairline)` does not compile, because that
  // parameter wants a `Color`, not a side.
  //
  // Rather than pick one shape and force every call site to convert, both are
  // named: the `BorderSide` for a single edge (`Border.fromBorderSide`, or
  // `.color` when you want just the colour) and the `*Border` for a
  // `BoxDecoration`.
  static const BoxBorder hairlineBorder = Border.fromBorderSide(hairline);
  static const BoxBorder controlBorder = Border.fromBorderSide(control);
  static const BoxBorder boundaryBorder = Border.fromBorderSide(boundary);

  /// The brief's categorical recipe: a 10%-alpha wash of the category's own hue
  /// behind a full-strength foreground of the same hue.
  ///
  /// **The one sanctioned way to put a hue behind text**, and a function rather
  /// than a convention because the old system's strongest rule was that depth
  /// and emphasis could not be bought with the fill — a wash behind a caption
  /// is exactly the thing that silently cost contrast. Pairing it with a
  /// full-strength foreground is what makes it safe, and keeping the pairing in
  /// one place is what stops a future call site from writing
  /// `hue.withValues(alpha: 0.3)` over 12px white text on its own.
  ///
  /// [AppBorders.categoricalBorder] is the 20%-alpha companion; both are
  /// produced from the same hue so a tile cannot end up with a wash and a border
  /// that disagree.
  static Color categoricalWash(Color hue) => hue.withValues(alpha: 0.10);

  /// The 20%-alpha hairline that goes with [categoricalWash].
  ///
  /// **Returned as a [Border] rather than a [BorderSide]**, because its only
  /// callers are `BoxDecoration`s and there is no call site that wants one edge of
  /// it. See the note on [hairlineBorder] for why both shapes exist.
  static Border categoricalBorder(Color hue) =>
      Border.fromBorderSide(
        BorderSide(color: hue.withValues(alpha: 0.20), width: 1),
      );
}

/// The three typefaces, on one scale.
///
/// **Two weights per family, no middle.** Numerals and headlines are 700, labels
/// are 700, body is 500. There is no 400 and no 600 anywhere in the app.
///
/// **The ceiling is 700 and that is the typeface's, not the design's.** The brief
/// asks for weight 900 on every numeral and headline, and this file originally
/// said `FontWeight.w900` in four places. Space Grotesk's variable axis stops at
/// 700 — that is the family's genuine maximum, read from the `fvar` table of the
/// master, not inferred — so no 900 exists to bundle. Declaring 900 anyway does
/// not fail: `flutter analyze` is clean, the release APK builds, and every test
/// passes, because Flutter synthesises the extra weight by smearing the 700
/// outlines. The result is a heading that looks slightly smeared at 36px and is
/// slightly wrong everywhere. It is recorded here because "900" is the number in
/// the brief and the next reader should find out why it is not in the file.
///
/// The reference screen settles it: its display weight is a heavy grotesque, not
/// a black, and 700 reproduces it. Choosing a different family to reach a 900
/// would have been the larger deviation — a different typeface is a visible
/// change on every screen, a weight ceiling is invisible.
///
/// Space Grotesk carries every numeral, which is the load-bearing choice: the
/// data is the hero on every card, and a humanist sans at tabular figures does
/// not read that way. Plus Jakarta Sans carries labels, which are almost always
/// uppercase with wide tracking. JetBrains Mono is for ratios where tabular
/// precision matters, in tiny doses.
class AppType {
  const AppType._();

  /// Numerals and headlines.
  static const String heading = 'SpaceGrotesk';

  /// Labels, captions, metadata, body.
  static const String sans = 'PlusJakartaSans';

  /// Ratios and tabular data.
  static const String mono = 'JetBrainsMono';

  // ── Numerals ────────────────────────────────────────────────────────────────

  /// The hero figure on a card. 36px, bold, tight. See the note on [AppType] for why
  /// this is 700 and not the 900 the brief asks for.
  static const TextStyle numeralXl = TextStyle(
    fontFamily: heading,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -0.02 * 36,
  );

  /// A secondary figure, or a screen title. 24px, bold.
  static const TextStyle numeralLg = TextStyle(
    fontFamily: heading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.01 * 24,
  );

  /// A screen title. 30px, bold, uppercase.
  static const TextStyle displayLg = TextStyle(
    fontFamily: heading,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: -0.025 * 30,
  );

  /// A secondary screen title. 24px, bold.
  static const TextStyle displayMd = TextStyle(
    fontFamily: heading,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.02 * 24,
  );

  /// A card sub-headline. 20px, bold.
  static const TextStyle headlineMd = TextStyle(
    fontFamily: heading,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.01 * 20,
  );

  // ── Labels ──────────────────────────────────────────────────────────────────

  /// The connective tissue. Uppercase, wide-tracked, bold — the motif the whole
  /// system is identified by, applied to every unit, caption and status word.
  static const TextStyle labelUppercase = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 0.12 * 12,
  );

  /// Smaller and wider-tracked still. Tab labels, metric units, badges.
  static const TextStyle labelMicro = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 0.1 * 10,
  );

  // ── Body ────────────────────────────────────────────────────────────────────

  /// Secondary descriptive text inside a list row.
  static const TextStyle bodyMd = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Used sparingly. Small print under a chart, a footnote.
  static const TextStyle bodySm = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// A ratio or a tabular pair, where digit alignment has to be exact.
  static const TextStyle numeralMono = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1,
  );
}

/// The durations and curves for everything that moves.
///
/// Unchanged by the restyle, because nothing here was about how a surface looks.
/// Press feedback is fast, state changes ease out, and nothing in the app moves
/// on a spring.
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

/// A divider, for the rare place that needs a rule rather than a border.
///
/// [AppBorders.hairline] is the default and this is not: a border draws the
/// outline of a thing, a divider draws a line *between* two things inside it.
Color appDivider({double opacity = 1.0}) =>
    AppSurfaces.border.withValues(alpha: opacity);

/// The categorical palette.
///
/// **These are the brief's values, and they are fixed.** The old system let the
/// user pick an accent from four swatches and then never varied it. The new
/// system assigns a hue to each category of data and reuses it everywhere that
/// category appears, so the palette is a *vocabulary* rather than an accent —
/// which means it cannot be user-configurable without destroying the thing it
/// exists to do.
///
/// `success` and `error` are the two that are also semantic. They are allowed to
/// play categorical roles, but see `color_helpers.dart` for the collision
/// analysis that keeps an ordinary reading from ever landing on the colour that
/// means "this is wrong".
class AppPalette {
  const AppPalette._();

  /// Coral. The focal/CTA hue, and the active navigation item.
  static const Color primary = Color(0xFFF7A5A5);

  /// Periwinkle. The second categorical hue.
  static const Color secondary = Color(0xFF8E99F3);

  /// Butter yellow. The text-button and focus-ring hue.
  static const Color accent = Color(0xFFFCE570);

  /// Mint. Semantic: a healthy reading.
  static const Color success = Color(0xFF4ADE80);

  /// Red. Semantic: a breach. See `color_helpers.dart` before using this as a
  /// category hue.
  static const Color error = Color(0xFFEF4444);

  /// A chart-series hue. Kept out of [primary] and [secondary] on purpose — a
  /// chart series is a trend the user is reading, which is a different job from
  /// being the app's call to action, and one colour doing both is how a palette
  /// starts meaning two things.
  static const Color chartViolet = Color(0xFFC084FC);

  /// A second chart-series hue.
  static const Color chartCoral = Color(0xFFFF8577);

  /// Ink on a saturated categorical fill. Every hue in this palette is light
  /// enough that dark ink is correct on all of them: 9.02:1 on [primary], 6.63
  /// on [secondary], 13.74 on [accent], 9.99 on [success], 6.59 on
  /// [chartViolet], 7.35 on [chartCoral], and **4.62 on [error]** — which is the
  /// tightest and the reason this is a measured list rather than an assumption.
  /// White on [primary] would measure 1.71:1, so this token is not a nicety.
  static const Color onHue = Color(0xFF1A1A1A);

  /// The coloured aura on the FAB and the focal chart bar.
  ///
  /// **Not a depth shadow.** The brief is explicit that this is a light source
  /// rather than elevation, and it is the only shadow in the system. It is
  /// allowed to exist because it is announcing the active brand element, not
  /// making a card float.
  static List<BoxShadow> aura(Color hue, {double strength = 0.30}) => [
    BoxShadow(
      color: hue.withValues(alpha: strength),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
