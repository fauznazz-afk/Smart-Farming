import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../utils/design_tokens.dart';
import 'terminal_panel.dart' show slotNumber;

/// One side of the power summary: a name, a live figure, and one caption.
class PowerSummaryColumn {
  const PowerSummaryColumn({
    required this.label,
    required this.icon,
    required this.figure,
    required this.unit,
    this.caption,
    this.soc,
    this.onTap,
  });

  /// `PV`, `AC`, `BATTERY` — the column's own name, not a sentence.
  final String label;
  final IconData icon;

  /// The live figure, already formatted, or `--` when the device is silent.
  final String figure;
  final String unit;

  /// The one qualifying line: today's kWh, the load share, the charge state.
  final String? caption;

  /// State of charge, percent. Drawn as its own figure under the live wattage
  /// on the battery column so the two numbers do not share one caption line.
  final double? soc;

  final VoidCallback? onTap;
}

/// PV, AC and battery side by side, with today's energy and the runtime.
///
/// **It replaced the 7-day sheet, and it keeps the three things that sheet was
/// the only route to**: the daily production target, the projected battery
/// runtime, and the tap-through to the energy report. Retiring a number the user
/// can still set in Settings would have been silent, which is the failure this
/// page has already paid for once.
///
/// The frame is [AppCard]'s recipe read through tokens — surface, hairline, one
/// lift — so a light ramp needs no edit here. Nothing is a hardcoded fill.
class PowerSummaryPanel extends StatelessWidget {
  const PowerSummaryPanel({
    super.key,
    required this.columns,
    this.todayKwh,
    this.energyLoading = false,
    this.energyError,
    this.targetKwh,
    this.targetProgress,
    this.runtimeHours,
    this.onOpenEnergyReport,
  });

  final List<PowerSummaryColumn> columns;

  /// Today's PV production, kWh.
  final double? todayKwh;
  final bool energyLoading;
  final String? energyError;

  /// The user's own daily target, from Settings. Null hides the row.
  final double? targetKwh;

  /// Progress toward [targetKwh], as a fraction of 1.
  final double? targetProgress;

  /// Projected battery runtime, hours. Null hides the row.
  final double? runtimeHours;

  /// The sheet title was this route before; the header chevron is the same route.
  final VoidCallback? onOpenEnergyReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppSurfaces.surface,
        borderRadius: AppRadius.all(AppRadius.card),
        border: AppBorders.hairlineBorder,
        boxShadow: AppShadows.subtle,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(onOpenEnergyReport: onOpenEnergyReport),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.cardPadding,
                AppSpacing.md,
                AppSpacing.cardPadding,
                AppSpacing.cardPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < columns.length; i++) ...[
                          if (i > 0)
                            Container(
                              width: 1,
                              color: AppSurfaces.border,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          Expanded(child: _Column(column: columns[i])),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(color: AppSurfaces.border, height: 1),
                  const SizedBox(height: AppSpacing.md),
                  _TodayRow(
                    todayKwh: todayKwh,
                    loading: energyLoading,
                    error: energyError,
                  ),
                  if (targetKwh != null && targetKwh! > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _MetaRow(
                      icon: Icons.flag_rounded,
                      label: 'Target',
                      value: slotNumber(targetKwh, decimals: 1),
                      unit: 'kWh',
                      trailing: targetProgress == null
                          ? null
                          : '${(targetProgress! * 100).clamp(0, 999).toStringAsFixed(0)}%',
                    ),
                  ],
                  if (runtimeHours != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _MetaRow(
                      icon: Icons.battery_charging_full_rounded,
                      label: 'Runtime',
                      value: slotNumber(runtimeHours, decimals: 1),
                      unit: 'h',
                      trailing: 'battery',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onOpenEnergyReport});

  final VoidCallback? onOpenEnergyReport;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.md,
        AppSpacing.cardPadding,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'POWER SUMMARY',
            style: AppType.slotKey.copyWith(
              color: AppSurfaces.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (onOpenEnergyReport != null) ...[
            Text(
              'REPORT',
              style: AppType.slotMicro.copyWith(color: AppPalette.accent),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppPalette.accent,
            ),
          ],
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOpenEnergyReport == null)
          row
        else
          InkWell(onTap: onOpenEnergyReport, child: row),
        Divider(color: AppSurfaces.border, height: 1),
      ],
    );
  }
}

/// One of the three columns: name, live figure with its unit, and a caption.
class _Column extends StatelessWidget {
  const _Column({required this.column});

  final PowerSummaryColumn column;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                column.icon,
                size: 14,
                color: AppSurfaces.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    column.label,
                    maxLines: 1,
                    style: AppType.slotMicro.copyWith(
                      color: AppSurfaces.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // The whole figure-and-unit shrinks rather than overflowing, the
          // `terminal_panel.dart` rule: the reading is never the thing clipped.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  column.figure,
                  maxLines: 1,
                  style: AppType.figureTerm.copyWith(
                    color: AppSurfaces.onSurface,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  column.unit,
                  style: AppType.figureUnit.copyWith(
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (column.soc != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${slotNumber(column.soc, decimals: 0)}%',
              maxLines: 1,
              style: AppType.figureTerm.copyWith(
                color: AppSurfaces.onSurface,
              ),
            ),
          ],
          if (column.caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              column.caption!,
              maxLines: 2,
              style: AppType.captionSmall.copyWith(
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (column.onTap == null) return body;
    return InkWell(
      onTap: column.onTap,
      borderRadius: AppRadius.all(AppRadius.sm),
      child: body,
    );
  }
}

/// `TODAY` — the kWh figure, or what state the request is in.
class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.todayKwh,
    required this.loading,
    required this.error,
  });

  final double? todayKwh;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final String value;
    final String trailing;
    if (loading) {
      value = '...';
      trailing = 'Loading';
    } else if (error != null) {
      // A failed request is not a zero day — the distinction this repo has been
      // caught conflating twice already.
      value = '--';
      trailing = 'Energy history failed';
    } else {
      value = slotNumber(todayKwh, decimals: 2);
      trailing = 'kWh';
    }

    return Row(
      children: [
        Icon(
          Icons.bolt_rounded,
          size: 16,
          color: AppSurfaces.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'TODAY',
          style: AppType.slotMicro.copyWith(
            color: AppSurfaces.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppType.numeralMd.copyWith(color: AppSurfaces.onSurface),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          trailing,
          style: AppType.captionSmall.copyWith(
            color: AppSurfaces.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One optional line: the target, or the projected runtime.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppSurfaces.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: AppType.slotMicro.copyWith(
            color: AppSurfaces.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppType.numeralMd.copyWith(color: AppSurfaces.onSurface),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          trailing == null ? unit : '$unit \u00b7 $trailing',
          style: AppType.captionSmall.copyWith(
            color: AppSurfaces.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The battery column's caption, built from the one sign convention in the app.
///
/// Kept in a function so a caller cannot be tempted into `voltage * current`:
/// the BMS publishes `power`, and only the state-of-charge trend settles which
/// sign means which direction. See `lib/utils/battery_sign.dart`.
String batterySummaryCaption(
  double? powerWatts,
  double? soc,
  double? voltage,
) {
  final parts = <String>[];
  if (powerWatts != null) parts.add(batteryChargeState(powerWatts).label);
  if (soc != null) parts.add('${slotNumber(soc, decimals: 0)}%');
  if (voltage != null) parts.add('${slotNumber(voltage, decimals: 1)} V');
  return parts.isEmpty ? 'No battery data' : parts.join(' \u00b7 ');
}
