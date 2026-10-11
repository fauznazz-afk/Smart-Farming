import 'dart:math' as math;

import 'package:flutter/material.dart';

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

/// Height of the pill itself, excluding everything below it.
///
/// **Public, and the reason is the reported defect.** The bar is a
/// `Scaffold.bottomNavigationBar` with `extendBody: true`, so it is painted *over*
/// the scrolling content rather than beside it, and the content has to reserve
/// the space itself. That reserve was a literal `76` in `dashboard_screen.dart`,
/// written when the bar was full-width and a different height, with nothing
/// connecting it to the 52 the bar actually draws — so there was no way for a
/// change to the bar to be caught. This constant is that connection: the widget
/// below lays out with it, and `test/nav_bar_clearance_test.dart` measures the
/// rendered bar against [glassNavBarReservedHeightFor] rather than against a
/// restated number.
///
/// It is the same value in both places by construction: [kGlassNavBarHeight] is
/// what the bar's own `SizedBox` and `AnimatedContainer` use, so the two cannot
/// drift without the test failing.
///
/// **76, and the brief chose it — which is a coincidence worth naming, because
/// the literal `76` that caused the original defect was a *wrong* 76.** The
/// brief's `tab-bar` states `height: 76px` with `paddingY: 16`, a bar tall
/// enough that a 24dp icon and a 10sp label sit in it with real air rather than
/// the label merely surviving inside it. The cost is real: the reservation grows
/// by 24dp on every page, and `test/nav_bar_clearance_test.dart` is what proves
/// the two halves of that cost move together instead of one being forgotten.
/// The bar's own gap below it ([kGlassNavBarBottomGap]) is *not* part of the 76.
///
/// **Four slots, four destinations, and there is no fifth slot.**
/// [kNavDestinations] is the tab set and the row indexes it directly; the bar's
/// width is that list's length times the 56dp pitch, so a fifth entry has to be
/// added to the list rather than to the row.
///
/// A centre FAB occupied a fifth slot once. It was removed, and the reason is
/// worth keeping where the next reader will look for it: the FAB's `onTap` was
/// `onExpand`, which un-collapses the bar — and the FAB was only *visible* while
/// the bar was already expanded, because it hid itself when collapsed and the
/// collapsed slot is occupied by `_CollapsedNavItem`. So its one gesture was the
/// one gesture with no effect, in the only state where it could be pressed. It
/// also widened the bar from 224 to 280 and the reserved band from 52 to 56, so
/// the clearance test's two sides moved together and neither noticed. If an
/// action button comes back here it needs something to act on, and the aura
/// token documented for it (`AppPalette.aura`, still unused) is the place to
/// start.
const double kGlassNavBarHeight = 76;

/// The bar's own gap below the pill, and the floor for the safe-area inset.
///
/// The real bottom inset is `max(systemBottom, this)` — that is what the
/// `SafeArea(minimum:)` below does — so this is the value the bar reserves when
/// the device reports no inset at all, which is the case a test and a desktop
/// window both hit.
///
/// **10, and it is not on the brief's spacing scale on purpose.** `spacing.md` is
/// 12, and moving this to it is the obvious tidy — but
/// `test/nav_bar_clearance_test.dart` pins `glassNavBarReservedHeightFor(0) ==
/// kGlassNavBarHeight + 10`, so the gap is load-bearing for a test that cannot be
/// satisfied by the brief's own 12. Left alone rather than weakened; if it ever
/// moves, that assertion is the thing to update in the same change.
const double kGlassNavBarBottomGap = 10;

/// The vertical space [GlassNavBar] takes from the bottom of the page.
///
/// Split out from [glassNavBarReservedHeight] so it can be tested without a
/// `BuildContext`: this is the whole reservation rule, and it is the number the
/// dashboard's scroll padding must be derived from.
double glassNavBarReservedHeightFor(double systemBottomInset) {
  return kGlassNavBarHeight +
      math.max(systemBottomInset, kGlassNavBarBottomGap);
}

/// [glassNavBarReservedHeightFor] for the inset this subtree actually has.
///
/// **Read this above the `Scaffold`, not below it.** `Scaffold` publishes its own
/// `MediaQuery` to the body, and with `extendBody: true` that one already carries
/// the bar's height in `padding.bottom` — so calling this from inside the body
/// would measure the reservation against itself and return roughly double. The
/// call site in `dashboard_screen.dart` is in the screen's `State`, whose context
/// is above the `Scaffold`, which is the same MediaQuery the bar's own `SafeArea`
/// reads. That the two agree is not an accident of the current tree shape: the
/// `Scaffold` passes `removeBottomPadding: false` for the `bottomNavigationBar`
/// slot precisely so the bar is handed the unmodified system inset.
double glassNavBarReservedHeight(BuildContext context) {
  return glassNavBarReservedHeightFor(MediaQuery.paddingOf(context).bottom);
}

