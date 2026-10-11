import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderBox, RenderFittedBox, RenderObject;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/nav_bar.dart';

/// The nav bar's four destinations draw four icons of the same size.
///
/// ## Why this test exists, and why it is this shape
///
/// The icons were all declared at 24 dp and none of them rendered at 24 dp. The
/// whole icon-plus-label column was wrapped in one `FittedBox`, so the *label*
/// set the scale and the icon was scaled along with it. Measured on the device:
///
///     Fish          23.6 dp
///     Power         18.9 dp
///     Overview      11.8 dp
///     Hydroponics    8.6 dp
///
/// A 2.7x spread across four glyphs in one row, tracking the length of the word
/// underneath and having nothing to do with the icons themselves. It read as
/// "the Hydroponics icon looks a bit small" and nothing more, because the icon
/// that *was* small happened to be the one with the longest label.
///
/// ## The measurement is a paint transform, and that is the whole difficulty
///
/// **`RenderBox.size` cannot see this.** A `FittedBox` lays its child out at the
/// child's natural size and applies the scale as a *paint* transform, so the
/// icon's render object reports 24 dp before and after the fix alike. An earlier
/// draft of this file read `renderObject.size.width` and passed on the broken
/// bar — which is the same trap `live_power_card_figure_size_test.dart` already
/// documents for the power figures.
///
/// So this walks up through **every** enclosing `RenderFittedBox` and multiplies
/// each one's scale factor, because nested fits compose. An icon with no
/// `FittedBox` above it measures 1.0 and reports its layout size, which is the
/// correct answer rather than a gap in the test — and that is exactly what the
/// fix produces.
double paintedIconWidth(Element iconElement) {
  final icon = iconElement.renderObject! as RenderBox;
  var painted = icon.size.width;

  // **Every** enclosing FittedBox, not just the nearest. Nested fits compose,
  // and stopping at the first one would miss a second halving entirely.
  RenderObject? node = iconElement.renderObject;
  while (node != null) {
    if (node is RenderFittedBox) {
      final child = node.child;
      if (child is RenderBox && child.size.width > 0) {
        painted *= node.size.width / child.size.width;
      }
    }
    node = node.parent;
  }
  expect(
    painted,
    greaterThan(0),
    reason: 'a zero painted width means the measurement itself is wrong',
  );
  return painted;
}

void main() {
  /// The painted width of each of the four expanded icons, left to right.
  Future<List<double>> paintedIcons(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1220, 2712);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

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
          ),
        ),
      ),
    );
    await tester.pump();

    final widths = <double>[];
    for (final element in find.byType(Icon).evaluate()) {
      final box = element.renderObject! as RenderBox;
      // The collapsed pill's icon is laid out in a 48 dp circle. It is off-screen
      // behind an opacity of 0 but still laid out, so it has to be excluded by
      // size rather than by visibility.
      if (box.size.height > 32) continue;
      widths.add(paintedIconWidth(element));
    }
    return widths;
  }

  group('every icon is drawn at the size it is declared at', () {
    testWidgets('the four expanded icons are all the same width', (
      tester,
    ) async {
      final widths = await paintedIcons(tester);
      expect(widths.length, 4, reason: 'expected the four expanded icons');

      final min = widths.reduce((a, b) => a < b ? a : b);
      final max = widths.reduce((a, b) => a > b ? a : b);
      expect(
        max - min,
        lessThanOrEqualTo(0.5),
        reason:
            'the icons are painted at '
            '${widths.map((w) => w.toStringAsFixed(1)).join(' / ')} dp. A spread '
            'this wide means one destination\'s label is scaling its own icon.',
      );
    });

    testWidgets('and that size is 24, not merely uniform', (tester) async {
      // Uniformity alone is not the claim — a bar where every icon were 8 dp
      // would pass the test above. This says the number is the one the
      // destinations declare.
      for (final w in await paintedIcons(tester)) {
        expect(
          w,
          closeTo(24, 0.5),
          reason:
              'an icon painted at ${w.toStringAsFixed(1)} dp. A `FittedBox` '
              'wrapping the icon as well as the label scales both together, and '
              'the scale follows the length of the word underneath.',
        );
      }
    });

    testWidgets('Hydroponics, the reported one, is 24 and not 8.6', (
      tester,
    ) async {
      // The specific complaint, named. "Hydroponics" is the longest label and
      // its icon was the smallest — 0.36x, because that is 123 dp squeezed into
      // a 44 dp slot.
      final widths = await paintedIcons(tester);
      final smallest = widths.reduce((a, b) => a < b ? a : b);
      expect(
        smallest,
        closeTo(24, 0.5),
        reason:
            'the smallest icon is ${smallest.toStringAsFixed(1)} dp, which is '
            'the one the user reported as looking small',
      );
    });

    testWidgets('the label may still shrink, because it is prose', (
      tester,
    ) async {
      // The complement of the fix, and the reason the fix is not "delete the
      // FittedBox". A destination label is prose and `scaleDown` is the right
      // degradation for it; what must not happen is the icon being dragged
      // along with it.
      //
      // `Hydroponics` is 123 dp of natural label in a 52 dp slot, so it *is*
      // shrinking — and the icon beside it is still full size. That contrast is
      // the whole claim, and asserting only "the icons match" would pass on a
      // bar that had simply stopped fitting its labels.
      final widths = await paintedIcons(tester);
      expect(widths.every((w) => w > 23.5), isTrue);

      // **The label's *painted* width, not its layout width.** Same reason as
      // the icons: a `FittedBox` lays the label out at 123 dp and paints it at
      // 44. Reading `RenderBox.size` here would report 123 and the test would
      // pass for a label that was in fact being crushed.
      final label = tester.renderObject<RenderBox>(find.text('Hydroponics'));
      var labelPainted = label.size.width;
      RenderObject? node = label;
      while (node != null) {
        if (node is RenderFittedBox) {
          final child = node.child;
          if (child is RenderBox && child.size.width > 0) {
            labelPainted *= node.size.width / child.size.width;
          }
        }
        node = node.parent;
      }
      expect(
        labelPainted,
        lessThan(label.size.width),
        reason:
            'the label lays out at ${label.size.width.toStringAsFixed(1)} dp '
            'and paints at ${labelPainted.toStringAsFixed(1)} dp. If the two are '
            'equal then nothing is scaling it, and this test says nothing about '
            'whether the label is allowed to shrink independently of the icon.',
      );
    });
  });
}