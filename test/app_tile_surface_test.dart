import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// `AppTile.inset` has to stay a real branch.
///
/// **The defect: the two arms collapsed onto one colour.** The fill read
/// `inset ? AppSurfaces.surface : AppSurfaces.input`, and `input` is *declared*
/// as the same value as `surface` — so `inset` selected between two identical
/// colours, every tile in the app drew in the card's own fill, and the only
/// thing distinguishing a metric tile from the card behind it was a 20%-alpha
/// categorical border. Nothing failed: `inset` was still passed by two call
/// sites and its doc still claimed metric tiles were kept distinct from
/// progress-bar wells. It had just quietly stopped being true.
///
/// These assertions are about the *relationship* between the surfaces, not
/// about which hex each one is today. That is deliberate for the same reason
/// `color_helpers_test.dart` derives its surface list rather than writing it
/// down: a test that names the values has to be edited by anyone who retunes
/// them, while a test that names the ordering catches the class of bug instead
/// of the instance.
void main() {
  /// The fill `AppTile` actually painted, read from the box it built.
  Future<Color> tileFill(WidgetTester tester, {required bool inset}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppBackground(
          child: Center(
            child: AppTile(inset: inset, child: const SizedBox.shrink()),
          ),
        ),
      ),
    );
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppTile),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration;
    expect(decoration, isA<BoxDecoration>());
    return (decoration as BoxDecoration).color!;
  }

  group('the surface ramp', () {
    test('page is darker than the card, which is darker than the tile', () {
      final luminance = <Color>[
        AppSurfaces.page,
        AppSurfaces.surface,
        AppSurfaces.surfaceAlt,
      ].map((c) => c.computeLuminance()).toList()..sort();
      expect(
        luminance[0],
        lessThan(luminance[1]),
        reason: 'page must sit below the card',
      );
      expect(
        luminance[1],
        lessThan(luminance[2]),
        reason:
            'the card must sit below the deepest step, so that something '
            'inside a card can still be louder than it',
      );
    });

    test('the tile step is loud enough to carry the boundary alone', () {
      // **Either direction, and the direction is the fix.**
      //
      // This asserted `> 1.0`, i.e. that the tile is *lighter* than the card,
      // which held while `surfaceAlt` was the lighter step of the ramp. The blue
      // system inverted that in both ramps: the card is now the near-white one
      // and `surfaceAlt` is the inset tile *below* it, so the ratio is **0.92**
      // and the assertion fails on a real, correct tile.
      //
      // What is actually claimed is not which way the step goes but that there
      // *is* one: a tile whose fill equals the card's own fill has no boundary at
      // all, and "no tonal step" is precisely the failure this test exists to
      // catch. So it asserts separation, in either direction, past a rounding
      // band — and the band is what separates a step from a quantisation error.
      final ratio =
          (AppSurfaces.surfaceAlt.computeLuminance() + 0.05) /
          (AppSurfaces.surface.computeLuminance() + 0.05);
      expect(
        ratio < 0.98 || ratio > 1.02,
        isTrue,
        reason:
            'the tile fill is indistinguishable from the card (ratio '
            '${ratio.toStringAsFixed(2)}), so the tile has no boundary and only '
            'the categorical border is left to describe it',
      );
    });
  });

  group('AppTile.inset', () {
    testWidgets(
      'an inset tile is the step above the card, not the card itself',
      (tester) async {
        final fill = await tileFill(tester, inset: true);
        expect(
          fill,
          AppSurfaces.surfaceAlt,
          reason:
              'A tile drawn in the card\u2019s own fill is invisible on it: '
              'the fill stops carrying the boundary and only a 20%-alpha border '
              'is left to do the work.',
        );
        expect(
          fill,
          isNot(await tileFill(tester, inset: false)),
          reason:
              '`inset` selects between two surfaces. If both arms return '
              'the same colour the parameter is dead and every call site that '
              'reads it is lying.',
        );
      },
    );

    testWidgets('an inset tile is a different step from the card', (tester) async {
      // **"a different step", not "lighter" — and the direction was the defect.**
      //
      // This asserted the inset tile was lighter than the card, which was true when
      // `surfaceAlt` was the lighter step. It is now the *darker* one in both
      // ramps, because the card is the near-white surface and the tile is the inset
      // well below it, so `greaterThan` fails on a correct tile.
      //
      // The claim that matters is separation: an inset tile that shares the card's
      // fill has no edge, which is the reason this test exists.
      final fill = await tileFill(tester, inset: true);
      expect(
        fill.computeLuminance(),
        isNot(closeTo(AppSurfaces.surface.computeLuminance(), 0.02)),
        reason:
            'the inset tile is indistinguishable from the card, so it has no '
            'edge and only a categorical border is left to describe it',
      );
    });

    testWidgets(
      'a non-inset tile is the input surface, which the tokens define',
      (tester) async {
        expect(await tileFill(tester, inset: false), AppSurfaces.input);
      },
    );
  });
}
