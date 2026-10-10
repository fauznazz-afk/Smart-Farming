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
/// It is the same 52 in both places deliberately: [kGlassNavBarHeight] is what
/// the bar's own `SizedBox` and `AnimatedContainer` use, so the two cannot
/// drift without the test failing.
const double kGlassNavBarHeight = 52;

/// The bar's own gap below the pill, and the floor for the safe-area inset.
///
/// The real bottom inset is `max(systemBottom, this)` — that is what the
/// `SafeArea(minimum:)` below does — so this is the value the bar reserves when
/// the device reports no inset at all, which is the case a test and a desktop
/// window both hit.
const double kGlassNavBarBottomGap = 10;

/// The vertical space [GlassNavBar] takes from the bottom of the page.
///
/// Split out from [glassNavBarReservedHeight] so it can be tested without a
/// `BuildContext`: this is the whole reservation rule, and it is the number the
/// dashboard's scroll padding must be derived from.
double glassNavBarReservedHeightFor(double systemBottomInset) {
  return kGlassNavBarHeight + math.max(systemBottomInset, kGlassNavBarBottomGap);
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
                      color: AppSurfaces.surface,
                      border: const Border(top: AppBorders.hairline),
                    ),
                    child: ClipRRect(
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
                                    for (var i = 0;
                                        i < kNavDestinations.length;
                                        i++)
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
  const _CollapsedNavItem({
    required this.selectedIndex,
    required this.onTap,
  });

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
            ),
          ),
        ),
      ),
    );
  }
}

/// A nav destination: glyph + label, coloured by selection only.
class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.selected,
    required this.selectedIcon,
    required this.icon,
  });

  final bool selected;
  final IconData selectedIcon;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.primary : AppSurfaces.onSurfaceVariant;
    return Pressable(
      pressedScale: 0.90,
      builder: (pressed) => AnimatedContainer(
        duration: AppMotion.press,
        curve: AppMotion.enter,
        width: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: AppType.labelMicro.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  NavDestination get destination =>
      kNavDestinations[selectedIndex];
  int get selectedIndex =>
      kNavDestinations.indexWhere(
        (d) => d.selectedIcon == selectedIcon,
      );
}
