import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import 'shortcut.dart';

/// Snapshot values shown for the battery.
///
/// Carries `power` and not just `current` because the charge direction has to be
/// read from the same key the hero card reads. This used to derive it from
/// `current < 0`, which was a second, independent interpretation of the BMS sign
/// using a different telemetry key: the hero card said one thing and this strip
/// said the opposite, on the same screen, from the same pack. Two readings of one
/// measurement is worse than either being alone.
typedef BatteryStatus = ({
  double soc,
  double voltage,
  double current,
  double power,
});

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
    required this.onOpenBattery,
    required this.lowSocThreshold,
    required this.activeAlerts,
  });

  final BatteryStatus battery;
  final AcStatus ac;
  final bool isDark;
  final Color seedColor;
  /// Takes the user to the battery readings.
  ///
  /// A bare callback rather than a page index, because Battery is no longer a
  /// destination of its own: it is a view inside the Power tab, so getting there
  /// takes two steps and only the screen knows what they are. Hard-coding an index
  /// here is how this widget ended up pointing at the wrong tab the moment the
  /// navigation changed.
  final VoidCallback onOpenBattery;

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
    // One interpretation, shared with the hero card. The three states rather than
    // the old `current < 0` binary, because this BMS reports 0.00 A for stretches
    // while idling and a bare comparison flips the label several times a minute
    // while asserting a direction the data does not establish.
    final chargeState = batteryChargeState(battery.power);
    final charging = chargeState == BatteryChargeState.charging;

    return DashboardShortcut(
      onTap: onOpenBattery,
      semanticLabel: 'Battery and grid status. Opens the battery readings.',
      child: AppCard(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Verdict(
              // Low charge is the actionable state, so the alert glyph wins over
              // the direction glyph. Previously the icon was a full charging
              // battery whenever the SOC was healthy, which drew a battery
              // charging on a pack that was discharging — a third signal, and the
              // one most likely to be read before the label.
              icon: !batteryOk
                  ? Icons.battery_alert
                  : switch (chargeState) {
                      BatteryChargeState.charging => Icons.battery_charging_full,
                      BatteryChargeState.discharging => Icons.battery_5_bar_rounded,
                      BatteryChargeState.standby => Icons.battery_std_rounded,
                    },
              // Only charging is worth naming here. Standby and discharging both
              // read as "Battery", which says less than the hero card but never
              // contradicts it.
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
    color: appDivider(isDark: dark, opacity: dark ? 0.10 : 0.08),
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
    final color = ok ? appPrimaryText(isDark) : statusBad(isDark);
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
