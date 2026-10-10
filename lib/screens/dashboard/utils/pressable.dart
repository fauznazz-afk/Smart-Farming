import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// A control that sinks into the page while it is held down.
///
/// **This existed as a parameter and was never used.** `AppCard` has taken a
/// `pressed` flag since the soft-UI migration, and nothing in the app ever
/// passed it, so the app shipped a press vocabulary with no way to reach it.
/// Under the previous system the flag only added a small extra shadow, which is
/// not enough to read as a press; the flag now *drops* the stamped shadow,
/// which is the geometry that makes it read as one.
///
///
/// The old animation was a swap between the neumorphic shadow pairs, not a
/// fade, because the light-source rule required the bounce to flip direction on
/// press. Every surface in the app was lit from the top left. A press
/// put the light source *inside* the object, so the bounce that was up and to
/// the left had to arrive from down and to the right instead. Cross-fading the
/// two pairs spent the middle of the animation with a dark halo and a light
/// halo in their old positions simultaneously, and that read as a rendering
/// fault rather than as a button being held.
///
/// **Under the brutalist system, press feedback is scale and the stamped
/// shadow, and both are geometry.** A press flattens the surface into the page:
/// [AppCard.pressed] drops its hard offset shadow, so the card moves *toward*
/// the canvas rather than away from it, and the whole widget shrinks by 5% at
/// the same time. That is the brief's `active:scale-95`, and it is a change of
/// the same *kind* the old press was — the old one swapped a raised shadow pair
/// for an inset one and relied on nothing but geometry to say "pushed".
///
/// The scale nudge is 5%, which is the figure the brief states outright rather
/// than one tuned here. It is on the *whole* widget rather than on the shadow,
/// so the icon inside moves with it.
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
    this.pressedScale = 0.95,
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
