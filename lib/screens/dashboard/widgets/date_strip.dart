import '../utils/color_helpers.dart';
import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/date_helpers.dart';
import '../utils/design_tokens.dart';

/// Seven-day quick-pick strip with a calendar button for custom ranges.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.accentColor,
    required this.onSelectDate,
    required this.onPickRange,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final Color accentColor;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPickRange;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _widestDayNameWidth(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    );
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final day in days) {
      final painter = TextPainter(
        text: TextSpan(text: dayNameShort(day.weekday), style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Material(
                type: MaterialType.transparency,
                child: IconButton(
                  tooltip: 'Pick a date range',
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onPickRange,
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: faintColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _rangeLabel(),
                      style: AppType.labelUppercase.copyWith(color: faintColor),
                    ),
                    Text(
                      rangeStart != null ? 'Range' : 'Pick a day',
                      style: AppType.labelMicro.copyWith(color: faintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 6.0;
            final fairShare =
                (constraints.maxWidth - gap * (days.length - 1)) / days.length;

            final needed =
                _widestDayNameWidth(context) +
                2 *
                    (DateStripChip.horizontalPadding +
                        DateStripChip.borderWidth) +
                1;
            final chipWidth = needed > fairShare ? needed : fairShare;
            final scrolls = chipWidth > fairShare + 0.5;

            final chips = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: chipWidth,
                    child: DateStripChip(
                      width: chipWidth,
                      dayName: dayNameShort(days[i].weekday),
                      dayNumber: days[i].day,
                      isSelected: rangeStart == null && _isSameDay(days[i], selectedDate),
                      accentColor: accentColor,
                      onTap: () => onSelectDate(days[i]),
                    ),
                  ),
                ],
              ],
            );

            if (!scrolls) return chips;

            return ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: chips,
              ),
            );
          },
        ),
      ],
    );
  }

  String _rangeLabel() {
    if (rangeStart != null && rangeEnd != null) {
      return '${rangeStart!.day} ${monthName(rangeStart!.month)} '
          '${rangeStart!.year} \u2013 '
          '${rangeEnd!.day} ${monthName(rangeEnd!.month)} ${rangeEnd!.year}';
    }
    final today = DateTime.now();
    if (_isSameDay(selectedDate, today)) return 'Today';
    if (_isSameDay(selectedDate, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return '${dayNameFull(selectedDate.weekday)}, '
        '${selectedDate.day} ${monthName(selectedDate.month)} ${selectedDate.year}';
  }
}