import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';
import '../screens/dashboard/utils/pressable.dart';
import '../theme/app_theme_of.dart';

import 'package:flutter/material.dart';

// ── AppBackground ────────────────────────────────────────────────────────────

/// The page backdrop.
///
/// This replaces `AmbientBackground` and its three-gradient orb painter. The
/// orbs existed for exactly one reason: the card fills were translucent, so
/// there had to be something behind them for the translucency to reveal. The
/// fills are opaque now — a soft-UI surface carries its depth in a dual shadow
/// pair, not in what shows through — so the orbs had nothing left to do.
///
/// They were also the most expensive paint in the app: three circles each with a
/// diameter wider than the screen, drawn as radial gradients over roughly ten
/// megapixels, and not gated by the Performance setting whose own subtitle
/// promised "flat cards, smoother scrolling". Removing them removes about ten
/// megapixels of shaded fill per repaint and makes that setting honest.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    required this.theme,
  });

  final Widget child;

  /// The appearance to paint, as an [AppTheme] rather than a bool. It is
  /// required rather than inferred because the backdrop is the one surface in
  /// the app that *is* the page, so a caller that guessed wrong here would put
  /// every card in the frame on the wrong ramp.
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurfaces.page(theme),
      child: child,
    );
  }
}

// ── Theme resolution for the widget layer ────────────────────────────────────

/// The [AppTheme] the tree is being painted in, for a widget whose caller did
/// not say.
///
/// **This is the widget-layer half of the Dracula migration, and it exists
/// because a `Brightness` cannot carry the answer.** Every widget in this file
/// used to fall back to
/// `isDark ?? Theme.of(context).brightness == Brightness.dark`, and for the two
/// themes that predated Dracula that was exact. It stopped being exact the
/// moment a third mode landed: [AppTheme.dracula] hands `MaterialApp`
/// [ThemeMode.dark], because Material has no third brightness and Dracula is a
/// dark theme, so `Theme.of(context).brightness` reports the *same*
/// [Brightness.dark] the app's own dark theme reports. A bool therefore cannot
/// distinguish them, and every null-[theme] call site would have quietly
/// rendered Dracula as plain dark — on the wrong page colour, the wrong shadow
/// alphas and the wrong elevation geometry, all of which are separately derived
/// values in `design_tokens.dart`.
///
/// **Why the scaffold background and not a controller.** `AppThemeController`
/// has the right answer, but it is a [ChangeNotifier] held by `main.dart` and
/// threaded down to the three screens that *have* a controller in their
/// constructor. A leaf widget like [AppCard] does not, there is no
/// `InheritedWidget` carrying it, and adding one is a change to the app's
/// plumbing rather than a signature migration. So this reads the theme the same
/// way `MaterialApp` published it, and it compares against the token
/// **constant** rather than a hex written here — which is the rule
/// `color_helpers_test.dart` exists to enforce for its surface lists, and it is
/// why this cannot go stale the way a hand-written hex did.
///
/// The practical contract for whoever owns `main.dart`: the `darkTheme`'s
/// `scaffoldBackgroundColor` must be `AppSurfaces.page(AppTheme.dracula)` when
/// the Dracula preset is active, which is already what it is for the other two
/// presets. If Dracula is ever wired up without that, this returns
/// [AppTheme.dark] and Dracula renders as the app's dark mode — a visible,
/// obvious failure rather than a subtle one, which is the right way round.
AppTheme _appThemeOf(BuildContext context) => appThemeOf(context);

// ── AppCard ──────────────────────────────────────────────────────────────────

