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
    required this.theme,
    required this.monthly,
    required this.selectedDate,
    required this.pvKwh,
    required this.acKwh,
    required this.buckets,
    required this.previousTotals,
  });

  /// The appearance to paint, as an [AppTheme] rather than a `bool`.
  ///
  /// It exists because the two metrics below are [AppTile]s, and a tile paints
  /// `AppSurfaces.input` — which has a Dracula step of its own, and Dracula's
  /// `#21222C` is *darker* than its page while the app's dark input is lighter
  /// than its page. A `bool` would have put the app's direction on Dracula's
  /// surface. `faintColor` still takes a `bool` and gets `theme.isDark` below.
  final AppTheme theme;
  final bool monthly;
  final DateTime selectedDate;
  final double pvKwh;
  final double acKwh;
  final List<EnergyBucket> buckets;
  final PeriodTotals? previousTotals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppSkeuo.fillGradient(
            AppSurfaces.card(theme),
            foreground: AppSkeuo.textSide(theme),
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthly
                  ? 'Summary ${formatMonthLabel(selectedDate)}'
                  : 'Summary ${formatDateLabel(selectedDate)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _TotalMetric(
                  theme: theme,
                  label: 'PV production',
                  value: pvKwh,
                  previous: previousTotals?.pvKwh,
                  color: const Color(0xFFFFC857),
                  icon: Icons.wb_sunny_outlined,
                ),
                const SizedBox(width: 10),
                _TotalMetric(
                  theme: theme,
                  label: 'AC usage',
                  value: acKwh,
                  previous: previousTotals?.acKwh,
                  color: const Color(0xFF69B7FF),
                  icon: Icons.electrical_services_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${totalSampleCount(buckets)} samples • ${buckets.length} ${monthly ? 'days' : 'hours'} with data',
              style: TextStyle(
                fontSize: 12,
                color: faintColor(theme.isDark),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TotalMetric extends StatelessWidget {
  const _TotalMetric({
    required this.theme,
    required this.label,
    required this.value,
    required this.previous,
    required this.color,
    required this.icon,
  });

  final AppTheme theme;
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
          label: '$label: ${value.toStringAsFixed(2)} kilowatt-hours. ${comparisonLabel(value, previous)}',
          // The same object as the dashboard's energy metric tile, so it is the
          // same widget: two hand-written washes at two radii (16 there, 14
          // here) for one conceptual thing.
          child: AppTile(
            theme: theme,
            accent: color,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, color: color, size: 19)),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  '${value.toStringAsFixed(2)} kWh',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comparisonLabel(value, previous),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: faintColor(theme.isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}