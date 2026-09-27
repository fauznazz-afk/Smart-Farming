import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import 'shortcut.dart';

/// Snapshot values shown for the battery.
typedef BatteryStatus = ({double soc, double voltage, double current});

/// Snapshot values shown for the AC side.
typedef AcStatus = ({
  double voltage,
  double current,
  double power,
  double frequency,
});

/// One-line verdicts for the three things a user checks on a glance.
///
/// This replaced two side-by-side cards that were about 200 px tall, and the
/// duplication was the reason: the hero card already showed a SOC gauge, the
/// battery page already had voltage and current, and the AC page had voltage,
/// current, power and frequency. So the one thing this section actually added
/// was a stable-or-not verdict on the grid, and it cost 200 px to say it.
///
/// A verdict also ages better than raw numbers. A row of readings is something
/// the user has to interpret every time; "STABIL" is not.
class SystemStatusStrip extends StatelessWidget {
  const SystemStatusStrip({
    super.key,
    required this.battery,
    required this.ac,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
    required this.onNavigate,
    required this.lowSocThreshold,
    required this.activeAlerts,
  });

  final BatteryStatus battery;
  final AcStatus ac;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;
  final ValueChanged<int> onNavigate;

  /// The user's low-SOC limit, so the verdict says what it is judged against.
  final double lowSocThreshold;

  /// How many alarms are currently active, or zero.
  final int activeAlerts;

  @override
  Widget build(BuildContext context) {
    final gridOk = (ac.frequency - 50).abs() < 2 &&
        ac.voltage > 200 &&
        ac.voltage < 240;
    final batteryOk = battery.soc >= lowSocThreshold;
    final charging = battery.current < 0;

    return DashboardShortcut(
      pageIndex: 3,
      onSelect: onNavigate,
      child: LiquidGlassCard(
        isDark: isDark,
        performanceMode: performanceMode,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Verdict(
              icon: batteryOk
                  ? Icons.battery_charging_full
                  : Icons.battery_alert,
              label: charging ? 'Charging' : 'Battery',
              value: '${battery.soc.toStringAsFixed(0)}%',
              ok: batteryOk,
              // The threshold is printed because "baterai 18%" means nothing on
              // its own; whether that is a problem is the user's setting.
              detail: 'min ${lowSocThreshold.toStringAsFixed(0)}%',
              isDark: isDark,
              seedColor: seedColor,
            ),
            _divider(isDark),
            _Verdict(
              icon: gridOk ? Icons.check_circle_outline : Icons.error_outline,
              label: 'AC grid',
              value: gridOk ? 'Stable' : 'Unstable',
              ok: gridOk,
              detail: '${ac.voltage.toStringAsFixed(0)} V · '
                  '${ac.frequency.toStringAsFixed(0)} Hz',
              isDark: isDark,
              seedColor: seedColor,
            ),
            if (activeAlerts > 0) ...[
              _divider(isDark),
              _Verdict(
                icon: Icons.notifications_active,
                label: 'Alarm',
                value: '$activeAlerts',
                ok: false,
                detail: 'active',
                isDark: isDark,
                seedColor: seedColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(bool dark) => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08),
  );
}

/// An icon, a headline verdict, and one line of supporting detail.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    required this.detail,
    required this.isDark,
    required this.seedColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final String detail;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    // The verdict is a warning, so only a warning is coloured. A healthy
    // reading is printed in ordinary text and the tick stays green.
    //
    // The value used to take the status colour unconditionally, which put three
    // green elements next to an amber theme's amber everything and read as two
    // unrelated colour systems. "70%" is not a status; whether 70% is enough is
    // the user's own threshold, and the icon already says it is fine. A low
    // battery still turns the number red, which is the case that matters.
    final color = ok
        ? (isDark ? Colors.white : Colors.black87)
        : statusBad(isDark);
    // Same rule for the icon: the accent when there is nothing to report, a
    // status colour when there is. A green tick beside an amber theme is the
    // clearest statement that two palettes are on screen at once, and it says
    // nothing the icon shape does not already say.
    final iconColor = ok
        ? themeColor(seedColor: seedColor, lightness: isDark ? 0.68 : 0.38)
        : statusBad(isDark);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: faintColor(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: faintColor(isDark)),
          ),
        ],
      ),
    );
  }
}
