import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_motion.dart';
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
/// **54, down from 76.** The brief chose 76 — which is a coincidence worth
/// naming, because the literal `76` that caused the *original* defect was a
/// *wrong* 76. At 76 the bar reserved 24 dp on every page to hold a 24 dp icon
/// and a 10 sp label with "real air", and the air was mostly air.
///
/// **54 is where a second reduction stopped.** The user called the 64 version
/// "masih agak mengganggu … lebih ke bulky" — still bulky — and height is what
/// makes a bar bulky: at 54 the pill is 26 dp above and below a 22 dp glyph,
/// which reads as a floating capsule rather than a slab, and a generous corner
/// radius at that height is a shape rather than a chamfer.
///
/// It stops at 54 rather than going lower because **the bar's height is also
/// the vertical touch target** — `_NavItem`'s `InkWell` fills a
/// `SizedBox(height: kGlassNavBarHeight)`, so the slot is 36 x 54 dp. 54 is the
/// point below which the target drops under Material's 44 dp and the user
/// trades a cosmetic complaint for a reachability one. Shrinking the icon to
/// buy the last few dp was rejected: the glyph is the entire content now the
/// captions are gone.
///
/// The reduction is not free: the reservation shrinks with it, which is the
/// whole point, and `test/nav_bar_clearance_test.dart` is what proves the two
/// halves moved together rather than one being forgotten — which is exactly
/// what went wrong the first time a literal was written here.
///
/// The bar's own gap below it ([kGlassNavBarBottomGap]) is *not* part of the 54.
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
const double kGlassNavBarHeight = 54;

/// The bar's own gap below the bar, and the floor for the safe-area inset.
///
/// **0, because the bar is docked and not floating.** It was 10, and it existed
/// to hold a capsule clear of the page's bottom edge. A docked bar is separated
/// from the page by its own hairline, so there is nothing to hold clear of and
/// the gap was 10 dp of page showing under a bar the user asked to be part of
/// the page.
const double kGlassNavBarBottomGap = 0;

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
/// is above the `Scaffold`, which is the same MediaQuery the bar itself reads.
/// That the two agree is not an accident of the current tree shape: the
/// `Scaffold` passes `removeBottomPadding: false` for the `bottomNavigationBar`
/// slot precisely so the bar is handed the unmodified system inset — the same
/// number `GlassNavBar` reads for the glass it paints down into that strip.
double glassNavBarReservedHeight(BuildContext context) {
  return glassNavBarReservedHeightFor(MediaQuery.paddingOf(context).bottom);
}

