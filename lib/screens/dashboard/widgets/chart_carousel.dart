import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

/// One chart per page, swiped horizontally.
class ChartCarousel extends StatefulWidget {
  const ChartCarousel({
    super.key,
    required this.itemCount,
    required this.height,
    required this.itemBuilder,
    required this.labelBuilder,
    required this.onPointerActive,
    required this.inset,
  });

  final int itemCount;
  final double height;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final String Function(int index) labelBuilder;
  final ValueChanged<bool> onPointerActive;
  final double inset;

  @override
  State<ChartCarousel> createState() => _ChartCarouselState();
}

class _ChartCarouselState extends State<ChartCarousel> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final accent = AppPalette.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **The carousel's bleed, and it cannot be a negative padding.**
        //
        // The PageView is `inset` wider on both sides than the card it sits in,
        // so a page's chart reaches the card's rounded edge and the next page
        // shows a sliver of itself as a swipe affordance. The pages still get
        // `inset` of their own padding inside `itemBuilder`, so what is widened
        // is the viewport and not the content.
        //
        // It was `Padding(horizontal: -inset)` for a long time, and that throws
        // now: `RenderPaddingBox`'s constructor asserts `padding.isNonNegative`,
        // so a debug build fails the moment the PV, AC or battery page lays out
        // its charts. A release build ignores the assert, which is why it went
        // unseen — the same code was fine in one mode and a red screen in the
        // other.
        //
        // Replacing it with a plain wider `SizedBox` is not enough either, and
        // this is the part that costs an afternoon: the `Column` is `stretch`, so
        // it hands every child a **tight** width, and `BoxConstraints.enforce`
        // clamps a `SizedBox(width: parentWidth + 2 * inset)` back down to
        // `parentWidth`. The `+ 2 * inset` never takes effect, so a translate
        // on top of it bleeds one side only and stops `2 * inset` short of the
        // card's right edge. Measured on the working build: every chart on the
        // PV, AC and battery pages sat 32dp off-centre, with `flutter analyze`
        // clean and the whole suite green.
        //
        // `OverflowBox` is the one box whose job is a child larger than the
        // space offered, it does not clip, and it keeps the band's own size at
        // the column's strict width so the dots row below still lines up.
        LayoutBuilder(
          builder: (context, constraints) {
            // The `SizedBox` is load-bearing: the `Column` is `stretch`, so it
            // hands its children a tight width and an unbounded height, and a
            // `sizedByParent` box laid out with an unbounded height takes its
            // size from `constraints.smallest` — which the OverflowBox then
            // cannot satisfy and reports as "was given an infinite size during
            // layout". Pinning the band's height first is what makes the box
            // legal; the overflow is meant to be horizontal only.
            return SizedBox(
              height: widget.height,
              child: OverflowBox(
                alignment: Alignment.center,
                maxWidth: double.infinity,
                child: SizedBox(
                  width: constraints.maxWidth + 2 * widget.inset,
                  height: widget.height,
                  child: Listener(
                    onPointerDown: (_) => widget.onPointerActive(true),
                    onPointerUp: (_) => widget.onPointerActive(false),
                    onPointerCancel: (_) => widget.onPointerActive(false),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: widget.itemCount,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.inset,
                        ),
                        child: widget.itemBuilder(context, i),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? accent : faint.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 10),
            Text(
              '${widget.labelBuilder(_index)}  ·  ${_index + 1} of '
              '${widget.itemCount}',
              style: AppType.labelMicro.copyWith(color: faint),
            ),
          ],
        ),
      ],
    );
  }
}
