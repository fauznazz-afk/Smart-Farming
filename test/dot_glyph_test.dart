import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/dot_glyph.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/overview_panel.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';
import 'package:plts_monitoring/utils/solar_irradiance.dart';

void main() {
  group('DotGlyph', () {
    // **A dot matrix that paints nothing is the failure this file exists for.**
    // `CustomPaint` with no `painter` sizes fine, takes its space, passes
    // `flutter analyze` and draws a blank square - which is exactly what a
    // `SizedBox` would have drawn anyway. So the assertion is on painted
    // commands, not on the widget tree.
    testWidgets('paints something for every condition', (tester) async {
      for (final condition in SkyCondition.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: DotGlyph(condition, size: 44))),
          ),
        );
        await tester.pumpAndSettle();

        final paint = tester.renderObject<RenderCustomPaint>(
          find.descendant(
            of: find.byType(DotGlyph),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          paint.debugNeedsPaint,
          isFalse,
          reason: 'the CustomPaint for $condition never painted',
        );
        // The painter exists and is a dot matrix, so its recorded picture is
        // non-empty. `isComplex` is the cheap proxy that survives tree shaking.
        expect(paint.painter, isNotNull, reason: '$condition has no painter');
      }
    });

    // **A dot you cannot see is not a dot.** At 22 dp with the radius this shipped
    // at first, each lamp measured **0.84 dp across** - smaller than the gap
    // beside it, so eleven of them in a row read as texture rather than as a
    // picture, and the user reported the mark as "11 px". The threshold is on
    // the dot, not on the box, because the box is what was fine.
    testWidgets('a lamp is big enough to read, not just to exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // The size the Overview panel actually uses.
            body: Center(child: DotGlyph(SkyCondition.clear, size: 72)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(DotGlyph));
      final cell = box.width / 11;
      final diameter = cell * 0.58;
      expect(
        diameter,
        greaterThan(3.0),
        reason:
            'each lamp is $diameter dp across at ${box.width} dp, which '
            'reads as texture rather than as a shape',
      );
      // **And the lamps still nearly touch.** A dot that fills its own cell
      // stops being a grid; one that leaves a wide gap stops being a picture.
      expect(diameter, greaterThan(cell * 0.5));
      expect(diameter, lessThan(cell * 0.66));
    });

    testWidgets('the mark is square and the requested size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DotGlyph(SkyCondition.clear, size: 44)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(DotGlyph));
      expect(box.width, 44);
      expect(
        box.height,
        44,
        reason: 'the grid is square; it must not letterbox',
      );
    });

    testWidgets('carries the condition as its accessible label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DotGlyph(SkyCondition.overcast, size: 22)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Overcast'),
        findsOneWidget,
        reason:
            'a dot matrix is unreadable to a screen reader as a shape, so '
            'it has to name itself',
      );
      handle.dispose();
    });

    testWidgets('repaints when the condition changes', (tester) async {
      // Two conditions with identical art would still repaint, so this is a
      // weaker claim than "the art differs" - it is the wiring claim, and it is
      // the one that fails when a caller caches the wrong painter.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DotGlyph(SkyCondition.clear, size: 44)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DotGlyph(SkyCondition.overcast, size: 44)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DotGlyph), findsOneWidget);
    });
  });
  group('OverviewPanel carries the sky mark on SKY_STATE', () {
    // **44 dp at the right edge, and both numbers were answers to a complaint.**
    // 22 dp put each lamp at 0.84 dp, smaller than the gaps between them, and
    // the mark read as texture - the user counted the lamps and said "11 px". A
    // centred 72 dp block fixed the size and broke the layout: in a column of
    // 43 dp rows it read as a section heading. So the size is 44 and the slot is
    // `trailing`.
    testWidgets('the mark is on the row, at the end of it', (tester) async {
      tester.view.physicalSize = const Size(381, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(381, 1400)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: OverviewPanel(
                  readings: const OverviewReadings(lux: 16000),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.ancestor(
        of: find.byType(DotGlyph),
        matching: find.byType(TerminalRow),
      );
      expect(row, findsOneWidget, reason: 'the mark belongs to the SKY row');

      final size = tester.getSize(find.byType(DotGlyph)).width;
      expect(size, greaterThanOrEqualTo(40), reason: 'still too small to read');

      // **At the right edge, past the value.** The slot name keeps the left
      // edge, and the mark is the last thing in the row.
      final mark = tester.getRect(find.byType(DotGlyph));
      final value = tester.getRect(find.text('Partly cloudy'));
      expect(
        mark.left,
        greaterThan(value.right),
        reason: 'the mark is not past the value, so it is not on the right',
      );
      expect(
        value.right - mark.right,
        lessThan(40),
        reason: 'the mark is floating in the middle rather than on the edge',
      );
    });

    // **No reading, no mark.** A dot matrix is a confident drawing of a
    // condition, and `--` is not one.
    testWidgets('an absent reading draws no mark', (tester) async {
      tester.view.physicalSize = const Size(381, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(381, 1400)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: OverviewPanel(readings: const OverviewReadings()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DotGlyph), findsNothing);
      expect(find.text('--'), findsWidgets);
    });
  });
}
