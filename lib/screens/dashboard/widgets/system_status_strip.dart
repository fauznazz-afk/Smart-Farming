import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart'
import '../utils/design_tokens.dart';
import 'shortcut.dart';

/// Snapshot values shown for the battery.
typedef BatteryStatus = ({
  double? soc,
  double? voltage,
  double? current,
  double? power,
});

/// Snapshot values shown for the AC side.
typedef AcStatus = ({
  double? voltage,
  double? current,
  double? power,
  double? frequency,
});

/// One-line verdicts for the three things a user checks on a glance.
class SystemStatusStrip extends StatelessWidget {
  const SystemStatusStrip({
    super.key,
    required this.battery,
    required this.ac,
    required this.onOpenBattery,
    required this.lowSocThreshold,
    required this.activeAlerts,
  });

  final BatteryStatus battery;
  final AcStatus ac;
  final VoidCallback onOpenBattery;
  final double lowSocThreshold;
  final int activeAlerts;

  @override
  Widget build(BuildContext context) {
    final soc = battery.soc;
    final voltage = ac.voltage;
    final frequency = ac.frequency;

    final bool? batteryOk =
        soc == null ? null : soc >= lowSocThreshold;
    final bool? gridOk = (voltage == null || frequency == null)
        ? null
        : (frequency - 50).abs() < 2 && voltage > 200 && voltage < 240;

    final chargeState =
        battery.power == null ? null : batteryChargeState(battery.power!);
    final charging = chargeState == BatteryChargeState.charging;

    return DashboardShortcut(
      onTap: onOpenBattery,
      semanticLabel: 'Battery and grid status. Opens the battery readings.',
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Verdict(
              icon: batteryOk == null
                  ? Icons.cloud_off_rounded
                  : !batteryOk
                      ? Icons.battery_alert
                      : switch (chargeState!) {
                          BatteryChargeState.charging =>
                            Icons.battery_charging_full,
                          BatteryChargeState.discharging =>
                            Icons.battery_5_bar_rounded,
                          BatteryChargeState.standby =>
                            Icons.battery_std_rounded,
                        },
              label: charging ? 'Charging' : 'Battery',
              value: soc == null ? '--' : '${soc.toStringAsFixed(0)}%',
              ok: batteryOk,
              detail: soc == null
                  ? 'not reporting'
                  : 'min ${lowSocThreshold.toStringAsFixed(0)}%',
              category: MetricCategory.battery,
            ),
            _divider(),
            _Verdict(
              icon: switch (gridOk) {
                null => Icons.cloud_off_rounded,
                true => Icons.check_circle_outline,
                false => Icons.error_outline,
              },
              label: 'AC grid',
              value: switch (gridOk) {
                null => '--',
                true => 'Stable',
                false => 'Unstable',
              },
              ok: gridOk,
              detail: (voltage == null || frequency == null)
                  ? 'not reporting'
                  : '${voltage.toStringAsFixed(0)} V \u00b7 '
                      '${frequency.toStringAsFixed(0)} Hz',
              category: MetricCategory.ac,
            ),
            if (activeAlerts > 0) ...[
              _divider(),
              _Verdict(
                icon: Icons.notifications_active,
                label: 'Alarm',
                value: '$activeAlerts',
                ok: false,
                detail: 'active',
                category: null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppSurfaces.border.withValues(alpha: 0.10),
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
    required this.category,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool? ok;
  final String detail;
  final MetricCategory? category;

  @override
  Widget build(BuildContext context) {
    final color = switch (ok) {
      null => appPrimaryText,
      true => appPrimaryText,
      false => statusBad,
    };
    final iconColor = switch (ok) {
      null => faintColor,
      true => category != null ? categoryColor(category!) : appPrimaryText,
      false => statusBad,
    };
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: AppType.labelMicro.copyWith(color: faintColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                detail,
                maxLines: 1,
                softWrap: false,
                style: AppType.labelMicro.copyWith(color: faintColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}