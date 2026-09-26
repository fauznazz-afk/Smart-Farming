import 'package:flutter/material.dart';

/// Wraps a dashboard card so tapping it jumps to the matching detail tab.
///
/// This was copy-pasted into three widgets at 20 lines each, two of them
/// private, and the public copy had no consumer at all. Three identical wrappers
/// is three places to update the moment the tap behaviour should differ, and
/// there is no reason for it to differ.
class DashboardShortcut extends StatelessWidget {
  const DashboardShortcut({
    super.key,
    required this.pageIndex,
    required this.onSelect,
    required this.child,
  });

  final int pageIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(pageIndex),
      child: child,
    );
  }
}
