import 'package:flutter/material.dart';

import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';

/// The shared surface kit: the four primitives every screen is built from.
///
/// **This file replaced a soft-UI / skeuomorphic layer on 9 October 2026.** The
/// primitives kept their names — `AppCard`, `AppTile`, `AppBadge`,
/// `AppBackground` — and lost their `theme:` parameter, because a single dark
/// theme does not have one to pass. That was the deliberate part: keeping the
/// names meant the roughly forty call sites needed no change, and dropping the
/// parameter meant none of them is left holding a value that means nothing.
///
/// What every primitive lost is its shadow list. There is no elevation here; a
/// surface is distinguished by a tonal step and a 1px hairline, and that is the
/// whole depth system. See `design_tokens.dart` for why the three-shadow pair is
/// gone rather than reduced, and `AppBorders` for the hairline that replaced it.
library;

// ── AppBackground ──────────────────────────────────────────────────────────────

/// The page backdrop.
///
/// The previous version painted three large radial-gradient orbs over the page
/// colour. They existed to give the translucent card fills something to reveal,
/// and the fills went opaque when the neumorphic system arrived, so the orbs were
/// already dead weight: about ten megapixels of shaded fill per repaint that
/// nothing could see. A flat system wants a flat page.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurfaces.page,
      child: RepaintBoundary(child: child),
    );
  }
}

// ── AppSurface ────────────────────────────────────────────────────────────────

/// A surface of any shape, including a circle.
///
/// This replaces `SkeuoSurface`, which existed because a `Border`-based bevel
/// *throws* at runtime when combined with a non-zero `borderRadius` or a circle —
/// a defect no linter sees, which is why it had its own paint test. A flat system
/// has no bevel, so the constraint disappears with it, and the name goes too:
/// "skeuo" named a theme that no longer exists.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.card,
    this.circle = false,
    this.fill,
    this.border = AppBorders.hairline,
    this.padding,
  });

  final Widget child;
  final double radius;

  /// Draw as a circle. [radius] is ignored; the shape takes the shorter side.
  final bool circle;

  /// Defaults to [AppSurfaces.surface].
  final Color? fill;

  /// Pass `BorderSide.none` for a surface that should not be outlined — a dot,
  /// a swatch, anything whose fill is the whole point.
  final BorderSide border;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: null,
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? AppSurfaces.surface,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius:
            circle ? null : BorderRadius.circular(radius),
        border: border == BorderSide.none ? null : Border.fromBorderSide(border),
      ),
      child: child,
    );
  }
}

// ── AppCard ───────────────────────────────────────────────────────────────────

/// The card every screen is built from.
///
/// **Flat by construction**: [AppSurfaces.surface] one step above the page, and
/// [AppBorders.hairline] around it. The old version's `card == page` identity is
/// gone and so is its reason — depth used to have to come from a shadow, and a
/// shadow on a same-coloured fill reads as a border, which is what the style
/// existed to avoid. Now the card is allowed to be its own colour and the
/// hairline is a real edge rather than a hint at one.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.semanticLabel,
    this.accent,
    this.inset = false,
    this.pressed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final String? semanticLabel;

  /// The theme accent, used for the hairline. Kept as a parameter because the
  /// previous version's doc comment made it a real one — a card could once be
  /// drawn with an accent that disagreed with the theme — and under a
  /// categorical system a card may legitimately carry its category's hue.
  final Color? accent;

  /// Cut the surface into the page instead of raising it off it. Input fields,
  /// and chips that are not selected.
  final bool inset;

  /// The pressed state of a control.
  ///
  /// **No geometry, and that is the whole change.** The pressed state used to
  /// swap a raised shadow pair for a `pressed` one, which is meaningful when a
  /// surface has thickness and meaningless when it does not. A press is now a
  /// step *darker*, which moves the fill away from the text rather than toward
  /// it — the direction rule that predates this system and survives it.
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    if (inset) {
      fill = AppSurfaces.surfaceAlt;
    } else if (pressed) {
      // A step toward the page. Darker, so contrast with [AppSurfaces.onSurface]
      // *improves* rather than degrades.
      fill = Color.lerp(AppSurfaces.surface, AppSurfaces.page, 0.35)!;
    } else {
      fill = AppSurfaces.surface;
    }

    final edge =
        (inset || accent == null) ? AppBorders.hairline : AppBorders.categoricalBorder(accent!);

    // The `Material` goes *between* the decorated box and the content, not
    // around the decorated box.
    //
    // A `Container` with a `BoxDecoration` paints its background on the same
    // layer as everything inside it, so a `Material` placed outside it is still
    // underneath: the card fill covers the ink layer, and anything inside with
    // its own ink — a `ListTile`, a `SwitchListTile`, an `InkWell` — loses its
    // splash and its hover state. Putting the Material inside the Container
    // makes the card fill paint first and the ink paint over it, which is the
    // order that works. `test/settings_screen_test.dart` catches this.
    //
    // `AnimatedContainer` because `pressed` is a flag on a stateless widget:
    // without it the fill steps on the frame the finger lands, which reads as a
    // flicker rather than a press. Idle cost is a controller that is not
    // ticking.
    final content = AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.enter,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.fromBorderSide(edge),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );

    // Keeps a card from re-rasterising when something above it moves; the eight
    // cards on a dashboard page are all inside one scrolling list.
    final card = RepaintBoundary(child: content);

    if (semanticLabel != null) {
      // **`excludeSemantics: true`, because the caller has written the better
      // sentence.** `container: true` creates a node but does not stop the
      // children being walked, so a screen reader read the caller's summary and
      // then went on to read every `Text` beneath it. The summary exists because
      // it is a better description than the concatenation of its parts.
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

// ── AppTile ───────────────────────────────────────────────────────────────────

/// A small block inside a card: a metric value, a legend entry, a legend dot.
///
/// It used to be a hand-written `BoxDecoration` with a low-alpha colour wash at
/// one of three different radii — 16 in the energy card, 14 in the energy report
/// totals, for the same conceptual object. This is that object, once.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.inset = true,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  /// A well (one step up the ramp) or a card (one step down from a card, for a
  /// tile inside a card). Defaults to the well, which is what a metric tile wants.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: inset ? AppSurfaces.surfaceAlt : AppSurfaces.input,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: accent == null
            ? null
            : Border.fromBorderSide(AppBorders.categoricalBorder(accent!)),
      ),
      child: child,
    );
  }
}

