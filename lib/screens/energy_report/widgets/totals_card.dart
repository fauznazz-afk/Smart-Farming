import 'package:flutter/material.dart';

import '../utils/format_helpers.dart';
import '../utils/period_buckets.dart';
import '../../../services/energy_report_service.dart';

class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.isDark,
    required this.monthly,
    required this.selectedDate,
    required this.pvKwh,
    required this.acKwh,
    required this.buckets,
    required this.previousTotals,
  });

  final bool isDark;
  final bool monthly;
  final DateTime selectedDate;
  final double pvKwh;
  final double acKwh;
  final List<EnergyBucket> buckets;
  final PeriodTotals? previousTotals;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  isDark: isDark,
                  label: 'PV production',
                  value: pvKwh,
                  previous: previousTotals?.pvKwh,
                  color: const Color(0xFFFFC857),
                  icon: Icons.wb_sunny_outlined,
                ),
                const SizedBox(width: 10),
                _TotalMetric(
                  isDark: isDark,
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
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalMetric extends StatelessWidget {
  const _TotalMetric({
    required this.isDark,
    required this.label,
    required this.value,
    required this.previous,
    required this.color,
    required this.icon,
  });

  final bool isDark;
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
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
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
                    color: isDark ? Colors.white60 : Colors.black54,
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