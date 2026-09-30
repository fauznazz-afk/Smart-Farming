import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

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
          minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              height: 64,
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
                    width: isCollapsed ? 64 : constraints.maxWidth,
                    height: 64,
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
                                  children: [
                                    for (var i = 0;
                                        i < kNavDestinations.length;
                                        i++)
                                      _NavItem(
                                        index: i,
                                        destination: kNavDestinations[i],
                                        selectedIndex: selectedIndex,
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
          child: AnimatedSwitcher(
            duration: AppMotion.state,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            child: _SelectedCircle(
              key: ValueKey(selectedIndex),
              icon: destination.selectedIcon,
              color: primary,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected destination's circle, in whichever bar state is showing.
///
/// 48dp, not 44. The Material floor is 48 and 44 was four under it, which is
/// not a rounding difference but a genuinely smaller target — and a soft-UI
/// control with no inner padding reads smaller than its box already, so the
/// visible ring matters as much as the hit area. The 64dp bar leaves 8dp of air
/// either side, so nothing had to move to make room.
class _SelectedCircle extends StatelessWidget {
  const _SelectedCircle({
    super.key,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        // The app's raised pair, not a coloured glow in the fill's own hue.
        // The glow was a second shadow vocabulary: warm, tight and pointing at
        // the light shadow, on a control whose every neighbour is lit from the
        // top left. It is also invisible on a light page, where a saturated
        // accent's glow has nothing darker than itself to sit against.
        boxShadow: AppElevation.raised(isDark),
      ),
      child: Icon(icon, size: 22, color: Colors.white),
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
    return Expanded(
      child: Semantics(
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
            height: 64,
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.state,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: selected
                    ? _SelectedCircle(
                        key: ValueKey('sel_$index'),
                        icon: destination.selectedIcon,
                        color: primary,
                        isDark: isDark,
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