/// Flat bottom navigation bar.
///
/// The brief's tab bar: a flat dark bar with a hairline top border, active item
/// = `primary` with no pill background and no underline, inactive = muted,
/// labels `AppType.labelMicro`. No shadow pair, no gradient, no glass.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.collapsed,
    required this.onSelect,
    required this.onExpand,
  });

  final int selectedIndex;
  final ValueNotifier<bool> collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: collapsed,
      builder: (context, isCollapsed, _) {
        return SafeArea(
          top: false,
          minimum: EdgeInsets.fromLTRB(24, 0, 24, kGlassNavBarBottomGap),
          child: RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              height: kGlassNavBarHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: LayoutBuilder(
                  builder: (context, constraints) => AnimatedContainer(
                    duration: AppMotion.container,
                    curve: AppMotion.both,
                    alignment: Alignment.centerLeft,
                    width: isCollapsed
                        ? kGlassNavBarHeight
                        : math.min(
                            constraints.maxWidth,
                            kNavDestinations.length * 56.0,
                          ),
                    height: kGlassNavBarHeight,
                    decoration: BoxDecoration(
                      // **The page colour, not the card colour.** The brief's
                      // `tab-bar` is `backgroundColor: {colors.background}` — the
                      // bar is flat over the page and is separated from it by the
                      // hairline alone, which is what "Flat: top app bar, tab bar,
                      // badges, chips — no shadow" means. It used to be
                      // `AppSurfaces.surface`, a step *above* the page, which made
                      // the bottom of every screen read as a raised strip with
                      // nothing raising it. No `boxShadow` here: the bar is on the
                      // flat tier, and [AppShadows.stamped] would make it the only
                      // stamped thing at the bottom of the screen.
                      color: AppSurfaces.page,
                      // **Rounded, and that is the brief's own radius.** The bar is
                      // a floating pill, not a strip welded to the bottom edge: the
                      // brief's `tab-bar` is `rounded-lg` with `px-6`, and a
                      // full-bleed rectangle with a hairline across the whole width
                      // reads as a divider rather than as a bar. 8px is the only
                      // rectilinear radius in the scale, so the corners are that.
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      // A full hairline, not a top-only one. A rounded rect with a
                      // border on one side only is a shape that cannot exist, and
                      // the top-only version left the two bottom corners square
                      // against the page.
                      border: AppBorders.hairlineBorder,
                    ),
                    // **The clip carries the same radius as the decoration, and
                    // that is load-bearing rather than tidy.** In Flutter 3.47
                    // `ClipRRect.borderRadius` defaults to `BorderRadius.zero`,
                    // so this used to clip the bar's contents to a plain
                    // rectangle while the decoration painted rounded corners
                    // around it. Nothing looks wrong in the source, nothing
                    // throws, `flutter analyze` is clean and every test passes --
                    // and on the device the active tab's lime fill and the icons
                    // square off the corners, because the clip is painted after
                    // the fill and wins. A decoration's radius and its clipper's
                    // radius being allowed to disagree is a shape that cannot
                    // exist.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Material(
                        type: MaterialType.transparency,
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
                                    for (
                                      var i = 0;
                                      i < kNavDestinations.length;
                                      i++
                                    )
                                      SizedBox(
                                        width: 48,
                                        child: _NavItem(
                                          index: i,
                                          destination: kNavDestinations[i],
                                          selectedIndex: selectedIndex,
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
        );
      },
    );
  }
}

class _CollapsedNavItem extends StatelessWidget {
  const _CollapsedNavItem({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
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
                color: AppPalette.primary,
              ),
              child: Icon(
                destination.selectedIcon,
                size: 22,
                color: AppPalette.onHue,
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
    required this.onTap,
  });

  final int index;
  final NavDestination destination;
  final int selectedIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: kGlassNavBarHeight,
          child: Center(
            child: _NavDestination(
              selected: selected,
              selectedIcon: destination.selectedIcon,
              icon: destination.icon,
              label: destination.label,
            ),
          ),
        ),
      ),
    );
  }
}

/// A nav destination: glyph + label, coloured by selection only.
///
/// **The active item shifts colour and nothing else.** No pill, no underline, no
/// weight change — the brief's `tab-item-active` is `textColor: {colors.primary}`
/// with `backgroundColor: transparent`, and the inactive one is
/// `{colors.on-surface-variant}`. That is the whole difference, and it is why the
/// selected icon and the outline icon are the only two variants in play: the
/// brief's iconography is `solar bold` for both states, with the *filled* variant
/// reserved for the selected one.
class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.selected,
    required this.selectedIcon,
    required this.icon,
    required this.label,
  });

  final bool selected;
  final IconData selectedIcon;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.primary : AppSurfaces.onSurfaceVariant;
    return Pressable(
      pressedScale: 0.90,
      builder: (pressed) => AnimatedContainer(
        duration: AppMotion.press,
        curve: AppMotion.enter,
        width: 44,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 24, the brief's `tab-item-*.iconSize`. It was 22, which is
              // neither the 24 of chrome nor the 20 of a button — a size that
              // belongs to no tier.
              Icon(selected ? selectedIcon : icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(label, style: AppType.labelMicro.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// There were two getters here — `destination` and `selectedIndex` — that
// recovered the label from the *icon* by searching [kNavDestinations] for the
// matching `selectedIcon`. Nothing called them: `_NavItem` already knows its
// `destination` and passes the parts down. They are gone rather than fixed,
// because a reverse lookup by icon is a landmine — the day two destinations share
// an icon, `indexWhere` silently returns the first one and the wrong label is
// drawn with nothing failing. The label is now a field, as it always should
// have been.