/// The card every screen is built from.
///
/// The fill is the page colour, which is what makes the shadow pair read as a
/// shadow. A card one step off the page would read as flat Material instead,
/// which is the look this moved away from.
///
/// `borderRadius` defaults to [AppRadius.card] and the call sites stopped
/// passing it, because the app had a default plus exceptions rather than a
/// scale: twelve values from 3 to 28, with the card at 20 and the navigation
/// pill at 28 as the two outliers above everything else.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.theme,
    this.width,
    this.height,
    this.semanticLabel,
    this.accent,
    this.inset = false,
    this.pressed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Null reads the theme from the context, which is right for a widget that is
  /// always built under a `MaterialApp`. It is a parameter because the
  /// dashboard passes it down from a single place to keep every card in one
  /// frame agreeing on which appearance it is in — which is what stops a frame
  /// from being half Dracula and half the app's dark mode, since `MaterialApp`
  /// reports both as [Brightness.dark] and the context cannot tell them apart.
  ///
  /// This replaced a `bool? isDark`. See [_appThemeOf] for why the fallback had
  /// to stop being a brightness comparison.
  final AppTheme? theme;

  final double? width;
  final double? height;
  final String? semanticLabel;

  /// The theme accent, used for the hairline. Read from the theme when null, so
  /// no call site can pass a colour that disagrees with the one in use.
  final Color? accent;

  /// Cut the surface into the page instead of raising it off it. For input
  /// fields and for a chip that is not selected.
  final bool inset;

  /// The pressed state of a control.
  ///
  /// This used to *add* a small extra shadow on top of the raised pair, which
  /// made a pressed card slightly darker rather than pressed. In this style a
  /// press is the light source moving from outside the object to inside it, so
  /// it is now [AppElevation.pressed] — the bounce arriving from the other side
  /// — rather than a fourth shadow. Nothing in the app passed this flag before;
  /// it is wired up through `Pressable` now.
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final theme = this.theme ?? _appThemeOf(context);
    final resolvedAccent = accent ?? Theme.of(context).colorScheme.primary;

    final shadows = <BoxShadow>[
      if (pressed)
        ...AppElevation.pressed(theme)
      else if (!inset)
        ...AppElevation.raised(theme)
      else
        ...AppElevation.inset(theme),
    ];

    final decoration = BoxDecoration(
      color: inset ? AppSurfaces.input(theme) : AppSurfaces.card(theme),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: AppElevation.hairline(
          accent: resolvedAccent,
          theme: theme,
        ),
      ),
      boxShadow: shadows,
    );

    // The `Material` goes *between* the decorated box and the content, not
    // around the decorated box.
    //
    // A `Container` with a `BoxDecoration` paints its background on the same
    // layer as everything inside it, so a `Material` placed outside it is still
    // underneath: the card fill covers the ink layer, and anything inside with
    // its own ink — a `ListTile`, a `SwitchListTile`, an `InkWell` — loses its
    // splash and its hover state. Putting the Material inside the Container
    // makes the card fill paint first and the ink paint over it, which is the
    // order that works.
    //
    // `MaterialType.transparency` because the fill is already painted by the
    // Container; this one exists only to own the ink.
    // `AnimatedContainer` rather than `Container`, and only because `pressed`
    // is a flag on a stateless widget: without it the shadow pair swaps on the
    // frame the finger lands, which reads as a flicker rather than a press.
    //
    // The cost when idle is a controller that is not ticking, so this is not the
    // kind of implicit animation worth avoiding. It does mean the decoration is
    // rebuilt and compared on every card build, which is why the eight cards on
    // a dashboard page are each behind a `RepaintBoundary` below — the animation
    // is a paint concern, and that is the thing that actually costs.
    final content = AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.enter,
      width: width,
      height: height,
      decoration: decoration,
      padding: padding,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );

    // The boundary is what keeps a card from re-rasterising when something
    // above it moves, and the eight cards on a dashboard page are all inside
    // one scrolling list.
    final card = RepaintBoundary(child: content);

    if (semanticLabel != null) {
      // **`excludeSemantics: true`, and the reason is that the caller has already
      // written the better sentence.**
      //
      // `container: true` creates a node but does not stop the children being
      // walked, so a screen reader read the caller's summary and then went on to
      // read every `Text` beneath it -- for a chart card that meant the summary,
      // then the legend, then the live values, then each of the three statistics
      // rows, all of which the summary had just said in one sentence. The
      // summary exists precisely because it is a better description than the
      // concatenation of its parts.
      //
      // `TelemetryChartCard` is the case that made this worth changing. Its
      // custom `LineChart` exposes nothing to a screen reader, which is why the
      // sentence is there at all, and the statistics rows *are* real text -- so
      // before this, a screen-reader user heard "Voltage, Current, Power. Last
      // 24 hours" and then the same six numbers again.
      //
      // Cards without a `semanticLabel` are untouched: they have no summary, so
      // their contents are the only description there is, and suppressing them
      // would leave a card silent.
      return Semantics(
        label: semanticLabel,
        container: true,
        excludeSemantics: true,
        child: card,
      );
    }
    return card;
  }
}