/// Flat bottom navigation bar.
///
/// The brief's tab bar: a flat bar with a hairline border, painted as glass
/// over the page gradient, active item = `AppPalette.accent` on a pill bubble
/// with no underline, inactive = muted glass ink. No shadow pair, no gradient
/// of its own. No captions either — the bar is four icons, and each one's name
/// lives in its `Semantics` label.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // **The bottom inset, read here and painted over.**
    //
    // `Scaffold` hands the `bottomNavigationBar` slot an unmodified MediaQuery
    // (`removeBottomPadding: false` for that slot), so this is the real system
    // strip — the same number `glassNavBarReservedHeight` reads above the
    // Scaffold, which is why the two agree. `viewPaddingOf` would *not*: the
    // fixtures in `nav_bar_clearance_test` and `nav_bar_icon_size_test` inject
    // `MediaQueryData(padding: ...)` with a zero `viewPadding`, so it reads 0
    // there and the bar would silently lose the strip the tests measure for.
    //
    // It was a `SafeArea` above a 54 dp `SizedBox`, which put the inset *outside*
    // the decoration: the gesture-handle strip showed the Scaffold's own
    // background instead of glass, and against a page gradient that is a hard
    // horizontal seam across the bottom of the screen — the reported defect.
    // The inset is now padding *inside* the decorated box, so the glass reaches
    // the bottom edge. Total height is unchanged at
    // `kGlassNavBarHeight + inset`, so `glassNavBarReservedHeightFor` and
    // `nav_bar_clearance_test`'s measured-height claim still hold.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight =
        kGlassNavBarHeight + math.max(bottomInset, kGlassNavBarBottomGap);

    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: totalHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // **One slot width, shared by the row and the bubble.**
              //
              // The row used `Expanded` across the bar's full width, which put
              // the four icons a quarter of a 360 dp screen apart — 90 dp
              // between centres for a 22 dp glyph, which reads as four things
              // that belong to four different bars rather than one navigation.
              // The bar's own width is not the destinations' width; it is the
              // *floor*, used only when the screen is too narrow to hold the
              // preferred pitch, which is the same clamp-and-centre rule the
              // `min` below is for.
              final slot = math.min(
                _kNavSlotWidth,
                constraints.maxWidth / kNavDestinations.length,
              );
              final rowWidth = slot * kNavDestinations.length;
              final rowLeft = (constraints.maxWidth - rowWidth) / 2;

              return AnimatedContainer(
                duration: AppMotion.container,
                curve: AppMotion.both,
                alignment: Alignment.centerLeft,
                // **Always the full width.** It used to shrink to
                // `kGlassNavBarHeight` when collapsed, which is a pill
                // floating at the bottom-left corner — a shape that only
                // exists while floating.
                width: constraints.maxWidth,
                height: totalHeight,
                // **The inset is padding on the *inside*.** This is the fix:
                // `Container` paints its decoration across the whole box and
                // only then insets the child, so the glass covers the gesture
                // strip and the row never moves down into it.
                padding: EdgeInsets.only(
                  bottom: totalHeight - kGlassNavBarHeight,
                ),
                decoration: BoxDecoration(
                  // **Glass over the page gradient, not a flat fill of it.**
                  //
                  // The bar used to paint `AppSurfaces.page` outright, which
                  // was right while the page was one flat colour: bar and page
                  // were the same value and only the hairline separated them.
                  // The page is a gradient slot even though WattVision flattens
                  // it, so painting its mid-tone here would lay a rectangle of a
                  // slightly different shade across the bottom of the screen
                  // with a visible seam at the join — the one place on a phone
                  // the user's thumb rests, and so the one place a seam is most
                  // legible.
                  //
                  // Translucent white over the gradient lets the sweep continue
                  // through the bar, which is the reason the rest of the screen
                  // is built this way at all.
                  // **A dark glass, not the white chip wash.** `fillStrong`
                  // is white 68%, which over the flat #121212 page resolves to a
                  // pale grey bar — a light element docked on a dark app, which
                  // is what "navigasi belum berubah dark" was seeing. The bar is
                  // the page's own layer, so it takes the page tone lifted a
                  // step: still translucent, still a surface, but dark.
                  // **`surface`, not `surfaceAlt`.** `surfaceAlt` is #252525
                  // over a #121212 page, so the docked bar read as a lighter
                  // grey slab taped to the bottom — still "not the dark theme"
                  // to the eye even after the white wash went away. A
                  // bottom-docked bar in this design system is the page's own
                  // layer lifted by one *card* step, so it takes the sheet
                  // surface and lets the hairline do the separating.
                  color: AppSurfaces.surface,
                  // **Rounded at the top, flush at the bottom, and the sheet's
                  // radius rather than the card's.**
                  //
                  // It used to be `BorderRadius.zero` on the argument that a
                  // docked bar's corners are off-screen, so the radius has
                  // nothing to describe. That is only true of the *bottom* two.
                  // The bar is `extendBody: true`, so its top corners sit in the
                  // middle of the page with the page visible on either side of
                  // them — and square, which is what read as "too square at the
                  // bottom" rather than as a bar. The bottom two stay flush:
                  // rounding them would cut the gesture-bar inset out of the
                  // shape.
                  //
                  // `AppRadius.sheet` rather than `AppRadius.card`, because a bar
                  // is a larger object than a card and a card-sized corner on it
                  // reads as a chamfered rectangle rather than as a rounded edge.
                  // The bar's own clip below carries the same value, and the test
                  // asserts the two are the same number, because that
                  // disagreement is invisible in the source and visible on the
                  // device.
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                  // **A top hairline only.** A docked bar's left, right and
                  // bottom edges are the page's own edges — a border there
                  // is a line drawn along the screen.
                  // A white hairline, not the neutral one: over the glass bar a
                  // slate border reads as dirt, where a translucent white reads
                  // as an edge.
                  border: Border(
                    top: BorderSide(color: AppGlass.divider, width: 1),
                  ),
                ),
                // **The clip matches the decoration, and still has to be stated.**
                // In Flutter 3.47 `ClipRRect.borderRadius` defaults to
                // `BorderRadius.zero`, so this used to clip the contents to
                // a plain rectangle while the decoration painted rounded
                // corners around it — invisible in the source, clean under
                // `flutter analyze`, and wrong on the device because the
                // clip is painted after the fill and wins.
                // The radius below is the same value as the decoration's, and
                // `nav_bar_clearance_test` asserts the two agree.
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // **The accent bubble, and it travels.** It is a single
                        // widget positioned by its index rather than one bubble
                        // per slot with a crossfade, because a crossfade draws
                        // two bubbles fading through each other while the user
                        // is swiping — the icon they are dragging toward appears
                        // twice, and neither copy is where their finger is. One
                        // widget moving is the animation they asked for.
                        //
                        // **`AnimatedPositioned`, not `AnimatedAlign`, and the
                        // difference is 16.5 dp.** `Align` places its child by
                        // `(W - childW) * ((alignment.x + 1) / 2)` — the child's
                        // *leading edge* lands on that fraction of the parent,
                        // not its centre. Solving for a centre put the first
                        // bubble at 116.5 in an 800-wide bar whose first icon is
                        // at 100, and it looked like a layout that was nearly
                        // right. Positioning the bubble over the whole slot and
                        // centring the disc inside it is exact by construction:
                        // the slot and the row's `SizedBox` are the same number.
                        //
                        // **`Curves.easeInOutCubic`, not [AppMotion.both], and
                        // that is the smoothness.** `both` is `easeInCubic` — it
                        // leaves the origin at walking pace and arrives at full
                        // speed before stopping, which is the right feel for
                        // something appearing and the wrong feel for something
                        // travelling. A 192 dp slide read as a lurch. Symmetric
                        // ease-in-out is a glide.
                        //
                        // **[AppMotionTab], and the bubble is not on a clock of
                        // its own.** The dashboard's page slide runs on the same
                        // duration and the same curve, so the bubble and the
                        // content it points at leave together and arrive
                        // together. The bubble was already on this clock; the
                        // page slide was the half that was 40 ms short and
                        // that started halfway through its own animation,
                        // because the selection was applied on the page
                        // change rather than on the tap — so the tab read as
                        // two events, the content arriving and then the
                        // bubble catching up.
                        AnimatedPositioned(
                          key: const ValueKey('nav-accent-bubble'),
                          duration: AppMotionTab.duration,
                          curve: AppMotionTab.curve,
                          left: rowLeft + slot * selectedIndex,
                          top: 0,
                          width: slot,
                          height: kGlassNavBarHeight,
                          child: const _NavBubble(),
                        ),
                        // **No collapse state, and this is the deletion rather
                        // than an omission.** There used to be a vertical-scroll
                        // collapse that crossfaded all four icons out and one
                        // enlarged icon in, at the bottom-left. It is gone: the
                        // bar keeps all four icons at all times, so the collapse
                        // had nothing to do and its notifier, its `_downScrollDistance`
                        // accumulator and its ~54-line `_CollapsedNavItem` all
                        // went with it. A bar that hides its own destinations on
                        // scroll is a bar you cannot tap your way back out of.
                        // **The row is `rowWidth` wide and centred, not
                        // `Expanded` across the bar.** Two numbers describe the
                        // same slots — `slot` here and `slot` in the bubble —
                        // and they are the same variable, so the bubble cannot
                        // drift off its icon the way a second, independently
                        // written slot width would.
                        Center(
                          child: SizedBox(
                            width: rowWidth,
                            child: Row(
                              children: [
                                for (
                                  var i = 0;
                                  i < kNavDestinations.length;
                                  i++
                                )
                                  Expanded(
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
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ),
    );
  }
}

/// The accent disc the selected tab's icon sits on.
///
/// **A constant 44, and it is the bar's height minus 10.** A bubble that fills
/// the bar touches both hairlines and reads as a selected *region* rather than a
/// selected *tab*; the air is what makes it an object sitting on the bar.
class _NavBubble extends StatelessWidget {
  const _NavBubble();

  @override
  Widget build(BuildContext context) {
    // **Centred in a full slot, not a 44 dp box at a computed offset.** The
    // caller already knows the slot's rectangle, so handing it the slot and
    // centring the disc is one fewer number to keep in agreement with the
    // `Row` — and the number is 44, the same constant `_kNavIconSize` sits
    // inside, so the disc cannot end up narrower than the glyph it carries.
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppPalette.accent,
        ),
        child: const SizedBox(width: 44, height: 44),
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
/// **The active item is ink on the accent bubble, not a coloured glyph.**
/// Selection used to be "the icon turns red", and there was no fill behind it.
/// The bar now paints [_NavBubble] behind the selected slot, so the selected
/// glyph has to be [AppPalette.onHue] — the same token the bubble's ink was
/// measured with. The bubble is the accent: on WattVision's bright cyan the
/// token ink is dark `#121212`, and the ink follows the fill rather than being
/// picked. The token is what keeps the two in step.
///
/// The inactive glyph is `AppGlass.navInkSoft`, because the bar is a glass
/// surface and the ink on glass is the token that follows the wash.
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
    // **`onHue`, not `accent`.** The bubble is behind this glyph, so accent ink
    // on an accent fill is accent-on-accent. See the class doc.
    // **`navInkSoft` is the white-chip ink and is wrong here now.** The bar is
    // a dark surface (see the decoration in `build`), so the inactive glyph
    // takes the page ink it is docked on; a navy glyph on a navy bar was the
    // other half of "navigasi belum berubah dark".
    final color = selected ? AppPalette.onHue : AppSurfaces.onSurfaceVariant;
    return Pressable(
      pressedScale: 0.90,
      builder: (pressed) => AnimatedContainer(
        // **The bubble's own duration and curve, and this is what makes the
        // travel read as one movement.** The colour was on `AppMotion.press`
        // (150 ms, `easeOutCubic`) while the bubble takes the tab clock
        // (`AppMotionTab`), so the glyph turned to its ink long before the disc
        // arrived — a white glyph on a white page for most of the slide, then
        // the red disc catching up with an icon that was already the right
        // colour. Two halves of one gesture have to be on the same clock, and
        // this is that clock: the glyph, the disc and the page behind them all
        // run on [AppMotionTab].
        duration: AppMotionTab.duration,
        curve: AppMotionTab.curve,
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

/// The icon's drawn size, in one place.
///
/// **A constant rather than a literal at the call site**, because the collapsed
/// item draws the same glyph and the two used to carry their own numbers — so a
/// retune of one silently desynchronised the other.
///
/// **22, down from 24, and deliberately *not* reduced with the bar.** A 24 dp
/// icon in the original 76 dp bar left the label crowdable against the top and
/// bottom edges. The captions are gone now, so the glyph is the entire content
/// of a destination: it was left at 22 while the bar went 76 -> 64 -> 54,
/// because shrinking it further would make the bar smaller at the cost of the
/// only thing it still shows.
///
/// The label it was measured against is gone, so this number is now free to grow
/// and was deliberately *not* grown: the icon-size test reads the declared value
/// off the widget rather than pinning it, so a retune here is a design decision
/// rather than a test failure, and nothing in the brief asked for a bigger glyph.
const double _kNavIconSize = 22;

/// The width a destination is laid out in.
///
/// **36 dp, down from 46, because there is no longer a label to fit.** Every step
/// of this number so far has been argued in terms of the widest word underneath
/// the icon — `Hydroponics` is 123 dp of natural text — and that constraint is
/// gone. What is left is the ripple's `_kNavItemWidth` box, so the slot only has
/// to clear the 22 dp icon with air around it: 7 dp on each side.
///
/// **This is the drawn box, not the touch target.** It has to clear the 22 dp
/// glyph and the 44 dp bubble with air, which 36 does not — the disc was being
/// clipped by the slot it sits in. The ripple's hit area comes from the
/// destination's own slot in [GlassNavBar] (`_kNavSlotWidth`), which is 48 dp
/// wide by [kGlassNavBarHeight] tall and therefore clears Material's 44 dp
/// minimum on both axes. Raising this number widens the bubble too, so it is
/// set to the disc's own 44 and no further.
///
/// The bar's width is this constant times the destination count plus the gap, and
/// that arithmetic lives in `GlassNavBar` rather than here, so the two halves move
/// together when this moves.
const double _kNavItemWidth = 44;

/// The pitch the four destinations are laid out at, independent of the bar's
/// width.
///
/// **48, and it is a floor rather than the whole layout.** The row used
/// `Expanded` across the full width, which on a 360 dp phone put the icons 90 dp
/// apart for a 22 dp glyph — too far to read as one navigation bar, and the
/// selected disc looked stranded between two empty halves rather than sitting
/// on a tab. 48 gives 13 dp of air either side of the glyph, which is the
/// spacing the floating pill had before the bar was docked.
///
/// `min(48, availableWidth / 4)`, so a narrow screen or a large text scale
/// shrinks the pitch rather than overflowing it; the four slots are always
/// centred whatever that comes to.
///
/// **This is the touch target, and it is 48 on both axes.** The width is this
/// constant; the height is [kGlassNavBarHeight] (54), so a destination is a
/// 48 x 54 hit area — over Material's 44 dp minimum rather than relying on the
/// drawn box, which is only [_kNavItemWidth] (44) wide.
///
/// It also has to hold that 44 dp drawn box with the bubble's own air, which is
/// why the two numbers sit 4 apart rather than being one constant.
const double _kNavSlotWidth = 48;

// There were two getters here — `destination` and `selectedIndex` — that
// recovered the label from the *icon* by searching [kNavDestinations] for the
// matching `selectedIcon`. Nothing called them: `_NavItem` already knows its
// `destination` and passes the parts down. They are gone rather than fixed,
// because a reverse lookup by icon is a landmine — the day two destinations share
// an icon, `indexWhere` silently returns the first one and the wrong label is
// drawn with nothing failing. The label is now a field, as it always should
// have been.
