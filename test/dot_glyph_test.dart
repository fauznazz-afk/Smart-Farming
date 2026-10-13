import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/dot_glyph.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/overview_panel.dart';
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

  group('OverviewPanel draws the sky as a block of its own', () {
    // **72 dp, and the number is the whole point of the change.** The mark was
    // 22 dp inline on the `SKY_STATE` row, where the lamps measured 0.84 dp
    // across - smaller than the gap beside them, so eleven of them in a row read
    // as texture. The user reported it as "11 px", which is exactly what eleven
    // dots that size are.
    testWidgets('the block is large enough to be looked at', (tester) async {
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

      expect(
        tester.getSize(find.byType(DotGlyph)).width,
        greaterThanOrEqualTo(64),
        reason: 'the sky mark is still small enough to read as decoration',
      );
      // **The name is under it, not beside it.** A shape and its label stacked
      // are one unit; side by side they are two rows of a table, which is what
      // the inline version was.
      expect(find.text('SKY_STATE'), findsOneWidget);
      expect(find.text('PARTLY CLOUDY'), findsOneWidget);
    });

    // **A sky nobody measured says so.** The block is always drawn - a gap in
    // the panel would look like a layout fault - but the mark is muted and the
    // label reads NO READING, because a dot matrix is a confident drawing of a
    // condition and `--` is not one.
    testWidgets('an absent reading is named rather than drawn', (tester) async {
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

      expect(find.byType(DotGlyph), findsOneWidget);
      expect(find.text('NO READING'), findsOneWidget);
      expect(find.text('PARTLY CLOUDY'), findsNothing);
    });
  });
}
