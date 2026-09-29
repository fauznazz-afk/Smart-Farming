import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/chart_gesture_lock.dart';

/// Covers the physics that gates the dashboard's four-tab [PageView].
///
/// The class was added in 1.6.0 and had no coverage at all. It exists so that a
/// drag starting on a chart does not also change page, and it replaced a
/// `ValueListenableBuilder` that rebuilt the whole `PageView` twice per gesture.
///
/// Being a gate rather than a replacement is the whole point, and that is what
/// the missing delegation below broke: the class overrode
/// `shouldAcceptUserOffset` and `allowUserScrolling` but not
/// `createBallisticSimulation`, so a released drag fell through to
/// `ScrollPhysics`'s friction simulation instead of `PageScrollPhysics`'s spring.
/// The pager stopped being a pager — it glided to wherever friction ended,
/// between pages, with nothing to snap it back. That is the "infinite page"
/// reported on the Overview tab.
void main() {
  const pageCount = 4;
  const pageWidth = 400.0;

  Future<ScrollPosition> pumpPager(
    WidgetTester tester, {
    required bool Function() isLocked,
  }) async {
    tester.view.physicalSize = const Size(pageWidth, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = PageController();
    addTearDown(controller.dispose);
    final changed = <int>[];
    addTearDown(() {});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageView.builder(
            controller: controller,
            physics: ChartGestureLockPhysics(
              basePhysics: const PageScrollPhysics(),
              isLocked: isLocked,
            ),
            itemCount: pageCount,
            onPageChanged: changed.add,
            itemBuilder: (context, index) => Center(
              child: Text('page $index', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    return scrollable.position;
  }

  group('ChartGestureLockPhysics is a gate, not a replacement', () {
    testWidgets('a released drag settles exactly on a page boundary',
        (tester) async {
      final position = await pumpPager(tester, isLocked: () => false);

      // Short drag, released with enough velocity to fling. A pager must spring
      // to the next whole page.
      await tester.fling(
        find.byType(PageView),
        const Offset(-150, 0),
        800,
      );
      await tester.pumpAndSettle();

      expect(
        position.pixels % pageWidth,
        closeTo(0, 0.5),
        reason: 'After a fling the pager must rest on a page boundary, not at '
            'whatever point friction happened to stop it. Offset was '
            '${position.pixels}.',
      );
    });

    testWidgets('a slow drag still advances exactly one page', (tester) async {
      final position = await pumpPager(tester, isLocked: () => false);

      await tester.drag(find.byType(PageView), const Offset(-pageWidth, 0));
      await tester.pumpAndSettle();

      expect(position.pixels, pageWidth);
    });

    testWidgets('paging never walks past the last page', (tester) async {
      final position = await pumpPager(tester, isLocked: () => false);

      for (var i = 0; i < 8; i++) {
        await tester.fling(
          find.byType(PageView),
          const Offset(-pageWidth, 0),
          2000,
        );
        await tester.pumpAndSettle();
      }

      expect(
        position.pixels,
        pageWidth * (pageCount - 1),
        reason: 'After eight forward flings the pager must be on the last page. '
            'It stopped at ${position.pixels}.',
      );
    });
  });

  group('the lock, as it actually behaves', () {
    testWidgets('a pager laid out while locked refuses the gesture',
        (tester) async {
      final position = await pumpPager(tester, isLocked: () => true);

      await tester.drag(find.byType(PageView), const Offset(-pageWidth, 0));
      await tester.pumpAndSettle();

      expect(
        position.pixels,
        0,
        reason: 'The PageView was laid out while locked, so it never got a drag '
            'recognizer and the gesture goes nowhere.',
      );
    });

    testWidgets('a pager laid out while unlocked pages normally',
        (tester) async {
      var locked = false;
      final position = await pumpPager(tester, isLocked: () => locked);

      await tester.drag(find.byType(PageView), const Offset(-pageWidth, 0));
      await tester.pumpAndSettle();
      expect(
        position.pixels,
        pageWidth,
        reason: 'Unlocked, so the pager has to work. Nothing about the lock '
            'should leak into the common case.',
      );
    });
  });
}