// ── AppTile ──────────────────────────────────────────────────────────────────

/// A small block inside a card: a metric value, a legend entry, a legend dot.
///
/// It used to be a hand-written `BoxDecoration` with a low-alpha colour wash at
/// one of three different radii — 16 in the energy card, 14 in the energy report
/// totals, for the same conceptual object. This is that object, once.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.child,
    required this.theme,
    this.accent,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.inset = true,
  });

  final Widget child;

  /// The appearance to paint. Required rather than optional because a tile is
  /// small enough that an inferred mode is a misread rather than a subtlety, and
  /// because it is the surface `color_helpers_test.dart` measures
  /// `faintColor` and the four status colours against.
  final AppTheme theme;

  /// A low-alpha wash of this colour under the tile.
  ///
  /// This is what makes a PV tile read differently from an AC one. The energy
  /// report used `0xFFFFC857` at 0.12 and the dashboard's energy card used the
  /// accent at 0.08 or 0.12, at two different radii, for the same object — so
  /// the wash belongs to the token now rather than to each call site.
  ///
  /// The value is a data-series colour, not a status colour: it says which
  /// quantity this tile is, not whether anything is wrong.
  final Color? accent;

  final EdgeInsetsGeometry padding;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    // An inset tile is a *well*, and a well is carried by a shadow rather than
    // by a darker fill. That is the same principle as `inputLight` and the same
    // code as `AppCard`'s inset branch: fill with `AppSurfaces.input`, add
    // `AppElevation.inset`.
    //
    // **This was `AppSurfaces.track` and it failed WCAG AA, measured.** A tile is
    // not a bar — it is a ~190dp box with a caption ("PV production") and a
    // delta ("+2% vs previous") drawn on it, and the light track `#CFD6D2` is the
    // darkest light-mode surface in the app. On it: `faintColor` 3.85:1,
    // `statusOk` 3.85:1, `statusWarn` 3.87:1, `statusBad` 3.86:1, `statusAlert`
    // 3.86:1. Five failures against 4.5, on 10–11dp text.
    //
    // It passed for the same reason the track does: `test/color_helpers_test.dart`
    // deliberately kept `AppSurfaces.track` out of its surface lists, because a
    // 6–8dp progress bar has no text on it. That exclusion was written for the
    // bars and then applied to the tile as well, and the tile is the one consumer
    // where it was false. The test now measures the tile fill as its own
    // surface; the track exclusion stays, and says why.
    //
    // `inputLight` `#EDF1EF` measures 4.99 / 5.00 / 5.02 / 5.01 / 5.01 on those
    // same five, so it clears AA with real margin rather than by hundredths.
    //
    // Dark mode does change surface (`trackDark` `#131A18` to `inputDark`
    // `#1E2623`) because the two modes have to agree — a light-mode well that is
    // lighter than the page and a dark-mode well that is darker than it is the
    // right instinct in both, and `AppSurfaces.input` is the token that already
    // encodes "lighter than the page, shadow carries the inset". Both clear AA
    // comfortably and the gap is small: `faintColor` is 8.17:1 on the old dark
    // track and 7.16:1 on the new one, against 4.5.
    final tile = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: inset ? AppSurfaces.input(theme) : AppSurfaces.card(theme),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: appDivider(theme: theme, opacity: 0.5)),
        // Without this the lighter fill simply flattens the tile. It was carrying
        // the whole inset read on its own, because a `BoxShadow` paints *outside*
        // the decoration rect and so cannot darken a tile's own interior — the
        // interior is the fill's job, the depth around it is the shadow's.
        boxShadow: inset ? AppElevation.inset(theme) : null,
      ),
      child: child,
    );

    // No wash by default, and that is a correction rather than an omission.
    //
    // The metric grid passes the theme accent here, and with the wash applied all
    // five cards wore a green tint. On the device it read as a slightly ill set
    // of tiles rather than as a monochrome soft-UI surface: colour is the one
    // thing this style cannot be generous with, because a card's depth is
    // supposed to come from its shadow pair and nothing else. So the wash is
    // reserved for a tile whose colour carries *meaning* — the energy report's
    // PV and AC series, which is the documented data-series exception.
    //
    // The energy summary card's two tiles and the report's totals tiles keep
    // theirs. The environment and fish grids do not, and they do not pass an
    // accent; this is the default rather than a call-site decision so the next
    // person adding a grid cannot reintroduce it by accident.
    if (accent == null) return tile;

    // The wash is clipped to the same radius, because the Container's
    // `borderRadius` does not clip its children — an unclipped square-cornered
    // wash paints over the rounded corner and the tile reads as a rectangle
    // sitting on a rounded card.
    //
    // 0.14 rather than the 0.12 the two call sites used, and lighter in dark
    // mode: the wash is a data-series colour, and it has to stay weak enough
    // that `faintColor` on top of it keeps at least 4.5:1.
    //
    // **That constraint is not currently satisfied by anything, because this
    // wash is invisible.** `ColoredBox` is the *parent* here, and the tile's own
    // `BoxDecoration` carries an opaque `color`, so the fill paints straight over
    // the wash. `ClipRRect` clips the wash to the tile radius and the Container
    // fills that same radius, so no sliver of it survives either. The two accent
    // tiles in the energy summary have therefore been rendering with no wash at
    // all since this was extracted from two call sites.
    //
    // It is left exactly as it is, deliberately. Making it visible means either
    // compositing it *over* the fill at 0.14 — which measures `faintColor` at
    // 4.42:1 on the solar accent and 4.10:1 on the darker AC accent, i.e. two
    // fresh AA failures on the delta caption — or inventing a translucent tile
    // fill so the wash can show through, which is the fill-contrast bug this
    // widget was just fixed for. Neither is a change to make while fixing a
    // contrast failure elsewhere in the same widget. The wash staying dead is
    // also why it does not move the numbers in `color_helpers_test.dart`: the
    // rendered surface is the fill, and the fill is opaque. If the wash is ever
    // revived it has to be measured, not eyeballed.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: ColoredBox(
        color: accent!.withValues(alpha: theme.isDark ? 0.20 : 0.14),
        child: tile,
      ),
    );
  }
}

