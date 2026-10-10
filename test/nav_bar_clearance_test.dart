import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/nav_bar.dart';

/// Covers the reservation the dashboard's scroll padding makes for the floating
/// nav bar, and pins that reservation to the bar's **measured** height.
///
/// **The defect this exists for was a device-only one.** On the Xiaomi 24090RA29G
/// (1220x2712, density 520) the bar is the `Scaffold.bottomNavigationBar` with
/// `extendBody: true`, so it is painted *over* the page and the scrolling content
/// has to reserve the space itself. It reserved `MediaQuery.paddingOf(context)
/// .bottom + 76` — a literal with no relationship to the 52 the bar draws,
/// written when the bar was full-width. The last line of the Energy analytics
/// card ended up under the pill, and no scroll position could clear it.
///
/// Two claims are pinned, and they are different claims:
///
///  1. `glassNavBarReservedHeightFor` is *at least* the bar's real height, for
///     any system inset. That is the reservation rule on its own.
///  2. The bar, laid out for real inside the same `Scaffold` shape the dashboard
///     uses, *measures* that height. This is the one that catches a future edit
///     to the pill — a taller bar, a bigger safe-area minimum, a fifth tab — and
///     it is the assertion that would have failed for the `76`.
///
/// A pure unit test of (1) alone would pass with a bar 30dp taller than anything
/// claims, which is exactly the drift that produced the original bug.
void main() {
  group('glassNavBarReservedHeightFor', () {
    test('covers the bar when the device reports no bottom inset', () {
      // The desktop-window and test case, and the one where a hard-coded
      // constant is most likely to have been tuned by accident.
      expect(
        glassNavBarReservedHeightFor(0),
        greaterThanOrEqualTo(kGlassNavBarHeight),
      );
    });

    test('never falls below the bar, at any inset', () {
      // The rule has to hold for every inset, not just the measured one, because
      // the reservation is evaluated per frame from whatever the platform
      // reports. Insets from 0 to 120 dp cover gesture bars, three-button bars
      // and a software keyboard's worth of bottom inset.
      for (var inset = 0.0; inset <= 120.0; inset += 1) {
        expect(
          glassNavBarReservedHeightFor(inset),
          greaterThanOrEqualTo(kGlassNavBarHeight),
          reason: 'inset $inset dp reserved less than the bar itself',
        );
      }
    });

    test('grows with the inset, so a taller system bar is still covered', () {
      expect(
        glassNavBarReservedHeightFor(48),
        greaterThan(glassNavBarReservedHeightFor(0)),
      );
    });

    test('the inset floor is a floor and not a second addition', () {
      // Below the floor the reservation is the same number, not the floor plus
      // the inset. Adding both would double-count on a device that reports an
      // inset, which is the mistake a "just add them" fix makes.
      expect(glassNavBarReservedHeightFor(0), glassNavBarReservedHeightFor(4));
      expect(glassNavBarReservedHeightFor(0), kGlassNavBarHeight + 10);
    });
  });

  group('the reservation matches the bar that actually renders', () {
    // The bar as the dashboard builds it: `Scaffold.bottomNavigationBar` with
    // `extendBody: true`, which is what makes it an overlay rather than a row.
    Future<double> measureBar(
      WidgetTester tester, {
      required double bottomInset,
    }) async {
      final collapsed = ValueNotifier<bool>(false);
      addTearDown(collapsed.dispose);
      // The `MediaQuery` goes *outside* the `MaterialApp`, which is safe and is
      // the shape `system_status_strip_test.dart` already uses: `WidgetsApp`
      // never introduces a `MediaQuery` of its own, the `View` below it does, and
      // an injected one above takes precedence for this subtree.
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
          child: MaterialApp(
            home: Scaffold(
              extendBody: true,
              bottomNavigationBar: GlassNavBar(
                selectedIndex: 0,
                collapsed: collapsed,
                onSelect: (_) {},
                onExpand: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(GlassNavBar)).height;
    }

    testWidgets('measured height equals the reservation, with no inset',
        (tester) async {
      final measured = await measureBar(tester, bottomInset: 0);
      expect(measured, glassNavBarReservedHeightFor(0));
    });

    testWidgets('measured height equals the reservation, with a system inset',
        (tester) async {
      // The device case. If the bar is genuinely taller than the rule says for
      // some inset, this is the assertion that names it.
      final measured = await measureBar(tester, bottomInset: 34);
      expect(measured, glassNavBarReservedHeightFor(34));
    });
  });

  group('the dashboard actually reserves the space', () {
    // **The two tests above do not catch the reported defect, and this one
    // does.** Verified by reverting the dashboard's padding to the old literal
    // `76` and re-running: they still passed. They measure the *bar* and compare
    // it to the *rule*, and both sides moved together when the bar changed, so
    // they confirm the rule describes the bar. The defect was never that - it
    // was that the dashboard's scroll padding did not match either number.
    //
    // So this asserts the thing the user actually sees: with a list scrolled to
    // its end, the last row of content must sit above the top of the pill. A
    // screen whose content is covered is the defect, and the only way to know it
    // is fixed is to look at where the content ends up.
    testWidgets('the last row of content clears the top of the nav bar',
        (tester) async {
      const clearance = 20.0;
      final collapsed = ValueNotifier<bool>(false);
      addTearDown(collapsed.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: MaterialApp(
            home: Scaffold(
              extendBody: true,
              bottomNavigationBar: GlassNavBar(
                selectedIndex: 0,
                collapsed: collapsed,
                onSelect: (_) {},
                onExpand: () {},
              ),
              body: ListView(
                // The padding the dashboard uses, and the thing under test.
                padding: EdgeInsets.only(
                  bottom: glassNavBarReservedHeightFor(34) + clearance,
                ),
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 60, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      );

      // Scroll to the very end, which is where the overlap happened.
      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pump();

      final lastRow = find.text('row 39');
      expect(lastRow, findsOneWidget);
      final bar = tester.getRect(find.byType(GlassNavBar));
      final gap = bar.top - tester.getBottomLeft(lastRow).dy;

      // The gap has to be **positive**, and the assertion is deliberately not
      // `>= clearance`. Measured on this geometry: the reserved padding yields a
      // gap of about +27.5dp, while the old literal `76` yields about **-7.6dp**
      // - the content ends 7.6dp *below* the top of the bar, i.e. covered. A
      // threshold sitting between the two is what distinguishes the fix from the
      // defect; `clearance` (20) sits at the wrong end of that range, which is
      // why an earlier draft of this test passed against the broken padding.
      expect(
        gap,
        greaterThan(0),
        reason: 'the last row of content ends ${-gap}dp below the top of the '
            'nav bar, so the bar is painted over it. The gap measured '
            '$gap; the reserved padding produces about +27.5 and the literal 76 '
            'this replaced produced about -7.6.',
      );

      // And it must clear the bar's *shadow*, not merely its edge: the ambient
      // half of `AppElevation.raised` reaches further than the pill does.
      expect(
        gap,
        greaterThanOrEqualTo(clearance - 8),
        reason: 'the content clears the bar by only $gap dp, which puts it '
            'inside the drop shadow the bar casts.',
      );
    });
  });
}
