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
  /// Paint the bar. Every test in this file starts here, because the two readers
  /// below need a laid-out tree and a `find` on an unpumped widget throws.
  Future<void> paintBar(WidgetTester tester) async {
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
  }

  /// The size the destinations declare their icons at, read off the painted tree.
  ///
  /// **Read from the widget, not written as a literal here.** An earlier version
  /// pinned `24` and failed the day the icon was retuned to 22 — correctly, but
  /// for a reason that had nothing to do with the bug it exists for. The claim
  /// is "the icons paint at the size they declare"; the number is the source's
  /// business.
  double declaredIconSize(WidgetTester tester) {
    for (final element in find.byType(Icon).evaluate()) {
      final box = element.renderObject! as RenderBox;
      if (box.size.height > 32) continue; // the collapsed pill
      return (element.widget as Icon).size!;
    }
    fail('the bar drew no expanded icons to read a declared size from');
  }

  /// The painted width of each of the four expanded icons, left to right.
  List<double> paintedIcons(WidgetTester tester) {
    final widths = <double>[];
    for (final element in find.byType(Icon).evaluate()) {
      final box = element.renderObject! as RenderBox;
      // The collapsed pill's icon is laid out in a 44 dp circle. It is off-screen
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
      await paintBar(tester);
      final widths = paintedIcons(tester);
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

    testWidgets('and that size is the declared one, not merely uniform', (
      tester,
    ) async {
      // Uniformity alone is not the claim — a bar where every icon were 8 dp
      // would pass the test above. This says the number is the one the
      // destinations declare.
      //
      // **Read off the widget rather than written here.** An earlier version
      // pinned `24` literally, and the day the icon was retuned to 22 the test
      // failed — correctly, but for a reason that had nothing to do with the bug
      // it exists for. The claim is "the icons are painted at the size they
      // declare"; the number is the source's business.
      await paintBar(tester);
      final declared = declaredIconSize(tester);
      for (final w in paintedIcons(tester)) {
        expect(
          w,
          closeTo(declared, 0.5),
          reason:
              'an icon declared at $declared dp paints at '
              '${w.toStringAsFixed(1)} dp. A `FittedBox` wrapping the icon as well '
              'as the label scales both together, and the scale follows the '
              'length of the word underneath.',
        );
      }
    });

    testWidgets('Hydroponics, the reported one, is full size and not 8.6', (
      tester,
    ) async {
      // The specific complaint, named. "Hydroponics" is the longest label and
      // its icon was the smallest — 0.36x, because that is 123 dp squeezed into
      // a 44 dp slot.
      await paintBar(tester);
      final declared = declaredIconSize(tester);
      final widths = paintedIcons(tester);
      final smallest = widths.reduce((a, b) => a < b ? a : b);
      expect(
        smallest,
        closeTo(declared, 0.5),
        reason:
            'the smallest icon is ${smallest.toStringAsFixed(1)} dp against a '
            'declared $declared dp, and it is the one the user reported as '
            'looking small',
      );
    });

    testWidgets('no icon is drawn below its declared size', (tester) async {
      // Uniformity alone is satisfied by a bar where every icon is 8 dp, so this
      // is the other half of the claim: the declared size is also the floor.
      await paintBar(tester);
      final declared = declaredIconSize(tester);
      final widths = paintedIcons(tester);
      expect(
        widths.every((w) => w > declared - 0.5),
        isTrue,
        reason:
            'declared $declared dp, painted '
            '${widths.map((w) => w.toStringAsFixed(1)).join(' / ')}. An icon '
            'below its declared size is being scaled by an enclosing fit.',
      );
    });

    testWidgets('and the bar no longer prints a caption under each icon', (
      tester,
    ) async {
      // **This replaced the "the label may still shrink" test, which asserted a
      // `Text` that no longer exists.** The captions are gone at the user's
      // request, so the thing worth guarding is their *absence*: a bar that
      // quietly grew one back would still pass every other test in this file,
      // because the icons would remain uniform and full size. The names survive
      // only as `Semantics(label:)`, which is not a `Text`.
      await paintBar(tester);
      expect(find.text('Hydroponics'), findsNothing);
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Power'), findsNothing);
      expect(find.text('Fish'), findsNothing);

      // **Structural, not just by string.** A caption drawn from anywhere other
      // than `NavDestination.label` would slip past the four finders above, so
      // the check is that the bar contains no `Text` at all.
      expect(
        find.descendant(
          of: find.byType(GlassNavBar),
          matching: find.byType(Text),
        ),
        findsNothing,
        reason:
            'the bar draws a Text. The captions were removed deliberately and the '
            'accessible name now lives on `Semantics`, so a Text here is a '
            'regression rather than a variant.',
      );
    });
  });
}