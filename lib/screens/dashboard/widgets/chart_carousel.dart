import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';

/// One chart per page, swiped horizontally.
///
/// **Why this exists.** The greenhouse declared four chart groups and the fish
/// tank three, and they were stacked — so reaching the TDS plot meant scrolling
/// past Temperature, Humidity and Light first, on a phone, every time. Four
/// cards is a lot of thumb.
///
/// The electrical pages declare a single group each, and they keep their plain
/// stacked layout: a carousel holding one chart is a carousel the user cannot
/// swipe, which is worse than the thing it replaced because it looks like it
/// should work.
///
/// **The header, the date-range picker and the Live indicator stay outside.** They
/// describe the page, not the chart, and a picker that slid away with the
/// content would be a control you could not see while you were using it. Only
/// the plot moves.
///
/// **The dots are not decoration.** A carousel with no position indicator looks
/// exactly like a chart you have finished with, and the reason this was not
/// shipped earlier is that the alternative was scrolling rather than any
/// confusion about what a swipe would do.
class ChartCarousel extends StatefulWidget {
  const ChartCarousel({
    super.key,
    required this.itemCount,
    required this.height,
    required this.itemBuilder,
    required this.labelBuilder,
    required this.isDark,
    required this.seedColor,
    required this.onPointerActive,
    required this.inset,
  });

  final int itemCount;

  /// The slot height, which is the tallest card among the pages.
  ///
  /// Every chart card already declares its own height (`ChartGroup.height`), so
  /// this is derived rather than guessed — and it is why the carousel costs no
  /// vertical accuracy: the card paints into the height it asked for, and the
  /// tallest one in the set sizes the slot.
  final double height;

  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The name of the chart at [index], shown beside the dots.
  final String Function(int index) labelBuilder;

  final bool isDark;
  final Color seedColor;

  /// Reports that a touch is happening somewhere inside the carousel.
  ///
  /// **This is what makes the swipe work at all, and it is not decoration.** The
  /// carousel sits inside the dashboard's four-tab `PageView`, so there are two
  /// horizontal pagers on top of each other and the outer one wins the gesture by
  /// default: the first version of this swiped from the Temperature chart to the
  /// *Fish Tank tab*, which is the exact failure `ChartGestureLockPhysics` exists
  /// to prevent.
  ///
  /// The lock works by the dashboard gating its own pager, and it is already
  /// wired for charts through `onPointerActive`. Reusing it is the point: a
  /// second, carousel-specific gesture arbitration would be a second thing to get
  /// wrong. `shouldAcceptUserOffset` is consulted per re-layout, and the
  /// carousel's own drag causes one, which is the path the class documents.
  final ValueChanged<bool> onPointerActive;

  /// How far the slot is pushed outside the page's content column, and the card
  /// pushed back inside it by the same amount.
  ///
  /// **A `PageView` clips its children, and that would amputate this card's
  /// shadow.** `AppElevation.raised` is a contact shadow at offset 3 / blur 6
  /// plus an ambient one at offset 9 / blur 22, so the ambient reaches 20dp at
  /// one sigma and 31dp at two. Clipped at the page margin the card would lose
  /// most of the half of its shadow that separates it from the page — and losing
  /// it unevenly is worse than losing it, because the card stops matching every
  /// other card on the page. It was visible on the device before this existed.
  ///
  /// The slot is therefore as wide as the screen and the card sits a page margin
  /// inside it, so the shadow has exactly the room it has everywhere else on the
  /// page — which is what `_pageHorizontalMargin` was derived for in the first
  /// place, and no card here is narrower than any other.
  final double inset;

  @override
  State<ChartCarousel> createState() => _ChartCarouselState();
}

class _ChartCarouselState extends State<ChartCarousel> {
  late final PageController _controller = PageController();

  /// Which chart is on screen.
  ///
  /// Held in state rather than read back off the controller, because the dots
  /// have to repaint on every settled page and `PageController.page` is only
  /// reliable after a frame.
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(widget.isDark);
    final accent = themeColor(
      seedColor: widget.seedColor,
      lightness: widget.isDark ? 0.68 : 0.42,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The negative margin plus the matching padding: the slot is pushed out
        // to the screen edges and the card is pushed back to the page column, so
        // the card's ambient shadow lands in the margin instead of being clipped
        // by the `PageView`. See [ChartCarousel.inset] for the measurement.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: -widget.inset),
          child: SizedBox(
            height: widget.height,
            // `PageView` rather than a horizontal `ListView`: it clips its
            // neighbours by default, which is what makes the next chart read as
            // "there is another one" instead of as part of this one.
            child: Listener(
              // `Listener` rather than `GestureDetector`, because the carousel
              // only needs to *observe* the touch. It must not claim it: the
              // `PageView` below is what turns the drag into a page change, and
              // a competing recognizer here would be the same arena fight the
              // dashboard pager is already losing.
              onPointerDown: (_) => widget.onPointerActive(true),
              onPointerUp: (_) => widget.onPointerActive(false),
              onPointerCancel: (_) => widget.onPointerActive(false),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.itemCount,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.inset),
                  child: widget.itemBuilder(context, i),
                ),
              ),
            ),
          ),
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
                // The active dot is wider rather than a different colour. Three
                // small marks of one hue at two sizes reads as "position", while
                // a recoloured dot would introduce a colour that means nothing
                // else anywhere in the app — the objection `AGENTS.md` raises
                // about hue being varied automatically.
                width: i == _index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? accent : faint.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 10),
            // The name, because dots alone do not tell you which chart you are
            // looking at and the header above names the page rather than the plot.
            Text(
              '${widget.labelBuilder(_index)}  ·  ${_index + 1} of '
                  '${widget.itemCount}',
              style: TextStyle(fontSize: 11, color: faint),
            ),
          ],
        ),
      ],
    );
  }
}