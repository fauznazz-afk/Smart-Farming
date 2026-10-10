import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/chart_carousel.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// The carousel's bleed: the `PageView` is [inset] wider on both sides than the
/// card it sits in, so a page's chart reaches the card's rounded edge and the
/// next page shows a sliver of itself as a swipe affordance.
///
/// **The defect this pins was 32dp wide and no test saw it.** The band was
/// rebuilt as `LayoutBuilder` + `SizedBox(width: maxWidth + 2 * inset)` +
/// `Transform.translate(-inset)`, which reads like an overflow-free way to get
/// the same result. It is not: the `Column` is `CrossAxisAlignment.stretch`, so
/// it hands each child a *tight* width, and `BoxConstraints.enforce` clamps a
/// `SizedBox` that asks for more back down to the width it was offered. The
/// `+ 2 * inset` never took effect, so the translate shifted a normal-width
/// carousel left by `inset` — bleeding on one side only and stopping `2 * inset`
/// short of the card's right edge. Every chart on the PV, AC and battery pages
/// sat 32dp off-centre that way, on a build where `flutter analyze` was clean
/// and every existing test passed.
///
/// So this asserts the *painted* geometry, not the arrangement that produces it.
/// Both edges have to bleed by the same amount, and it has to be exactly the
/// [inset] the caller asked for.
void main() {
  testWidgets('the PageView bleeds past the card by `inset` on both sides', (
    tester,
  ) async {
    const inset = 16.0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppBackground(
          child: Center(
            child: SizedBox(
              width: 411,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  child: ChartCarousel(
                    itemCount: 2,
                    height: 200,
                    inset: inset,
                    labelBuilder: (i) => 'page $i',
                    onPointerActive: (_) {},
                    itemBuilder: (context, i) =>
                        Container(color: AppPalette.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final cardContent = tester.getRect(find.byType(ChartCarousel));
    final viewport = tester.getRect(find.byType(PageView));

    expect(
      viewport.left,
      lessThan(cardContent.left),
      reason:
          'the carousel must bleed past the left edge of the card it sits '
          'in; it starts at ${viewport.left} against ${cardContent.left}',
    );
    expect(
      cardContent.left - viewport.left,
      moreOrLessEquals(inset, epsilon: 0.5),
      reason:
          'the left bleed is not the inset: ${cardContent.left - viewport.left}',
    );
    expect(
      viewport.right - cardContent.right,
      moreOrLessEquals(inset, epsilon: 0.5),
      reason:
          'the carousel stops ${viewport.right - cardContent.right}dp short '
          'of the card\u2019s right edge. A bleed on one side only is the '
          'symptom of a width that was clamped by the surrounding stretch.',
    );
    // And the right edge really is outside, which is the half a one-sided bleed
    // loses.
    expect(
      viewport.right,
      greaterThan(cardContent.right),
      reason: 'the carousel never reaches past the right edge of the card',
    );
  });

  testWidgets('the bleed grows with the inset, for any inset', (tester) async {
    for (final inset in <double>[0, 8, 24]) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppBackground(
            child: Center(
              child: SizedBox(
                width: 411,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                    child: ChartCarousel(
                      itemCount: 1,
                      height: 100,
                      inset: inset,
                      labelBuilder: (i) => 'page $i',
                      onPointerActive: (_) {},
                      itemBuilder: (context, i) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final cardContent = tester.getRect(find.byType(ChartCarousel));
      final viewport = tester.getRect(find.byType(PageView));
      expect(
        cardContent.left - viewport.left,
        moreOrLessEquals(inset, epsilon: 0.5),
        reason: 'inset $inset: left bleed disagrees',
      );
      expect(
        viewport.right - cardContent.right,
        moreOrLessEquals(inset, epsilon: 0.5),
        reason: 'inset $inset: right bleed disagrees',
      );
    }
  });
}
