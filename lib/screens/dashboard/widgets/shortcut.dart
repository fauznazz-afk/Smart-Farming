import 'package:flutter/material.dart';

/// Wraps a dashboard card so tapping it jumps to the view it summarises.
///
/// This was copy-pasted into three widgets at 20 lines each, two of them
/// private, and the public copy had no consumer at all. Three identical wrappers
/// is three places to update the moment the tap behaviour should differ, and
/// there is no reason for it to differ.
///
/// It takes a callback rather than a page index because the destinations are no
/// longer one-to-one with pages: the battery lives inside the Power tab, so
/// reaching it means selecting a sub-view as well as navigating. Which index that
/// is, and what has to happen before it, is the screen's business.
class DashboardShortcut extends StatelessWidget {
  const DashboardShortcut({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
