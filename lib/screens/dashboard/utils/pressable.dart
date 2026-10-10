import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// A control that sinks into the page while it is held down.
///
/// **This existed as a parameter and was never used.** `AppCard` has taken a
/// `pressed` flag since the soft-UI migration, and nothing in the app ever
/// passed it, so the app shipped a press vocabulary with no way to reach it. The
/// flag added a small extra shadow; it did not invert the surface, which is the
/// only thing that reads as a press in this style.
///
/// The old animation was a swap between the neumorphic [AppElevation.raised] and
/// [AppElevation.pressed] shadow pairs, not a fade, because the light-source rule
/// required the bounce to flip direction on press. Every surface in the app was lit from the top left. A press
/// put the light source *inside* the object, so the bounce that was up and to
/// the left had to arrive from down and to the right instead. Cross-fading the
/// two pairs spent the middle of the animation with a dark halo and a light
/// halo in their old positions simultaneously, and that read as a rendering
/// fault rather than as a button being held.
///
/// **Under the new flat categorical system, press feedback is opacity and colour
/// only (via [AppCard.pressed] which steps the fill darker), not geometry.** The
/// shadow system is gone. The scale nudge is 1.5%, which is below the threshold
/// where a control starts to look like it is shrinking, and it is on the *whole*
/// widget rather than the shadow so the icon inside moves with it.
///
/// `AppMotion.press` is 150ms down. The release is deliberately faster at 120ms:
/// a finger lifting should feel like release rather than like a slow settle, and
/// the asymmetry is the whole reason a press feels like a physical push instead
/// of a colour cross-fade.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.pressedScale = 0.985,
    this.semanticLabel,
    this.selected,
    this.enabled = true,
  }) : assert(
          child != null || builder != null,
          'Pressable needs either a child or a builder',
        );

  /// A fixed subtree, for the common case where only the scale should change.
  final Widget? child;

  /// Called with the current pressed state, for a control whose *decoration*
  /// has to change too — which in this style is most of them, because a press
  /// that is only a scale reads as a bounce rather than as a surface being
  /// pushed.
  ///
  /// Passing both is a mistake rather than a merge: the two would scale the same
  /// content twice, so the nudge would compound. The assert above requires one
  /// of them; a caller passing both gets the builder's output, because that is
  /// the branch that can express a press.
  final Widget Function(bool pressed)? builder;

  /// The tap itself, for a control that has no `InkWell` of its own.
  final VoidCallback? onTap;

  /// The three pointer phases, exposed separately because the nav bar keeps its
  /// own `InkWell` for the ripple and this owns the press. Two gesture
  /// recognisers on one subtree is the arrangement that works there: the
  /// `InkWell` wins the tap, and these still fire because this is the outer,
  /// more permissive recogniser. A caller that only wants the press and not a
  /// ripple sets these three and leaves [onTap] null.
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;

  final double pressedScale;
  final String? semanticLabel;
  final bool? selected;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  /// Guards the release against a pointer that was cancelled rather than lifted.
  ///
  /// Without it, a scroll gesture that starts on a nav item leaves it stuck in
  /// the pressed state after the finger leaves, because the gesture arena hands
  /// the pointer to the scrollable and `onTapCancel` is what tells this widget
  /// that nothing was tapped. This is the whole difference between a control
  /// that feels physical and one that occasionally looks broken.
  void _setDown(bool value) {
    if (!mounted || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedScale(
      scale: _down ? widget.pressedScale : 1.0,
      duration: _down ? AppMotion.press : _release,
      curve: _down ? AppMotion.enter : AppMotion.both,
      child: widget.builder?.call(_down) ?? widget.child!,
    );

    if (widget.onTap != null ||
        widget.onTapDown != null ||
        widget.onTapUp != null ||
        widget.onTapCancel != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: widget.enabled ? (_) => _setDown(true) : null,
        onTapUp: widget.enabled ? (_) => _setDown(false) : null,
        onTapCancel: widget.enabled ? () => _setDown(false) : null,
        child: content,
      );
    }

    if (widget.semanticLabel != null) {
      content = Semantics(
        label: widget.semanticLabel,
        button: true,
        selected: widget.selected,
        enabled: widget.enabled,
        container: true,
        child: content,
      );
    }

    return content;
  }

  /// Faster than [AppMotion.press], and only ever used going up.
  static const Duration _release = Duration(milliseconds: 120);
}