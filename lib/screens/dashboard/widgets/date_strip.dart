import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/date_helpers.dart';

/// Seven-day quick-pick strip with a calendar button for custom ranges.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.isDark,
    required this.accentColor,
    required this.performanceMode,
    required this.onSelectDate,
    required this.onPickRange,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool isDark;
  final Color accentColor;
  final bool performanceMode;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPickRange;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Pilih rentang tanggal',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                onPressed: onPickRange,
                icon: Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _rangeLabel(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rangeStart != null ? 'Custom range' : 'Last 7 days',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 6.0;
            final chipWidth =
                (constraints.maxWidth - gap * (days.length - 1)) / days.length;
            return Row(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: chipWidth,
                    child: GlassDateChip(
                      width: chipWidth,
                      dayName: dayNameShort(days[i].weekday),
                      dayNumber: days[i].day,
                      isSelected: rangeStart == null && _isSameDay(days[i], selectedDate),
                      isDark: isDark,
                      accentColor: accentColor,
                      onTap: () => onSelectDate(days[i]),
                      performanceMode: performanceMode,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _rangeLabel() {
    if (rangeStart != null && rangeEnd != null) {
      return '${rangeStart!.day} ${monthName(rangeStart!.month)} '
          '${rangeStart!.year} – '
          '${rangeEnd!.day} ${monthName(rangeEnd!.month)} ${rangeEnd!.year}';
    }
    final first = days.first;
    final last = days.last;
    if (first.month == last.month) {
      return '${first.day}–${last.day} ${monthName(last.month)} ${last.year}';
    }
    return '${first.day} ${monthName(first.month)} – '
        '${last.day} ${monthName(last.month)} ${last.year}';
  }
}