// ── AppBadge ─────────────────────────────────────────────────────────────────

/// A small status pill. Narrow, so it gets the tight radius rather than the
/// card's.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.child,
    required this.theme,
    required this.color,
  });

  final Widget child;

  /// The appearance to paint. The wash alpha is keyed on brightness only —
  /// Dracula takes the dark value — because the wash is the *same colour* as the
  /// label on it and every point of alpha is a point of contrast; see below.
  final AppTheme theme;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 0.08 in light mode, not 0.12, and the reason is arithmetic rather than
    // taste: the wash is the *same colour* as the label sitting on it, so every
    // point of alpha is a point of contrast. Measured on the light page,
    // `statusOk` is 5.14:1 on the card and 4.39:1 on a 0.12 wash of itself —
    // under AA. The ramp is 0.08 -> 4.63, 0.10 -> 4.50, 0.12 -> 4.39. The
    // status colours are already at 4.5 on the surface with almost no margin,
    // so the wash has to be the shallowest one that still reads as a tint.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: theme.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: child,
    );
  }
}

// ── AppDivider ───────────────────────────────────────────────────────────────

/// A one physical pixel rule. It was 0.5dp, which is the thinnest line in the
/// app and renders as a grey smear on a 3x screen.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, required this.theme, this.opacity = 0.10});

  final AppTheme theme;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: appDivider(theme: theme, opacity: opacity),
    );
  }
}

