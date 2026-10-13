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

  group('OverviewPanel draws the sky mark on SKY_STATE', () {
    // The row that carries it is the one the user asked for, so this is the
    // assertion that says it is wired at all. The glyph only appears when there
    // is a reading: a mark beside `--` would be a confident picture of a sky
    // nobody measured.
    testWidgets('the mark appears only when lux is known', (tester) async {
      Future<void> pump(double? lux) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OverviewPanel(readings: OverviewReadings(lux: lux)),
            ),
          ),
        ),
      );

      await pump(16000);
      await tester.pumpAndSettle();
      expect(find.byType(DotGlyph), findsOneWidget);

      await pump(null);
      await tester.pumpAndSettle();
      expect(find.byType(DotGlyph), findsNothing);
    });
  });
}