// ── AppBadge ──────────────────────────────────────────────────────────────────

/// A categorical pill: a 10%-alpha wash of the category's own hue behind a
/// full-strength foreground of the same hue.
///
/// **The one sanctioned way to put a hue behind text**, and it is a widget rather
/// than a convention because a hand-written `hue.withValues(alpha: 0.3)` behind a
/// caption is exactly the mistake that cost contrast in three previous design
/// systems in this app.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppBorders.categoricalWash(color),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: DefaultTextStyle.merge(
        style: AppType.labelMicro.copyWith(color: color),
        child: child,
      ),
    );
  }
}

// ── AppDivider ────────────────────────────────────────────────────────────────

/// A rule *between* two things inside a surface.
///
/// [AppBorders.hairline] is the default for drawing the outline of a thing;
/// this is for the case where there is no outline.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.height = 1, this.opacity = 1.0});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: appDivider(opacity: opacity),
    );
  }
}

// ── DateStripChip ─────────────────────────────────────────────────────────────

/// One day in the horizontal date strip. The brief's `chip` / `chip-active`.
///
/// **The active state is the brief's, not a derived one**: a solid categorical
/// fill with dark ink and *no* border. That is a change of kind rather than of
/// degree — the old version raised the selected chip off the page with a shadow
/// pair and dropped the unselected one into a well, and the difference between
/// them was a geometry. Here the difference is a fill and an ink colour.
class DateStripChip extends StatelessWidget {
  const DateStripChip({
    super.key,
    required this.dayName,
    required this.dayNumber,
    required this.isSelected,
    required this.onTap,
    this.width = 48,
  });

  final String dayName;
  final String dayNumber;
  final bool isSelected;
  final VoidCallback onTap;

  /// `minHeight`, not `height`, so the chip grows with the user's font scale.
  /// A fixed height here truncated the day number at the largest system font
  /// sizes, and the width is measured from the text for the same reason.
  final double width;

  @override
  Widget build(BuildContext context) {
    final fill = isSelected ? AppPalette.accent : AppSurfaces.surface;
    final ink = isSelected ? AppPalette.onHue : AppSurfaces.onSurfaceVariant;
    final numberInk = isSelected ? AppPalette.onHue : AppSurfaces.onSurface;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$dayName $dayNumber',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.press,
          curve: AppMotion.enter,
          width: width,
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            // The active chip has no border, per the brief. An outline round a
            // solid fill reads as a second, competing edge.
            border: isSelected
                ? null
                : Border.fromBorderSide(AppBorders.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(dayName.toUpperCase(), style: AppType.labelMicro.copyWith(color: ink)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dayNumber,
                  style: AppType.numeralLg.copyWith(color: numberInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary type. A function in the previous version because it took a
/// `bool isDark` and there were two dark ramps; with one ramp it is
/// [AppSurfaces.onSurface], and keeping a wrapper around a constant would be the
/// kind of vestigial signature that outlives the thing it was written for.
const Color appPrimaryText = AppSurfaces.onSurface;