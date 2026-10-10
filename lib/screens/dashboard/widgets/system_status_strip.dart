import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
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

    final bool? batteryOk = soc == null ? null : soc >= lowSocThreshold;
    final bool? gridOk = (voltage == null || frequency == null)
        ? null
        : (frequency - 50).abs() < 2 && voltage > 200 && voltage < 240;

    final chargeState = battery.power == null
        ? null
        : batteryChargeState(battery.power!);
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
                      BatteryChargeState.standby => Icons.battery_std_rounded,
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
    // **Full strength, not 10%.** This used to be
    // `AppSurfaces.border.withValues(alpha: 0.10)`, which is a rule you have to
    // lean in to see — and a divider that cannot be seen is not separating the
    // three verdicts, it is just space. The brief has exactly one border colour
    // and one weight for it; `AppDivider` and `appDivider` both draw it at full
    // strength, and this hand-rolled copy was the only thing in the app drawing
    // it fainter. No hue here: a coloured divider between a battery column and
    // an AC column would be a third meaning for those two hues.
    color: AppSurfaces.border,
  );
}

/// An icon, a headline verdict, and one line of supporting detail.
///
/// **A status colour here is ink and never a fill.** The brief's status ramp is
/// for a *condition*, and a condition is stated by a word: [statusBad] paints
/// the icon and the verdict text when something is wrong, and nothing else on the
/// strip changes. A full-strength block of red behind a column would be the
/// "signal the same state three ways" failure `AGENTS.md` already records — tick,
/// triangle and coloured border all at once, reading as a checklist rather than
/// as a reading. It would also put a large saturated fill under a caption, which
/// is the exact shape that lost this repo contrast three times over.
///
/// The healthy half is the same rule run the other way: an in-range reading takes
/// the accent and ordinary text, *not* [statusOk]. A permanent green "all normal"
/// column asserts a condition that is boring when true and occupies the space
/// where a real warning needs to go.
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
                // **900, not 800.** The brief's type scale is 900 for everything
                // that matters, 700 for the uppercase labels and 400 for the
                // rare body line — "there is almost no 400/500", and there is no
                // 800 either. The word in this box *is* the thing that matters
                // on the strip: `Stable` is the whole claim the strip makes, so
                // it wears the display weight, the same weight as every other
                // figure on the Overview page. Held at 15sp rather than the
                // brief's `numeral-lg` 24sp because three of these share one row
                // and the `FittedBox` above already scales them down at large
                // text scales — the size is this strip's own layout decision,
                // the weight is the system's.
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
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
