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
///
/// ## The captions are gone, and the labels survive as semantics
///
/// The user asked for the bar to stop printing a word under every icon, and it
/// does — nothing under a destination renders text any more. `label` stays on the
/// record because `_NavItem` and `_CollapsedNavItem` both hand it to
/// `Semantics(label:)`; a caption that cannot be seen is still a caption a screen
/// reader announces, and deleting the field would have taken that with it.
///
/// That is also what makes the four-tab count harder to revisit. The argument
/// above for four was partly that "Hydroponics" measured 62 dp in a 60 dp slot —
/// with no text on screen there is no label to collide, so the limit is now
/// touch-target pitch alone rather than the width of a word.
///
/// ## The glyphs, and why each one was replaced
///
/// The first set was `dashboard` / `bolt` / `eco` / `set_meal`. Two of the four
/// were wrong for what the page *is*, and one of them was wrong in a way that
/// only shows up when it is 24 dp tall:
///
///  - **`set_meal` is a plate of food.** It is Material's fish-on-a-dinner-plate
///    glyph, which reads as a menu rather than as an aquarium. The Fish page is
///    water quality — temperature, pH, turbidity — so the glyph is now `water`,
///    which is what the page actually reports on.
///  - **`dashboard` is a nine-square grid.** At 24 dp in a 72 dp slot the nine
///    squares turn into a grey smudge, and `space_dashboard` draws the same idea
///    as four panels with air between them, which survives being that small.
///  - `bolt` and `eco` were right and only their *style* changed. `Icons.bolt`
///    is a hairline zigzag and `Icons.eco` is a thin outline; both are the
///    Material 2 weight. `*_rounded` is the same glyph at the weight the rest of
///    the bar draws at, so an unselected tab is legible rather than merely
///    correct.
///
/// The set is `*_outlined` / `*_rounded` throughout, and it has to be: mixing
/// `Icons.bolt` with `Icons.space_dashboard` puts two different stroke weights
/// and two different corner languages in one 72 dp row.
const List<NavDestination> kNavDestinations = [
  NavDestination(
    Icons.space_dashboard_outlined,
    Icons.space_dashboard_rounded,
    'Overview',
  ),
  NavDestination(Icons.bolt_outlined, Icons.bolt_rounded, 'Power'),
  NavDestination(Icons.eco_outlined, Icons.eco_rounded, 'Hydroponics'),
  NavDestination(Icons.water_outlined, Icons.water_rounded, 'Fish'),
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
/// **64, down from 76.** The brief chose 76 — which is a coincidence worth
/// naming, because the literal `76` that caused the *original* defect was a
/// *wrong* 76. At 76 the bar reserved 24 dp on every page to hold a 24 dp icon
/// and a 10 sp label with "real air", and the air was mostly air.
///
/// The reduction is a third of the bar's height and it is not free: the
/// reservation shrinks with it, which is the whole point, and
/// `test/nav_bar_clearance_test.dart` is what proves the two halves moved
/// together rather than one being forgotten — which is exactly what went wrong
/// the first time a literal was written here.
///
/// The bar's own gap below it ([kGlassNavBarBottomGap]) is *not* part of the 64.
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
const double kGlassNavBarHeight = 64;

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
/// The brief's tab bar: a flat dark bar with a hairline border, active item =
/// `AppPalette.error` (red) with no pill background and no underline, inactive =
/// muted. No shadow pair, no gradient, no glass. No captions either — the bar is
/// four icons, and each one's name lives in its `Semantics` label.
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
                            // **A 4 dp margin inside each pitch.** The slots
                            // are `_kNavItemWidth` wide and sit
                            // `spaceEvenly`, so without a gap the pill's rounded
                            // ends butt straight into the first and last item's
                            // box — which is what makes a floating bar read as
                            // slightly cramped at the edges even when nothing
                            // overlaps.
                            kNavDestinations.length * _kNavItemWidth +
                                kNavDestinations.length * _kNavItemGap,
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
                      // **A stadium, not an 8px rectangle.** This was
                      // `AppRadius.card`, and the user's read on it was "masih
                      // kotak" — still square. That is a measurement, not a
                      // preference: 8 px on a bar 76 dp tall is a corner radius
                      // of 10% of the height, which at a phone's physical
                      // density is about two millimetres. It reads as a
                      // slightly chamfered rectangle, which is what it is.
                      //
                      // A tab bar is the one component in the app that is
                      // *floating* — it is `extendBody: true`, painted over the
                      // page, with a gap under it and page visible on both
                      // sides. A floating object with near-square corners does
                      // not read as floating; it reads as a strip that happens
                      // to be inset. `AppRadius.pill` is the token that already
                      // means "fully round" and it is what the pressed
                      // `InkWell` in `_NavItem` uses, so the ripple and the
                      // silhouette finally agree — the ripple was a capsule
                      // over a chamfered rectangle.
                      //
                      // The bar's own clip below carries the same value, and the
                      // test asserts the two are the same number, because that
                      // disagreement is invisible in the source and visible on
                      // the device.
                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
                                        // **The slot is `_kNavItemWidth` wide,
                                        // not 48.** A slot narrower than the
                                        // box the item lays out in clips it, and
                                        // the item draws its icon at 24 in a
                                        // `_kNavItemWidth` box — so a 48 dp slot
                                        // was already 4 dp too narrow for its own
                                        // child, which is the kind of thing that
                                        // reads as "the icon looks a bit off"
                                        // rather than as a bug.
                                        width: _kNavItemWidth,
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
                // Red, with the lime accent gone: see `_NavDestination`.
                color: AppPalette.error,
              ),
              // **`_kNavIconSize`, not 22.** The collapsed pill drew the same
              // glyphs as the expanded row at a different size, which meant the
              // tab you were on changed apparent size when the bar collapsed —
              // the one moment where the icon is the entire content.
              child: Icon(
                destination.selectedIcon,
                size: _kNavIconSize,
                // **`onHue` stays, and it is worth saying why against red.**
                // Its job is ink-on-fill, so it has to be re-measured rather than
                // assumed whenever the fill changes. Black on `#FF6B6B` is
                // 7.6:1 — comfortably past AA — because this red is light
                // (relative luminance 0.33). The white that "feels" like the
                // instrument-panel pairing is only 2.8:1 on the same fill, so
                // swapping to `AppSurfaces.onSurface` here would have made it
                // worse. The bar's own fill is a near-black page, so the white in
                // this design is the *ink*, not the ink-on-red.
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

/// A nav destination: the glyph alone, coloured by selection only.
///
/// **Icon-only.** The caption is gone at the user's request, so this is now a
/// centred icon in a `_kNavItemWidth` slot and nothing else — no `Column`, no
/// label, no `FittedBox`. The reason the last two were hard to remove is
/// preserved below, because the guard against their return is the thing that
/// matters now.
///
/// **The active item shifts colour and nothing else.** No pill, no underline, no
/// weight change — the brief's `tab-item-active` is `textColor: {colors.primary}`
/// with `backgroundColor: transparent`, and the inactive one is
/// `{colors.on-surface-variant}`. That is the whole difference, and it is why the
/// selected icon and the outline icon are the only two variants in play: the
/// brief's iconography is `solar bold` for both states, with the *filled* variant
/// reserved for the selected one.
///
/// **Red, not lime.** The accent is [AppPalette.error] (`#FF6B6B`) to match the
/// black+red instrument-panel design; the bar used to paint `AppPalette.primary`,
/// the lime. The label's *name* survives only as `NavDestination.label`, which is
/// now read solely by the `Semantics(label:)` on each item — a caption that is
/// invisible is still a caption a screen reader needs, and dropping the field would
/// have taken the accessibility label with it.
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
    final color = selected ? AppPalette.error : AppSurfaces.onSurfaceVariant;
    return Pressable(
      pressedScale: 0.90,
      builder: (pressed) => AnimatedContainer(
        duration: AppMotion.press,
        curve: AppMotion.enter,
        width: _kNavItemWidth,
        // **The icon is NOT inside a `FittedBox`, and that is the fix for
        // "the Hydroponics icon looks small".** The whole icon-plus-label column
        // used to be wrapped in one, so the *label* set the scale and the icon
        // came along for the ride. Measured at the device's own density:
        //
        //   Hydroponics  scale 0.36   (label natural width 123 dp)
        //   Overview     scale 0.49   ( 90 dp)
        //   Power        scale 0.79   ( 56 dp)
        //   Fish         scale 0.98   ( 45 dp)
        //
        // Four icons in one row, drawn at **0.36 / 0.49 / 0.79 / 0.98 of the size
        // they were declared at** — a 2.7x spread that tracked the length of the
        // word underneath and had nothing to do with the glyphs. The icon that
        // looked small was the one with the longest label, which is why nobody
        // found it by looking at the icons themselves.
        //
        // Deleting the label removes the *cause* of that scale rather than
        // fighting it, and `test/nav_bar_icon_size_test.dart` still measures the
        // painted width of all four icons — so a future re-wrap in a `FittedBox`
        // fails loudly instead of returning quietly.
        //
        // **`Center` is load-bearing here, and it replaced the `Column`.** The
        // column passed loose constraints down to its children, which is why an
        // `Icon` inside one drew at its declared size. Delete the column and the
        // slot's tight 40 dp reaches the icon directly, and `Icon` obeys it: every
        // glyph painted at the full slot width, which `test/nav_bar_icon_size_test`
        // caught as 40 dp against a declared 22.
        child: Center(
          child: Icon(
            selected ? selectedIcon : icon,
            size: _kNavIconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The air between two destinations, inside the pill.
///
/// **A constant because it is half of the bar's width arithmetic.** The pill is
/// `4 * _kNavItemWidth + 4 * _kNavItemGap` wide, and the `56` that used to be
/// written inline was that arithmetic done in the reader's head — which is how it
/// drifted from the 48-wide slot it was supposed to describe.
const double _kNavItemGap = 3;

/// The icon's drawn size, in one place.
///
/// **A constant rather than a literal at the call site**, because the collapsed
/// item draws the same glyph and the two used to carry their own numbers — so a
/// retune of one silently desynchronised the other.
///
/// **22, down from 24.** The bar is 12 dp shorter, so a 24 dp icon left the
/// label crowdable against the top and bottom edges. 22 keeps the icon
/// unmistakably larger than the 10 sp label without crowding it.
///
/// The label it was measured against is gone, so this number is now free to grow
/// and was deliberately *not* grown: the icon-size test reads the declared value
/// off the widget rather than pinning it, so a retune here is a design decision
/// rather than a test failure, and nothing in the brief asked for a bigger glyph.
const double _kNavIconSize = 22;

/// The width a destination is laid out in.
///
/// **40 dp, down from 46, because there is no longer a label to fit.** Every step
/// of this number so far has been argued in terms of the widest word underneath
/// the icon — `Hydroponics` is 123 dp of natural text — and that constraint is
/// gone. What is left is the ripple's `_kNavItemWidth` box, so the slot only has
/// to clear the 22 dp icon with air around it: 9 dp on each side.
///
/// The bar's width is this constant times the destination count plus the gap, and
/// that arithmetic lives in `GlassNavBar` rather than here, so the two halves move
/// together when this moves.
const double _kNavItemWidth = 40;

// There were two getters here — `destination` and `selectedIndex` — that
// recovered the label from the *icon* by searching [kNavDestinations] for the
// matching `selectedIcon`. Nothing called them: `_NavItem` already knows its
// `destination` and passes the parts down. They are gone rather than fixed,
// because a reverse lookup by icon is a landmine — the day two destinations share
// an icon, `indexWhere` silently returns the first one and the wrong label is
// drawn with nothing failing. The label is now a field, as it always should
// have been.
