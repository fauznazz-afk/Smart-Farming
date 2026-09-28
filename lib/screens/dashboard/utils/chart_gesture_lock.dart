import 'package:flutter/widgets.dart';

/// Blocks horizontal paging while a chart is being dragged.
///
/// This used to be done by wrapping the whole `PageView` in a
/// `ValueListenableBuilder` and swapping `physics` between `PageScrollPhysics` and
/// `NeverScrollableScrollPhysics`. That looked cheap and was not: the chart covers
/// most of the PV, AC and Battery pages, so almost every scroll gesture started on
/// one, and each `onPointerDown` / `onPointerUp` rebuilt the entire `PageView` —
/// twice per gesture. `PageView.builder` gets a fresh delegate on every rebuild,
/// so `_buildPage` re-ran for every cached page, re-laying out the ambient
/// background, the app bar and each page's closure list.
///
/// Reading the flag at gesture time removes the rebuild entirely. The physics
/// object is constructed once per build of the dashboard, holds a closure, and
/// `Scrollable` asks it whether to accept an offset when a drag begins.
///
/// The base physics is kept and delegated to, so page snapping still works when no
/// chart is being touched. Swapping in `NeverScrollableScrollPhysics` instead would
/// have silently dropped that behaviour.
@immutable
class ChartGestureLockPhysics extends ScrollPhysics {
  const ChartGestureLockPhysics({
    this.basePhysics,
    required this.isLocked,
  });

  /// Whatever physics the `PageView` would otherwise use. Delegated to rather than
  /// replaced, so this is a gate and not a substitute.
  final ScrollPhysics? basePhysics;

  /// Consulted when a drag begins, not when the widget is built.
  final bool Function() isLocked;

  @override
  ScrollPhysics applyTo(ScrollPhysics? ancestor) {
    // If the ancestor is already a ChartGestureLockPhysics, return it directly
    // to avoid infinite wrapping. This is the key fix for the infinite scroll
    // bug: without this guard, each applyTo call would wrap the physics again,
    // creating a chain of ChartGestureLockPhysics objects that never terminates.
    if (ancestor is ChartGestureLockPhysics) return ancestor;
    final applied = basePhysics?.applyTo(ancestor);
    if (applied is ChartGestureLockPhysics) return applied;
    return ChartGestureLockPhysics(
      basePhysics: applied,
      isLocked: isLocked,
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (isLocked()) return false;
    final base = basePhysics;
    if (base != null) return base.shouldAcceptUserOffset(position);
    return super.shouldAcceptUserOffset(position);
  }

  @override
  bool get allowUserScrolling => !isLocked();
}
