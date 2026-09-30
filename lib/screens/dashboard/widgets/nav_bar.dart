import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import '../utils/pressable.dart';

/// Destination shown in the glass bottom navigation bar.
class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestination(this.icon, this.selectedIcon, this.label);
}

/// The dashboard tabs, in navigation order.
///
/// Four, not six. Material 2 documents 80 dp as the minimum width of a
/// bottom-navigation destination in portrait; this phone is 380 dp, so six tabs
/// needed 480 dp and "Hydroponics" measured 62 dp in a 60 dp slot even at
/// `label-small`, the smallest style the Material type scale has. Material 3
/// states the limit and the symptom together: "the elements may collide and there
/// likely won't be enough space for translated text." Four tabs need 320 dp and
/// leave a slot spare for a seventh destination.
///
/// PV, AC and Battery are one tab with a selector inside it, because they are
/// three views of one electrical system. See `power_sub_tabs.dart`.
///
/// Labels are 11 sp and must stay at or above it. Both Material versions forbid
/// the two ways of making a long label fit: "Don't shrink text to fit on a single
/// line" and "Don't reduce the type size to fit more characters into a
/// destination label." Neither do they forbid the other escape route — "Don't
/// use multiple or low-contrast colors in a bottom navigation bar" — which is why
/// every tab here renders the same accent and is told apart by label and icon.
const List<NavDestination> kNavDestinations = [
  NavDestination(Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
  NavDestination(Icons.bolt_outlined, Icons.bolt, 'Power'),
  NavDestination(Icons.eco_outlined, Icons.eco, 'Hydroponics'),
  NavDestination(Icons.set_meal_outlined, Icons.set_meal, 'Fish'),
];

/// Floating glass navigation bar that collapses to a single button when the
/// user scrolls down, and expands again on scroll up or tap.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.isDark,
    required this.seedColor,
    required this.collapsed,
    required this.onSelect,
    required this.onExpand,
  });

  final int selectedIndex;
  final bool isDark;
  final Color seedColor;
  final ValueNotifier<bool> collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: collapsed,
      builder: (context, isCollapsed, _) {
        final primary = strongMetricColor(
          seedColor: seedColor,
          index: selectedIndex,
          isDark: isDark,
        );
        return SafeArea(
          top: false,
          // 10, not 16. Six tabs split the width with Expanded, so every point of
          // margin is a point taken from an already narrow slot. The bar used to
          // have five tabs and 16 dp of air; both had to give when the Hydroponics
          // and Fish tabs arrived.
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: LayoutBuilder(
                  builder: (context, constraints) => AnimatedContainer(
                    duration: AppMotion.container,
                    curve: AppMotion.both,
                    // The width animation stays. It is a layout animation, so a
                    // collapse re-lays out this subtree once per frame, and a
                    // transform-only replacement was evaluated and rejected:
                    //
                    //  * `Transform.scale` on the bar squashes the row, the
                    //    labels and the pill's own radius, so the pill stops
                    //    being a circle and "Hydroponics" deforms with it.
                    //  * Scaling only the shadow layer leaves the fill running
                    //    the full width underneath it.
                    //  * Clipping to the 64dp window with an opaque mask drawn
                    //    over the right-hand side cuts the bar's own drop shadow
                    //    off mid-blur. A hard shadow edge is visible in a way the
                    //    layout cost is not, and no test in the suite would have
                    //    caught it.
                    //
                    // What is true is that this is the only layout animation in
                    // the bar, that the whole bar sits inside the `RepaintBoundary`
                    // above, and that the shadows are interpolated per frame
                    // rather than rebuilt: `AnimatedContainer` lerps a
                    // `Decoration`, and `BoxDecoration.lerp` lerps `BoxShadow`.
                    alignment: Alignment.centerLeft,
                    // Sized to its contents, not to the screen.
                    //
                    // A full-width bar for four icons leaves a third of a phone
                    // with nothing in it, and the destinations are already
                    // named by the header of the page each one opens -- so the
                    // width was carrying no information. 56dp a slot is four
                    // times the icon with a 48dp target inside it, and the cap
                    // keeps it sane if a fifth tab ever arrives.
                    width: isCollapsed
                        ? 52
                        : math.min(
                            constraints.maxWidth,
                            kNavDestinations.length * 56.0,
                          ),
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      // The same dual-shadow pair every card in the app uses, so
                      // the bar is lit from the same place as the content above
                      // it. It had one `black @ 0.40` drop shadow and nothing
                      // catching light on the other side, which is the old
                      // glass model rather than the current one.
                      boxShadow: AppElevation.raised(isDark),
                    ),
                    // A `Material` here, before the `InkWell`s below, and not
                    // only at the Scaffold.
                    //
                    // The bar's own fill is opaque, and the nearest Material
                    // above it belongs to the Scaffold, whose ink layer paints
                    // *below* this Container. So the tap ripple on a nav item
                    // was drawn and then immediately covered: pressing a tab
                    // gave no feedback at all. It used to leak a trace because
                    // the fill was `0xEE101412` at 92% alpha, which is not a
                    // reason to keep a translucent bar.
                    //
                    // `MaterialType.transparency` rather than a real Material
                    // because the fill is already painted by the Container
                    // below; this one exists only to own the ink.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                        decoration: BoxDecoration(
                          // Opaque, like every other surface. It was
                          // `0xEE101412` and `white @ 0.92`, and the only thing
                          // those alphas revealed was the page — which
                          // `AppSurfaces.chrome` already steps away from by one
                          // value, so the translucency bought nothing.
                          color: AppSurfaces.chrome(isDark),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppElevation.hairline(
                              accent: primary,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              ignoring: isCollapsed,
                              child: AnimatedOpacity(
                                opacity: isCollapsed ? 0 : 1,
                                duration: AppMotion.state,
                                curve: AppMotion.both,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    for (var i = 0;
                                        i < kNavDestinations.length;
                                        i++)
                                      // Sized rather than `Expanded`, because
                                      // the bar is now as wide as its contents and
                                      // an `Expanded` inside an unbounded-looking
                                      // row would just re-inflate it back to the
                                      // full width. The 48 box is still the tap
                                      // target; the padding around it is the
                                      // breathing room that used to come from the
                                      // extra width.
                                      SizedBox(
                                        width: 48,
                                        child: _NavItem(
                                          index: i,
                                          destination: kNavDestinations[i],
                                          selectedIndex: selectedIndex,
                                          isDark: isDark,
                                          seedColor: seedColor,
                                          primary: primary,
                                          onTap: () => onSelect(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !isCollapsed,
                              child: AnimatedOpacity(
                                opacity: isCollapsed ? 1 : 0,
                                duration: AppMotion.state,
                                curve: AppMotion.both,
                                child: _CollapsedNavItem(
                                  selectedIndex: selectedIndex,
                                  isDark: isDark,
                                  primary: primary,
                                  onTap: onExpand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _CollapsedNavItem extends StatelessWidget {
  const _CollapsedNavItem({
    required this.selectedIndex,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  final int selectedIndex;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destination = kNavDestinations[selectedIndex];
    return Semantics(
      button: true,
      selected: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Center(
          child: Pressable(
            pressedScale: 0.90,
            builder: (pressed) => AnimatedContainer(
              duration: AppMotion.press,
              curve: AppMotion.enter,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The accent fill, and the one place a nav item is a *coloured*
                // surface: it is the only element in the bar that is not a
                // neutral, and it is what tells the user where they are. The
                // press flattens it into the bar, same as an expanded item.
                color: primary,
                boxShadow: pressed
                    ? AppElevation.pressed(isDark)
                    : AppElevation.raised(isDark),
              ),
              child: Icon(
                destination.selectedIcon,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.destination,
    required this.selectedIndex,
    required this.isDark,
    required this.seedColor,
    required this.primary,
    required this.onTap,
  });

  final int index;
  final NavDestination destination;

  /// The bar's selected tab, as the `int` it always was.
  ///
  /// This used to arrive as a `double page` and be compared with
  /// `page.round() == index`, which is a value converted to a double and
  /// rounded straight back to the integer it was created from. The round trip
  /// was for a sliding indicator that was never built, and it cost nothing to
  /// read and something to trust: any future non-integral value would have
  /// silently selected the nearest tab instead of none.
  final int selectedIndex;

  final bool isDark;
  final Color seedColor;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex == index;
    // This colour is used for the icon AND the 11sp w600 label, so it is text,
    // not decoration. It was the accent at alpha 0.72, which composites the
    // saturated accent over the chrome surface and lands near 3:1 in light mode
    // — under the 4.5:1 that applies below the 18.66px large-text floor.
    // `metricColor` is the measured accent at full strength; the alpha existed
    // to soften the icon, and softening is what cost the contrast.
    final tint = metricColor(
      seedColor: seedColor,
      index: index,
      isDark: isDark,
    );
    // Not `Expanded`. The bar is sized to its contents now, so an `Expanded`
    // here would ask for all the remaining width and put the bar straight back
    // to full screen -- which is exactly what it was before. The caller wraps
    // this in a fixed 48 box, so the tap target is unchanged.
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        // The bar's own pill radius, so a ripple on one item follows the
        // shape of the container it sits in rather than a bare 20 that
        // happened to match the old card radius.
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 52,
          child: Center(
            // The `AnimatedSwitcher` is gone and this is the interesting part
            // of that. It existed to cross-fade the selected circle and the bare
            // icon, which is right for a *selection change* — but it also
            // re-ran on every press, because selecting is a press. So tapping
            // the tab you are already on started a 200ms cross-fade between
            // two copies of the same circle, and the old shadow list did not
            // match the new one, so the circle flickered through an
            // interpolated pair on the way.
            //
            // The icon is now always the same widget and only its colour and
            // glyph change, which is an `AnimatedDefaultTextStyle`-sized
            // problem rather than a subtree swap. Selection still animates --
            // through the shadow pair, which is the thing that actually carries
            // the difference.
            child: _NavDestination(
              selected: selected,
              primary: primary,
              tint: tint,
              isDark: isDark,
              selectedIcon: destination.selectedIcon,
              icon: destination.icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// The pressed state of a nav destination.
///
/// **The bar had a ripple and nothing else, and on this surface a ripple is
/// close to invisible** — the icon is a flat 22dp glyph on a flat chrome fill,
/// the splash is a low-alpha wash of the same hue, and both sit inside a
/// transparent `Material` over an opaque fill. A pressed tab looked like the app
/// had dropped a frame.
///
/// What it needed was a *geometric* change, not a colour one, and it is the same
/// distinction the date chips make: the selected circle is a raised block, so
/// pressing it flattens it into the bar, while an unselected icon has nothing to
/// flatten, so pressing it cuts a well around itself. Using one pair for both
/// would mean either a block that sinks or a well that pops out, and only one of
/// those is what the finger asked for.
class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.selected,
    required this.primary,
    required this.tint,
    required this.isDark,
    required this.selectedIcon,
    required this.icon,
  });

  final bool selected;
  final Color primary;
  final Color tint;
  final bool isDark;
  final IconData selectedIcon;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      // 0.90 rather than the 0.985 default: this is the smallest tap target in
      // the app's chrome and it is already flush inside a 52dp pill, so it has
      // to give noticeably for the press to register at all.
      pressedScale: 0.90,
      builder: (pressed) => AnimatedContainer(
        duration: AppMotion.press,
        curve: AppMotion.enter,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Transparent rather than the chrome fill: the bar's own fill is
          // already painted behind this, and filling it again would put an
          // opaque disc over the pill's shadow where the two meet.
          color: Colors.transparent,
          boxShadow: !pressed
              ? null
              : (selected
                  // A block coming up off the page flattens into it.
                  ? AppElevation.pressed(isDark)
                  // An icon with no block of its own gains one that is cut in.
                  : AppElevation.insetDeep(isDark)),
        ),
        child: Icon(
          selected ? selectedIcon : icon,
          size: 22,
          color: selected ? primary : tint,
        ),
      ),
    );
  }
}

