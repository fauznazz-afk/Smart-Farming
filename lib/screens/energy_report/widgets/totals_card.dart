import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/format_helpers.dart';
import '../utils/period_buckets.dart';
import '../../../services/energy_report_service.dart';

class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.monthly,
    required this.selectedDate,
    required this.pvKwh,
    required this.acKwh,
    required this.buckets,
    required this.previousTotals,
  });

  final bool monthly;
  final DateTime selectedDate;
  final double pvKwh;
  final double acKwh;
  final List<EnergyBucket> buckets;
  final PeriodTotals? previousTotals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthly
                ? 'Summary ${formatMonthLabel(selectedDate)}'
                : 'Summary ${formatDateLabel(selectedDate)}',
            // `headline-md`, the brief's "uppercase card title inside list rows
            // and tiles". It was a hand-written 16/800 — a third weight and a
            // fourth size, neither of them in the brief's scale.
            style: AppType.headlineMd,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _TotalMetric(
                label: 'PV production',
                value: pvKwh,
                previous: previousTotals?.pvKwh,
                color: categoryColor(MetricCategory.pv),
                icon: Icons.wb_sunny_outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              _TotalMetric(
                label: 'AC usage',
                value: acKwh,
                previous: previousTotals?.acKwh,
                color: categoryColor(MetricCategory.ac),
                icon: Icons.electrical_services_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${totalSampleCount(buckets)} samples • ${buckets.length} ${monthly ? 'days' : 'hours'} with data',
            // The brief's metadata line: uppercase, wide-tracked, secondary
            // ink. The literal 12px/faint it replaces is what
            // `label-uppercase-md` already is.
            style: AppType.labelUppercase.copyWith(color: faintColor),
          ),
        ],
      ),
    );
  }
}

class _TotalMetric extends StatelessWidget {
  const _TotalMetric({
    required this.label,
    required this.value,
    required this.previous,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final double? previous;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MergeSemantics(
        child: Semantics(
          label:
              '$label: ${value.toStringAsFixed(2)} kilowatt-hours. ${comparisonLabel(value, previous)}',
          child: AppTile(
            // `AppTile` draws the 2px categorical *bottom* border from this
            // accent — the brief's `border-b-2` colour code. It used to draw a
            // 1px frame on all four sides at 20% alpha, which is the tint-chip
            // recipe applied to the wrong component; that change is already in
            // `liquid_glass.dart` and reaches this tile through this argument.
            accent: color,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  // 24 — the brief's default size "in chrome". Its
                  // iconography band puts *hero* tile icons at 32–40, and this
                  // is a 2-up tile inside a card, not a hero: a 32px glyph
                  // beside a `numeral-lg` figure crowds the number the tile
                  // exists to show. 19 was a size in no band at all.
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  // The brief's micro metadata line, in the measured
                  // secondary ink. 11px was not in the scale.
                  style: AppType.labelMicro.copyWith(color: faintColor),
                ),
                const SizedBox(height: AppSpacing.xs),
                // **The figure and the unit are two spans, because the brief
                // says they are two things.** `numeral-lg` is the "data
                // shouter" at 24/900; `label-uppercase-sm` is the unit. Both
                // used to be one string at 16/800, which put a metadata-sized
                // label on the number this screen exists to show.
                //
                // Baseline-aligned rather than stacked, so the pair still
                // occupies one line at the width a 2-up tile has.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value.toStringAsFixed(2),
                      style: AppType.numeralLg.copyWith(
                        color: AppSurfaces.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'kWh',
                      style: AppType.labelMicro.copyWith(color: faintColor),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  comparisonLabel(value, previous),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelMicro.copyWith(color: faintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