// ── DateStripChip ────────────────────────────────────────────────────────────

/// One day in the date strip.
///
/// A selected chip is raised off the page and filled with the accent; an
/// unselected one is cut into it. That is the whole soft-UI vocabulary in one
/// control, and it is why the chip needed its own widget rather than sharing
/// `AppCard`: the two states are inverses of each other, not two shades of one.
class DateStripChip extends StatelessWidget {
  const DateStripChip({
    super.key,
    required this.dayName,
    required this.dayNumber,
    required this.isSelected,
    required this.theme,
    required this.onTap,
    required this.accentColor,
    this.width = 48,
  });

  /// The chip's horizontal padding and its border width, in logical pixels.
  ///
  /// **Exposed because `DateStrip` measures the day name to decide how wide a
  /// chip has to be, and a measurement that ignores either of these is wrong by
  /// exactly that much.**
  ///
  /// This is not hypothetical: the first attempt at that measurement carried its
  /// own `10 + 2` guess, and the strip still shipped clipping `Mon` and `Wed` at
  /// 2x -- a 0.75 px shortfall, invisible to `flutter analyze`, invisible to a
  /// release build, and only visible as `M…` on a screen. Two numbers written down
  /// twice in two files is a copy, and this one had already drifted once.
  static const double horizontalPadding = 5;
  static const double borderWidth = 1;

  final String dayName;
  final int dayNumber;
  final bool isSelected;

  /// The appearance to paint. Required, because a chip is the app's only
  /// control that is a *raised block* and a *well* in the same widget, so a
  /// wrong mode here does not merely shift a colour — it puts `raised` and
  /// `insetDeep` on the wrong branch of [decorationFor].
  final AppTheme theme;
  final VoidCallback onTap;
  final Color accentColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    // `theme.isDark`, not a Dracula branch: the ink on an accent fill is a
    // contrast question and the app's dark ink `#14201A` is the answer for both
    // dark presets. Nothing here needs Dracula's own accent.
    final onAccent = theme.isDark ? const Color(0xFF14201A) : Colors.white;

