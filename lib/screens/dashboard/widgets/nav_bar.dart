import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';

/// Destination shown in the glass bottom navigation bar.
class NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestination(this.icon, this.selectedIcon, this.label);
}

/// The five dashboard tabs, in navigation order.
const List<NavDestination> kNavDestinations = [
  NavDestination(Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
  NavDestination(Icons.wb_sunny_outlined, Icons.wb_sunny, 'PV'),
  NavDestination(Icons.power_outlined, Icons.power, 'AC'),
  NavDestination(
    Icons.battery_5_bar_outlined,
    Icons.battery_full,
    'Battery',
  ),
  NavDestination(Icons.videocam_outlined, Icons.videocam, 'CCTV'),
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
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                            style: TextStyle(
                              fontSize: 9,
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
