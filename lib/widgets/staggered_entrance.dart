import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/dashboard/utils/design_tokens.dart';

/// Fades and slides [child] up on the first build, and never again.
///
/// **First build only, because the screens under it rebuild on their own
/// clock.** A report reloads every five minutes and an alarm list rebuilds on
/// every filter tap; an entrance that replayed on those would flash the page
/// for a reason the user did not cause.
///
/// **[index] buys the stagger, and it is capped so the last section starts no
/// later than [AppMotion.page].** Past that the sections stop being an
/// entrance and become a queue.
///
/// **Reduce-motion wins.** `MediaQuery.disableAnimationsOf` is the platform's
/// own setting; when it is set the child is simply present.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.child, this.index = 0});

  final Widget child;

  /// Position in the list, from zero. Sections beyond the cap start together.
  final int index;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    // The step is derived from the page clock rather than written in
    // milliseconds: the last capped section still finishes by AppMotion.page.
    final delayMs = math.min(widget.index, _kMaxStaggered) *
        _kStaggerStep.inMilliseconds;
    final totalMs = delayMs + AppMotion.container.inMilliseconds;
    _controller = AnimationController(
      duration: Duration(milliseconds: totalMs),
      vsync: this,
    );
    final begin = delayMs / totalMs;
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1.0, curve: AppMotion.enter),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// `shortcut:` five sections, which is every screen this was written for;
/// upgrade to a step derived from the section count if a page wants more.
const int _kMaxStaggered = 4;

/// How far apart two consecutive sections start. 4 x 50 + 300 = 500 ms.
/// `shortcut:` a fixed 50 ms step; upgrade to one derived from the section
/// count if a page carries more than five.
const Duration _kStaggerStep = Duration(milliseconds: 50);
