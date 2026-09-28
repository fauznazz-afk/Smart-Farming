import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';

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
        final page = selectedIndex.toDouble();
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
          minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: LayoutBuilder(
                  builder: (context, constraints) => AnimatedContainer(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.centerLeft,
                    width: isCollapsed ? 64 : constraints.maxWidth,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.40)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xEE101412)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.07),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              ignoring: isCollapsed,
                              child: AnimatedOpacity(
                                opacity: isCollapsed ? 0 : 1,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOutCubic,
                                child: Row(
                                  children: [
                                    for (var i = 0;
                                        i < kNavDestinations.length;
                                        i++)
                                      _NavItem(
                                        index: i,
                                        destination: kNavDestinations[i],
                                        page: page,
                                        isDark: isDark,
                                        seedColor: seedColor,
                                        primary: primary,
                                        onTap: () => onSelect(i),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !isCollapsed,
                              child: AnimatedOpacity(
                                opacity: isCollapsed ? 1 : 0,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOutCubic,
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
        borderRadius: BorderRadius.circular(28),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Container(
              key: ValueKey(selectedIndex),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(destination.selectedIcon, size: 22, color: Colors.white),
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
    required this.page,
    required this.isDark,
    required this.seedColor,
    required this.primary,
    required this.onTap,
  });

  final int index;
  final NavDestination destination;
  final double page;
  final bool isDark;
  final Color seedColor;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = page.round() == index;
    final tint = metricColor(
      seedColor: seedColor,
      index: index,
      isDark: isDark,
    ).withValues(alpha: 0.72);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 64,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selected
                    ? _SelectedPill(
                        key: ValueKey('sel_$index'),
                        icon: destination.selectedIcon,
                        color: primary,
                      )
                    : Column(
                        key: ValueKey('unsel_$index'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(destination.icon, size: 20, color: tint),
                          const SizedBox(height: 2),
                          Text(
                            destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              // 11, not 8. Shrinking this to 8 was my suggestion
                              // and it was wrong: 11sp is `label-small`, the
                              // smallest style in the entire Material type scale,
                              // so 8px was off the scale entirely. Material 2 says
                              // "Don't shrink text to fit on a single line" and
                              // Material 3 says "Don't reduce the type size to fit
                              // more characters into a destination label".
                              //
                              // At 11sp "Hydroponics" measures 62dp and the slot is
                              // 60dp, so it still does not fit — which is the actual
                              // finding, and it is a tab-count problem rather than a
                              // font problem. Six slots at Material 2's documented
                              // 80dp portrait minimum need 480dp; this phone is
                              // 380dp. Fixing that means fewer tabs, not smaller
                              // text.
                              fontSize: 11,
                              color: tint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedPill extends StatelessWidget {
  const _SelectedPill({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}
