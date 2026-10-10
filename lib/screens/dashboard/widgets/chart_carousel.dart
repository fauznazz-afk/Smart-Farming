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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: -widget.inset),
          child: SizedBox(
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