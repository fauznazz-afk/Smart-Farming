import '../utils/color_helpers.dart';

import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/date_helpers.dart';
import '../utils/design_tokens.dart';

/// Seven-day quick-pick strip with a calendar button for custom ranges.
///
/// **The chip itself is not in this file.** It is `DateStripChip` in
/// `liquid_glass.dart`, and the brief's recipe for it lives there too: 4px
/// corners (`AppRadius.sm`), unselected = [AppSurfaces.surface] with the neutral
/// hairline, selected = a solid [AppPalette.primary] fill with
/// [AppPalette.onHue] ink — the brief's `chip-active`, with no border and no
/// shadow of its own. The selected day label is also the one place in the brief
/// that sets **italic at 900 weight**, on the theory that leaning the type
/// forward implies motion.
///
/// This file owns the strip: the row geometry, the width the chips are given,
/// and the measurement that decides that width. The width probe below is the
/// part that has to agree with the chip, and [_widestDayNameWidth] is where it
/// does.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onSelectDate,
    required this.onPickRange,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPickRange;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _widestDayNameWidth(BuildContext context) {
    // **The style the chip actually draws, not a hand-written near-miss.**
    //
    // This used to merge `DefaultTextStyle.of(context).style` with
    // `fontSize: 10, fontWeight: w600` — a *measurement* style that disagreed
    // with the *drawing* style on two of the three properties that decide a
    // label's width. `DateStripChip` sets the day name in `AppType.labelMicro`:
    // 10sp at **w700**, with `letterSpacing: 0.12em`, which on a three-letter
    // day name is another 3.6dp the probe never asked for. So the strip measured
    // every chip against a style narrower than the one it rendered, and the
    // chips were laid out a few dp too tight for their own contents.
    //
    // **It worked, and it worked by accident.** `date_strip_test.dart` sweeps
    // eight font scales across four viewports and asserts no day name is
    // clipped, and it is green — the `+ 16 + 1` slack below happened to cover the
    // shortfall at every one of those 32 combinations. A shortfall that only has
    // to be covered by slack is a shortfall that a future change to the slack
    // will uncover with the suite still green. Measuring with the real style is
    // the fix; the padding arithmetic is untouched.
    final style = AppType.labelMicro;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final day in days) {
      final painter = TextPainter(
        text: TextSpan(
          text: dayNameShort(day.weekday).toUpperCase(),
          style: style,
        ),
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

            // The chip's own padding is 8 per side. There is no border width to
            // add any more: the unselected chip draws a 1px hairline, which sits
            // *inside* the padding rather than outside it, so it changes the visual
            // weight of the edge and not the box.
            final needed = _widestDayNameWidth(context) + 16 + 1;
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
                      isSelected:
                          rangeStart == null &&
                          _isSameDay(days[i], selectedDate),
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
