import 'package:flutter/material.dart';

/// One of the three views inside the Power tab.
///
/// PV, AC and Battery are three views of one electrical system, so they are one
/// destination with a selector rather than three destinations. See the navigation
/// comment in `dashboard_screen.dart` for the arithmetic and for why the grouping
/// is also the honest one.
class PowerSubTab {
  const PowerSubTab({
    required this.prefix,
    required this.label,
    required this.icon,
  });

  /// The key this view's history is stored under, and what `historyKeysForPrefix`
  /// and `historyDeviceForPrefix` resolve. Unchanged from when these were three
  /// separate tabs, so the existing history cache, chart keys and tests all keep
  /// working.
  final String prefix;

  final String label;
  final IconData icon;
}

const List<PowerSubTab> kPowerSubTabs = [
  PowerSubTab(prefix: 'pv', label: 'PV', icon: Icons.wb_sunny_outlined),
  PowerSubTab(prefix: 'ac', label: 'AC', icon: Icons.power_outlined),
  PowerSubTab(
    prefix: 'battery',
    label: 'Battery',
    icon: Icons.battery_5_bar_outlined,
  ),
];
