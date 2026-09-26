import 'package:flutter/material.dart';

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
            ButtonSegment(value: false, label: Text('Harian')),
            ButtonSegment(value: true, label: Text('Bulanan')),
          ],
          selected: {monthly},
          onSelectionChanged: (value) {
            onMonthlyChanged(value.first);
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPickPeriod,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            monthly ? formatMonthLabel(selectedDate) : formatDateLabel(selectedDate),
          ),
        ),
      ],
    );
  }
}