    // An unselected chip is a well and a selected one is a block, so the two
    // states differ in more than colour and the press state has to be a third
    // geometry again — it is neither "in" nor "out", it is "being pushed". A
    // pressed well deepens and a pressed block flattens, which is what a chip
    // between two states should do.
    BoxDecoration decorationFor({required bool pressed}) {
      if (isSelected) {
        return BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: AppElevation.controlEdge(
              accent: accentColor,
              theme: theme,
            ),
          ),
          boxShadow: pressed
              ? AppElevation.pressed(theme)
              : AppElevation.raised(theme),
        );
      }
      return BoxDecoration(
        color: AppSurfaces.page(theme),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: appDivider(theme: theme)),
        boxShadow: pressed
            // A well that is being pressed is deeper than a well at rest, so it
            // takes the raised pair's scale of offset and blur but stays a well:
            // the light still comes from inside, so this is [AppElevation.inset]
            // with a wider spread rather than the pressed pair, which is the
            // inverse of a raised block and would point the wrong way.
            ? AppElevation.insetDeep(theme)
            : AppElevation.inset(theme),
      );
    }

    return RepaintBoundary(
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: isSelected,
          label: '$dayName $dayNumber',
          child: Pressable(
            onTap: onTap,
            pressedScale: 0.94,
            builder: (pressed) => AnimatedContainer(
              duration: AppMotion.press,
              curve: AppMotion.enter,
              width: width,
              // **68 is a floor, not a height.** It was a fixed `height: 68`,
              // which is the other half of the font-scale defect: with the day
              // name free to grow, a fixed height either clipped it or made the
              // `Column` overflow. Measured, at 2x scale on a 42 dp chip, the
              // fixed height overflowed by 40 px.
              //
              // So the chip keeps its designed height at 1.0 and grows above it
              // when the user has asked for larger text. `minHeight` rather than
              // `height` is what makes that a floor instead of a clamp; the strip
              // gets taller at 2x, which is the whole point of the setting.
              constraints: const BoxConstraints(minHeight: 68),
              padding: EdgeInsets.symmetric(
                vertical: 7,
                horizontal: DateStripChip.horizontalPadding,
              ),
              decoration: decorationFor(pressed: pressed),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // **No `SizedBox(height: 13)` and no `FittedBox`.**
                  //
                  // There was a fixed 13 dp box with a `scaleDown` inside it, so at
                  // a 2x system font scale the day name was laid out at 20 sp and
                  // then scaled straight back down to 13 dp. It rendered at
                  // effectively its 1.0 size whatever the user had asked for --
                  // the one place in the app that silently inverted an
                  // accessibility setting, and it did it invisibly, which is why
                  // it is worth a comment rather than a silent removal.
                  //
                  // The fixed height existed to keep the strip compact, so the
                  // honest fix is to let the chip grow instead of shrinking the
                  // text inside a box that cannot. The strip is a fixed-height
                  // control and grows with the setting the user chose; a taller
                  // strip at 2x is what being asked for.
                  //
                  // `maxLines: 1` with `ellipsis` remains as a last-resort guard,
                  // but **it is not the answer to a large font scale, and the
                  // comment that used to say otherwise was wrong.**
                  //
                  // The reasoning it replaced was: "at a large scale a
                  // three-letter abbreviation can still exceed a 42 dp chip --
                  // and a day name that reads 'Mo' instead of 'Mon' is still a
                  // day name, unlike a truncated reading." Checked on an emulator
                  // at 2x, it did not read 'Mo'. It read `S`, `M`, `W`, `T`,
                  // `T`, `F`, `S` -- one letter each, because at 2x not even two
                  // letters fit in 42 dp. `S` is not a day name, and it is
                  // ambiguous besides: Saturday and Sunday share it, so do Tuesday
                  // and Thursday.
                  //
                  // The width a chip takes is now measured from the text and the
                  // user's text scale in `DateStrip`, and the strip scrolls
                  // horizontally rather than amputating. This `ellipsis` is now
                  // unreachable at any ordinary scale; it is kept because a chip
                  // width is a `LayoutBuilder` decision and a `maxLines` with no
                  // overflow has its own overflow.
                  Text(
                    dayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? onAccent : faintColor(theme.isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? onAccent : appPrimaryText(theme.isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ordinary text colour on a card.
///
/// It was `Colors.white` or `Colors.black87` chosen at each of a dozen call
/// sites. Both are fine; having twelve of them is not, because one of them
/// would eventually be `black54` and that is the failure the AA work was about.
///
/// **It still takes a `bool isDark`, and that is the same deliberate split as
/// `faintColor` and the status colours.** A text colour is shared by the two
/// dark presets — `#F2F5F3` is 12.97:1 on Dracula's `#282A36`, unchanged — so a
/// call site in a widget that already has an `AppTheme` passes
/// `theme.isDark`. See [AppTheme.isDark] for the measurement and the argument
/// against adding a Dracula text palette.
Color appPrimaryText(bool isDark) =>
    isDark ? const Color(0xFFF2F5F3) : const Color(0xFF1A211E);
