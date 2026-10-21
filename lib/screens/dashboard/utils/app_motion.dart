/// The motion the whole app shares.
///
/// **One place for the clocks.** A duration written at a call site is a
/// duration that can drift from the one next to it, and this app's record is a
/// page and a nav-bar bubble that ran on different clocks and arrived apart.
/// Every duration and curve below is either [AppMotion] or a named constant
/// here, and no call site writes a millisecond of its own.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The clock for "the user changed tab".
///
/// **One duration and one curve, in two places.** The nav bar's bubble and
/// the dashboard's page slide are two halves of one gesture: if they run on
/// different clocks, the bubble arrives before the content or after it, and
/// the tab reads as two events instead of one.
///
/// **[AppMotion.container] and `easeInOutCubic`.** The bubble was already on
/// this clock, so the page is the half that moved. `easeInOutCubic` is a glide
/// — `AppMotion.both` is `easeInCubic`, which leaves the origin at walking
/// pace and arrives at full speed before stopping, which is the right feel for
/// something appearing and the wrong feel for something travelling.
class AppMotionTab {
  const AppMotionTab._();

  static const Duration duration = AppMotion.container;
  static const Curve curve = Curves.easeInOutCubic;
}

/// The app's one screen transition.
///
/// **Fade and a short slide up, and the same in reverse.** Every push used to
/// be a different thing: the login screen had its own `PageRouteBuilder` and
/// every other screen was a `MaterialPageRoute`, which slides the whole page
/// in from the side. Two transitions in one app means the user has to learn
/// two different answers to "what happens when I press this".
///
/// **[AppMotion.page] forward and [AppMotion.state] back, and both are the
/// app's own clocks.** [AppMotion.page] is what the app already calls a
/// screen change; a route on a different one would arrive before or after the
/// screen it is opening.
Route<T> appPageRoute<T>({
  required Widget page,
  Duration duration = AppMotion.page,
  Duration reverseDuration = AppMotion.state,
  Curve curve = AppMotion.enter,
  Curve reverseCurve = AppMotion.exit,
  double slide = 0.035,
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _FadeSlide(
          animation: animation,
          slide: slide,
          curve: curve,
          reverseCurve: reverseCurve,
          child: child,
        ),
  );
}

/// The transition's own widget, so the [CurvedAnimation] it creates is
/// disposed with it rather than left on the route's animation.
class _FadeSlide extends StatefulWidget {
  const _FadeSlide({
    required this.animation,
    required this.curve,
    required this.reverseCurve,
    required this.slide,
    required this.child,
  });

  final Animation<double> animation;
  final Curve curve;
  final Curve reverseCurve;

  /// How far down the page starts, as a fraction of its own height.
  final double slide;

  final Widget child;

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide> {
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: widget.curve,
    reverseCurve: widget.reverseCurve,
  );

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.slide),
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// A figure that counts to its new value instead of jumping to it.
///
/// **The tween is inside the widget, so nothing above it rebuilds.** The
/// dashboard polls every ten seconds and announces the change through a
/// revision counter; a figure that re-rendered the tree above it on every
/// frame of its own animation would put the whole page back on the rebuild
/// path.
///
/// **It starts at the value it was given, so a card that opens shows the
/// reading and not a count-up from zero.** The first build paints the figure
/// as it is; only a *change* starts an animation.
///
/// **A figure that does not print a number is not animated.** `--`,
/// `Discharging` and `40.1 / 71.6 / 94.9` are words and triples, and there is
/// nothing to count between them — they are painted exactly as they arrive.
class TweenedFigure extends StatefulWidget {
  const TweenedFigure({
    super.key,
    required this.text,
    required this.builder,
    this.duration = AppMotion.state,
  });

  /// The figure, as the app already prints it.
  final String text;

  /// Builds the figure from the text, so the caller keeps its own style, its
  /// own unit and its own semantics.
  final Widget Function(BuildContext context, String text) builder;

  final Duration duration;

  @override
  State<TweenedFigure> createState() => _TweenedFigureState();
}

class _TweenedFigureState extends State<TweenedFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  /// Where this animation starts.
  double? _from;

  /// Where it is going.
  double? _to;

  /// The precision the target figure is printed at.
  int _decimals = 0;

  /// The text on screen right now.
  ///
  /// **Kept, because it is where the *next* animation starts.** A figure that
  /// changed again while this one was still running has to count on from what
  /// is on screen, not from the value it was heading for.
  late String _painted;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _curve = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _painted = widget.text;
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(TweenedFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text) return;
    final to = _figureNumber(widget.text);
    final from = _figureNumber(_painted);
    if (to == null || from == null) {
      // **Nothing to count between, so it jumps.** A word, a triple, an absent
      // reading: there is no number to interpolate towards.
      _from = null;
      _to = null;
      _painted = widget.text;
      return;
    }
    _from = from;
    _to = to;
    // **The finer of the two precisions, so the count starts on the figure
    // that is already on screen.** The target's own precision applied to the
    // old value would round it: `25.4` heading for `25` would show `25` on
    // the first frame, which is the jump this widget exists to remove.
    _decimals = math.max(
      _figureDecimals(_painted),
      _figureDecimals(widget.text),
    );
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final from = _from;
        final to = _to;
        // **The last frame is the text the caller asked for, verbatim.** The
        // interpolated value is printed at the target's precision, which is the
        // same string for every figure this app prints — but the caller's own
        // text is the one that has to be on screen when the animation is over.
        final text = (from == null || to == null || _curve.value >= 1.0)
            ? widget.text
            : (from + (to - from) * _curve.value).toStringAsFixed(_decimals);
        _painted = text;
        return widget.builder(context, text);
      },
    );
  }
}

/// The number a printed figure carries, or null if it does not print one.
///
/// **Only a plain number counts.** `NaN` and `Infinity` parse, and neither is
/// a reading; a padded number parses too, and re-printing it would drop the
/// padding the caller asked for.
double? _figureNumber(String text) {
  if (text.trim() != text) return null;
  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

/// The decimals a printed figure carries, so the interpolated values are
/// printed at the same precision as the figure they are heading for.
int _figureDecimals(String text) {
  final dot = text.indexOf('.');
  return dot < 0 ? 0 : text.length - dot - 1;
}
