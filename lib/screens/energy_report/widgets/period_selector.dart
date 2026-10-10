import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/format_helpers.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.monthly,
    required this.selectedDate,
    required this.onMonthlyChanged,
    required this.onPickPeriod,
  });

  final bool monthly;
  final DateTime selectedDate;
  final ValueChanged<bool> onMonthlyChanged;
  final VoidCallback onPickPeriod;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Daily')),
            ButtonSegment(value: true, label: Text('Monthly')),
          ],
          selected: {monthly},
          onSelectionChanged: (value) {
            onMonthlyChanged(value.first);
          },
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: OutlinedButton.icon(
            onPressed: onPickPeriod,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              monthly ? formatMonthLabel(selectedDate) : formatDateLabel(selectedDate),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
