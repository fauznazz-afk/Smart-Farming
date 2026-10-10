import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderFittedBox, RenderObject, RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/live_power_card.dart';

/// The three flow-row figures share one painted size.
///
/// **Its own file, not a group in `live_power_card_test.dart`.** That file holds
/// 60 tests and a full-file run of it sits right at the edge of this machine's
/// memory budget -- past that, `flutter test` reports `did not complete` for
/// every remaining test with no stack trace, which reads exactly like a logic
/// failure and is not one (see `dart_test.yaml` and the note in `AGENTS.md`).
/// Adding 13 more card pumps to that file pushed it over, so this half of the
/// same widget lives beside it. The suite is run per file here anyway.
void main() {
  /// The figure drawing [figure], as the layout actually resolved it.
  RenderParagraph findFigure(WidgetTester tester, String figure) {
    final finder = find.text(figure);
    expect(
      finder,
      findsOneWidget,
      reason: 'expected exactly one "$figure" on the card',
    );
    return tester.renderObject<RenderParagraph>(finder.first);
  }

  /// **The effective painted size of one figure, in logical pixels.**
  ///
  /// This is a *painted-size* measure, and that is the whole difficulty. The
  /// three figures always shared a `fontSize` of 24, taken from one style, so a
  /// test that reads the font size passes on the broken build and guards nothing
  /// at all. And `FittedBox` gives its child unbounded width, lays it out at its
  /// natural size, and applies the scale as a paint transform -- so
  /// `RenderParagraph.size` is the *un-scaled* width both before and after the
  /// fix. The number the reader actually sees exists only as the product of the
  /// style's font size, the `TextScaler` the card was pumped at, and the fitted
  /// box's size over its child's.
  double paintedFontSize(RenderParagraph figure, double textScale) {
    final span = figure.text;
    expect(span, isA<TextSpan>());
    final style = (span as TextSpan).style;
    expect(
      style?.fontSize,
      isNotNull,
      reason: 'the figure has no font size, so there is no size to compare',
    );

    RenderFittedBox? fitted;
    for (RenderObject? node = figure; node != null; node = node.parent) {
      if (node is RenderFittedBox) {
        fitted = node;
        break;
      }
    }
    if (fitted == null) {
      fail('the figure is not inside a FittedBox, so this test would be '
          'measuring the wrong thing');
    }
    final natural = figure.size.width;
    expect(
      natural,
      greaterThan(0),
      reason: 'a zero-width figure has no scale to report',
    );

    return style!.fontSize! * textScale * (fitted.size.width / natural);
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required double solar,
    required double house,
    required double battery,
    required double scale,
    double width = 381,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800))
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: LivePowerCard(
                pvPower: solar,
                acPower: house,
                batteryPower: battery,
                soc: 75,
                pzemStale: false,
                pzemAgeLabel: '5s ago',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  group('the three flow figures are drawn at one size', () {
    // **Found on the Xiaomi 24090RA29G on 3 October 2026 at a 2.0 system font,
    // not by reasoning.** With `Solar 250 W / House 17 W / Charging 93 W` the
    // `250` rendered visibly smaller and raised above the other two. Measured,
    // the three were 11.3 / 16.9 / 29.8 px effective -- a 2.6x spread -- because
    // each `_Term` carried its own `FittedBox(scaleDown)` and each settled at its
    // own factor.
    //
    // The card's comment says the row "reads as three equal stations", so a
    // figure at a different size reads as a different *quantity* -- the same
    // objection `AGENTS.md` raises about a chart whose shape is an artefact of
    // its units.
    Future<void> expectOneSharedSize(
      WidgetTester tester,
      List<double> watts,
      double scale,
    ) async {
      final sizes = <double>[];
      for (final w in watts) {
        sizes.add(paintedFontSize(findFigure(tester, w.toStringAsFixed(0)), scale));
      }

      final spread = sizes.reduce(math.max) - sizes.reduce(math.min);
      expect(
        spread,
        lessThanOrEqualTo(1.0),
        reason: 'the figures are drawn at '
            '${sizes.map((s) => s.toStringAsFixed(1)).join(' / ')} px, a '
            '${spread.toStringAsFixed(1)} px spread. Each must be drawn at the '
            'same size or it reads as a different quantity.',
      );
    }

    const cases = <String, (double, double, double)>{
      // The reported case: one three-digit figure and two short ones.
      '250 / 17 / 93': (250, 17, 93),
      // The opposite shape, so the assertion is not a coincidence of digit
      // count: the first term is the long one and the third is short.
      '1250 / 17 / 9': (1250, 17, 9),
      // A negative four-digit figure, which is the sign the Battery page prints
      // and the one string that must never be abbreviated away.
      '93 / 1250 / -1250': (93, 1250, -1250),
    };

    for (final entry in cases.entries) {
      final (solar, house, battery) = entry.value;
      // Three scales, not five. The behaviour here is monotone in the text
      // scale -- once the figures shrink they keep shrinking -- so 1.0, 2.0 and
      // 3.0 bracket it.
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('${entry.key} share one size at scale $scale',
            (tester) async {
          await pumpCard(
            tester,
            solar: solar,
            house: house,
            battery: battery,
            scale: scale,
          );

          // And the figures are still whole numbers, which is the other half of
          // the same card: equal size must not be bought with an abbreviation.
          expect(find.text(solar.toStringAsFixed(0)), findsOneWidget);
          expect(find.text(battery.toStringAsFixed(0)), findsOneWidget);

          await expectOneSharedSize(tester, [solar, house, battery], scale);
        });
      }
    }

    // **The equality guard is worth nothing if the shared size can be made
    // arbitrarily small.** A "fix" that passed it by collapsing every figure to
    // a few pixels would be equal and useless, so the size is pinned from below
    // as well. The floor is measured rather than chosen: 11.3 px is the size the
    // three-digit figure in the narrowest slot already drew at, and that width
    // is set by the labels crowding the row, so a drop below it is a regression
    // and not an improvement. Equalising does cost size -- `17` and `93` come
    // down to meet the `250` -- and that trade is deliberate; this test is what
    // stops the next person making it a worse one.
    testWidgets('the shared size does not collapse below what was drawn before',
        (tester) async {
      const scale = 2.0;
      await pumpCard(tester, solar: 250, house: 17, battery: 93, scale: scale);

      final size = paintedFontSize(findFigure(tester, '93'), scale);
      expect(
        size,
        greaterThanOrEqualTo(11.0),
        reason: 'the figures settled at ${size.toStringAsFixed(1)} px. The '
            'three-digit figure in the narrowest slot was 11.3 px before this '
            'change, so this is smaller than anything the card has drawn.',
      );
    });

    // The narrow viewport, because the flow share shrinks with the card and this
    // is the case most likely to squeeze the figures further.
    testWidgets('the figures still share one size on a narrow viewport',
        (tester) async {
      const scale = 2.0;
      await pumpCard(
        tester,
        solar: 250,
        house: 17,
        battery: 93,
        scale: scale,
        width: 320,
      );

      await expectOneSharedSize(tester, [250, 17, 93], scale);
    });
  });
}
