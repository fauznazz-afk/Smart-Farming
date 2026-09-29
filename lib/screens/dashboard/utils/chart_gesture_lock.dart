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
/// Reading the flag out of build removes the rebuild entirely. The physics
/// object is constructed once per build of the dashboard, holds a closure, and
/// `Scrollable` asks it whether the viewport may be dragged.
///
/// The base physics is kept and delegated to, so page snapping still works when no
/// chart is being touched. Swapping in `NeverScrollableScrollPhysics` instead would
/// have silently dropped that behaviour — and so did delegating only the two
/// methods below, which is how the pager stopped snapping at all. See
/// [createBallisticSimulation] and [allowUserScrolling]'s note for the two that
/// matter. Pinned by `test/chart_gesture_lock_test.dart`.
@immutable
class ChartGestureLockPhysics extends ScrollPhysics {
  const ChartGestureLockPhysics({
    this.basePhysics,
    required this.isLocked,
  });

  /// Whatever physics the `PageView` would otherwise use. Delegated to rather than
  /// replaced, so this is a gate and not a substitute.
  final ScrollPhysics? basePhysics;

  /// Consulted when the viewport re-lays out, and for wheel and trackpad input.
  ///
  /// It is **not** consulted part-way through a touch drag. `Scrollable` decides
  /// once, at layout, whether to install a drag recognizer at all — it asks
  /// `shouldAcceptUserOffset` from `applyNewDimensions` and caches the answer as
  /// `canDrag` — and from then on a touch drag is gated by the presence of that
  /// recognizer, not by this class. A mid-drag re-layout does re-read the flag,
  /// and that is the path a chart drag takes, because `fl_chart` repaints as the
  /// pointer moves. So the gate does bite for chart drags, but by way of a layout
  /// that happens to occur while the finger is down, not by being read at the
  /// start of the gesture as the comment here used to claim.
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

  /// Deliberately not overridden: `allowUserScrolling` is read when the
  /// `Scrollable` decides whether it can drag, which is at build time, not at
  /// gesture time. Overriding it made the lock *sticky* — once a chart drag
  /// turned it off, lifting the finger did not turn it back on, because nothing
  /// rebuilt the `PageView` to re-read it. Paging stayed dead until some
  /// unrelated rebuild happened to arrive, which on a polling dashboard means up
  /// to ten seconds of a pager that ignores you. `shouldAcceptUserOffset` is the
  /// hook that is consulted per gesture, and it is already overridden.
  ///
  /// @override
  /// bool get allowUserScrolling => !isLocked();

  /// Delegates the fling itself, which is what makes this a pager.
  ///
  /// This was the missing piece. Everything else here decides whether a gesture
  /// is *accepted*; nothing decided what happened when it was *released*.
  /// `PageScrollPhysics.createBallisticSimulation` is what springs a fling onto
  /// the next whole page, and without it the release fell through to
  /// `ScrollPhysics`'s plain friction simulation. The pager then coasted to
  /// wherever friction ended and kept taking velocity past the end of the
  /// content — on the Overview tab, eight swipes left landed at page 9 of a
  /// four-page pager. That is the "infinite page" this was reported as.
  ///
  /// `this` is passed as the physics rather than `basePhysics` so the delegate
  /// sees the real tolerance and can still consult the gate if it needs to.
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final base = basePhysics;
    if (base == null) {
      return super.createBallisticSimulation(position, velocity);
    }
    return base.createBallisticSimulation(position, velocity);
  }
}
