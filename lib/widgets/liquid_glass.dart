import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';
import '../screens/dashboard/utils/pressable.dart';

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
    required this.isDark,
  });

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurfaces.page(isDark),
      child: child,
    );
  }
}

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
    this.isDark,
    this.width,
    this.height,
    this.semanticLabel,
    this.accent,
    this.inset = false,
    this.pressed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Null reads the brightness from the context, which is right for a widget
  /// that is always built under a `MaterialApp`. It is a parameter because the
  /// dashboard passes it down from a single place to keep every card in one
  /// frame agreeing on which mode it is in.
  final bool? isDark;

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
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    final resolvedAccent = accent ?? Theme.of(context).colorScheme.primary;

    final shadows = <BoxShadow>[
      if (pressed)
        ...AppElevation.pressed(dark)
      else if (!inset)
        ...AppElevation.raised(dark)
      else
        ...AppElevation.inset(dark),
    ];

    final decoration = BoxDecoration(
      color: inset ? AppSurfaces.input(dark) : AppSurfaces.card(dark),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: AppElevation.hairline(accent: resolvedAccent, isDark: dark),
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
      return Semantics(label: semanticLabel, container: true, child: card);
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
    required this.isDark,
    this.accent,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.inset = true,
  });

  final Widget child;
  final bool isDark;

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
    final tile = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: inset
            ? AppSurfaces.track(isDark)
            : AppSurfaces.card(isDark),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: appDivider(isDark: isDark, opacity: 0.5)),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: ColoredBox(
        color: accent!.withValues(alpha: isDark ? 0.20 : 0.14),
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
    required this.isDark,
    required this.color,
  });

  final Widget child;
  final bool isDark;
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
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
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
  const AppDivider({super.key, required this.isDark, this.opacity = 0.10});

  final bool isDark;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: appDivider(isDark: isDark, opacity: opacity),
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
    required this.isDark,
    required this.onTap,
    required this.accentColor,
    this.width = 48,
  });

  final String dayName;
  final int dayNumber;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final Color accentColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final onAccent = isDark ? const Color(0xFF14201A) : Colors.white;

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
            color: AppElevation.controlEdge(accent: accentColor, isDark: isDark),
          ),
          boxShadow: pressed
              ? AppElevation.pressed(isDark)
              : AppElevation.raised(isDark),
        );
      }
      return BoxDecoration(
        color: AppSurfaces.page(isDark),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: appDivider(isDark: isDark)),
        boxShadow: pressed
            // A well that is being pressed is deeper than a well at rest, so it
            // takes the raised pair's scale of offset and blur but stays a well:
            // the light still comes from inside, so this is [AppElevation.inset]
            // with a wider spread rather than the pressed pair, which is the
            // inverse of a raised block and would point the wrong way.
            ? AppElevation.insetDeep(isDark)
            : AppElevation.inset(isDark),
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
              height: 68,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
              decoration: decorationFor(pressed: pressed),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 13,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? onAccent : faintColor(isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? onAccent : appPrimaryText(isDark),
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
Color appPrimaryText(bool isDark) =>
    isDark ? const Color(0xFFF2F5F3) : const Color(0xFF1A211E);
