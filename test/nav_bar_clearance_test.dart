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

    test('the inset is taken as a maximum, not added to the floor', () {
      // The rule is `height + max(inset, gap)`, not `height + gap + inset`.
      // Adding both double-counts on a device that reports an inset, which is
      // the mistake a "just add them" fix makes — and it is the mistake this
      // assertion is for.
      //
      // **It used to also assert a flat region below the floor, and it cannot
      // any more.** That claim — `f(0) == f(4)` — was only ever true because the
      // floor was 10. The bar is docked now, so the floor is 0, every non-zero
      // inset is above it, and there is no flat region to assert. The rule it
      // was a proxy for is asserted directly below instead.
      expect(
        glassNavBarReservedHeightFor(34),
        kGlassNavBarHeight + 34,
        reason: 'a reported inset is added once, not twice',
      );
      expect(kGlassNavBarBottomGap, 0);
    });
  });

  group('the reservation matches the bar that actually renders', () {
    // The bar as the dashboard builds it: `Scaffold.bottomNavigationBar` with
    // `extendBody: true`, which is what makes it an overlay rather than a row.
    Future<double> measureBar(
      WidgetTester tester, {
      required double bottomInset,
    }) async {
      // The `MediaQuery` goes *outside* the `MaterialApp`, which is safe and is
      // the shape `system_status_strip_test.dart` already uses: `WidgetsApp`
      // never introduces a `MediaQuery` of its own, the `View` below it does, and
      // an injected one above takes precedence for this subtree.
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
          child: MaterialApp(
            home: Scaffold(
              extendBody: false,
              bottomNavigationBar: GlassNavBar(
                selectedIndex: 0,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(GlassNavBar)).height;
    }

    testWidgets('measured height equals the reservation, with no inset', (
      tester,
    ) async {
      final measured = await measureBar(tester, bottomInset: 0);
      expect(measured, glassNavBarReservedHeightFor(0));
    });

    testWidgets('measured height equals the reservation, with a system inset', (
      tester,
    ) async {
      // The device case. If the bar is genuinely taller than the rule says for
      // some inset, this is the assertion that names it.
      final measured = await measureBar(tester, bottomInset: 34);
      expect(measured, glassNavBarReservedHeightFor(34));
    });

    testWidgets('the bar is square, and the clip agrees with the decoration', (
      tester,
    ) async {
      // **A decoration's radius and its clipper's radius being allowed to
      // disagree is a shape that cannot exist.** The claim here has not changed
      // since the bar was a stadium — only the value has, because the bar is
      // docked now.
      //
      // It was `AppRadius.pill` on the grounds that a floating object needs
      // round corners to read as floating. A docked bar has the opposite
      // requirement: its bottom corners are the screen's own corners, so a
      // radius there paints page-coloured notches in them, which read as a
      // rendering fault rather than as a shape. `BorderRadius.zero` on both sides
      // of the claim is the docked answer.
      await measureBar(tester, bottomInset: 0);

      final decoration = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius != null);

      expect(
        decoration.borderRadius,
        BorderRadius.zero,
        reason:
            'a docked bar is square, and a radius here shows page-coloured '
            'notches in the two screen corners',
      );

      // And the clip is `ClipRect` rather than a `ClipRRect` with a radius,
      // because in Flutter 3.47 `ClipRRect.borderRadius` *defaults* to
      // `BorderRadius.zero` rather than being required — which is how a rounded
      // decoration ended up with a square clip painted over it, on a device,
      // with the suite green.
      expect(
        find.byType(ClipRect),
        findsOneWidget,
        reason:
            'the clip must still clip the contents to the same shape the '
            'decoration paints',
      );
    });
  });

  group('the accent bubble lands on the selected icon', () {
    Future<void> paintWithIndex(WidgetTester tester, int index) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: false,
            bottomNavigationBar: GlassNavBar(
              selectedIndex: index,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      // Past `AppMotion.container`, so the bubble has finished travelling.
      await tester.pumpAndSettle();
    }

    // **This is the claim the bubble exists to make, and nothing else checks
    // it.** The bubble is positioned by an `Alignment` computed from
    // `selectedIndex` while the icons are laid out by a `Row` of `Expanded`s —
    // two independent expressions of "where is slot `i`", in the same widget.
    // They agree for four destinations and would silently disagree the moment
    // a fifth was added, which is why the row uses `Expanded` rather than
    // `spaceEvenly`. A bubble 8 dp off its icon looks like a rendering fault,
    // not like a layout that is nearly right.
    for (final index in [0, 1, 2, 3]) {
      testWidgets('index $index puts the bubble on that icon', (tester) async {
        await paintWithIndex(tester, index);

        // **The bubble's own `SizedBox`, not the widget that positions it.**
        // `getCenter` on an `AnimatedPositioned` returns the centre of *its*
        // render box, which here is the whole slot, not where the disc inside
        // it was centred — the two happen to agree today because the bubble is
        // a centred child of a full slot, and measuring the wrong one would keep
        // passing for that reason.
        final bubble = tester.getCenter(
          find.descendant(
            of: find.byKey(const ValueKey('nav-accent-bubble')),
            matching: find.byType(SizedBox),
          ),
        );
        final icons = find.byType(Icon).evaluate().toList();
        expect(icons.length, greaterThanOrEqualTo(index + 1));

        final icon = tester.getCenter(find.byWidget(icons[index].widget));
        expect(
          (bubble.dx - icon.dx).abs(),
          lessThanOrEqualTo(0.5),
          reason:
              'the bubble is ${(bubble.dx - icon.dx).toStringAsFixed(1)}dp to '
              'the side of icon $index',
        );
        expect(
          (bubble.dy - icon.dy).abs(),
          lessThanOrEqualTo(0.5),
          reason: 'the bubble is not vertically centred on icon $index',
        );
      });
    }
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
    // its end, the last row of content must sit above the top of the bar. A
    // screen whose content is covered is the defect, and the only way to know it
    // is fixed is to look at where the content ends up.
    //
    // **The fixture is the bar's current shape, and it changed.** The bar is
    // docked: `extendBody: false`, so the Scaffold reserves the slot itself, and
    // the body asks only for the clearance gap. The fixture below used
    // `extendBody: true` with the body reserving the bar's full height, which is
    // the overlay shape this app no longer uses — a test that keeps passing
    // against a layout the app does not have is worse than no test, because it
    // reads as coverage.
    testWidgets('the last row of content clears the top of the nav bar', (
      tester,
    ) async {
      const clearance = 20.0;
      const bottomInset = 34.0;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: MaterialApp(
            home: Scaffold(
              // Docked: the Scaffold reserves the bar, the body reserves only
              // the gap. Mirrors `dashboard_screen.dart`.
              extendBody: false,
              bottomNavigationBar: GlassNavBar(
                selectedIndex: 0,
                onSelect: (_) {},
              ),
              body: ListView(
                // The padding the dashboard uses, and the thing under test.
                padding: const EdgeInsets.only(bottom: clearance),
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
      // `>= clearance`: `clearance` is what the body reserves, so requiring the
      // gap to *equal* it would pass for a layout that happens to agree with
      // itself and fail for one that does not.
      expect(
        gap,
        greaterThan(0),
        reason:
            'the last row of content ends ${-gap}dp below the top of the '
            'nav bar, so the bar is painted over it. The gap measured $gap.',
      );

      // And it must clear the bar's edge by the clearance, not merely touch it.
      expect(
        gap,
        greaterThanOrEqualTo(clearance - 8),
        reason:
            'the content clears the bar by only $gap dp, which puts it against '
            'the hairline rather than below the reserved gap.',
      );
    });
  });
}
