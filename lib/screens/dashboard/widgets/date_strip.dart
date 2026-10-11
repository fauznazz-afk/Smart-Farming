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
    //
    // **Italic, because the selected chip is the one that is drawn that way.**
    // The brief asks for the active day to lean forward, and a slanted Inter is
    // a fraction wider than an upright one at the same weight and size. The probe
    // measured upright and the strip laid out for upright, so the chip with the
    // *least* room to give — the one carrying the widest string — was the one
    // that overflowed. Measuring the wider of the two variants means the strip is
    // sized for the worst case rather than for the average one, which is the only
    // asymmetry that matters here: every chip gets the same width either way.
    final style = AppType.labelMicro.copyWith(fontStyle: FontStyle.italic);
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
        Row(
          children: [
            // **The legend leads and the calendar button trails, because the
            // strip has to read as one grid.**
            //
            // It used to be the other way round: a `Padding(horizontal: 2)` with
            // a 48dp `IconButton` and a 4dp gap, then an `Expanded` legend. That
            // put the legend text's left edge at 2 + 48 + 4 = 54dp while the chip
            // row below started at 0, and it pulled the header's right edge in to
            // maxWidth - 2 while the chips ran to maxWidth. Three different edges
            // inside one widget, which is what the Overview calendar's "slightly
            // off-centre" look was: nothing was misaligned by much and nothing
            // was aligned, and the eye reads the sum rather than the parts.
            //
            // Trailing the button collapses it to two, and both of them are now
            // the chip row's: the legend starts where the first chip starts, and
            // the button's touch target ends where the last chip ends. The 48dp
            // target is kept deliberately — it is below the 48dp minimum tap
            // size, and shrinking it to match a text baseline would be trading an
            // accessibility floor for optical tidiness.
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
          ],
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
