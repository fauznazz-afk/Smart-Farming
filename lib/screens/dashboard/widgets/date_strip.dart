import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/date_helpers.dart';
import '../utils/design_tokens.dart';

/// Seven day quick-pick strip. Tapping a day selects it.
///
/// **The chip itself is not in this file.** It is `DateStripChip` in
/// `liquid_glass.dart`, and its recipe lives there too: the brief's corner radius,
/// unselected = [AppSurfaces.surface] with the neutral hairline, selected = a
/// solid accent fill with the accent's own ink — the brief's `chip-active`, with
/// no border and no shadow of its own. The selected day label is also the one
/// place in the brief that sets **italic at 900 weight**, on the theory that
/// leaning the type forward implies motion.
///
/// **No header and no range control.** The custom-range trigger is one of the
/// hero card's own actions now, and this strip is that card's footer; the strip
/// is only the seven chips. [dateSelectionLabel] still renders the trigger's
/// tooltip.
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
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<DateTime> onSelectDate;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _widestDayNameWidth(BuildContext context) {
    // **The style the chip actually draws, not a hand-written near-miss.**
    //
    // This used to merge `DefaultTextStyle.of(context).style` with
    // `fontSize: 10, fontWeight: w600` — a *measurement* style that disagreed
    // with the *drawing* style on two of the three properties that decide a
    // label's width. `DateStripChip` sets the day name in `AppType.labelMicro`:
    // 10sp at **w600**, with `letterSpacing: 0.04em`, which on a three-letter
    // day name is another 1.2dp the probe never asked for. So the strip measured
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
        // **No header row, and no control of its own.** The row used to hold a
        // `Spacer` and a calendar `IconButton`, which after the weather glyph was
        // removed left a strip of empty space above the chips with one button
        // floating at its right end. The trigger is now one of the hero card's
        // own actions and the strip is that card's footer, so the dates sit
        // inside the surface describing "now" instead of in a row of their own.
        // [dateSelectionLabel] still supplies the button's tooltip.
        LayoutBuilder(
          builder: (context, constraints) {
            // **The gap is a ladder, and it steps down before the type does.**
            //
            // This was one fixed `6`, and when the widest day name needed more
            // than a fair share the whole row went into a
            // `SingleChildScrollView` — so a 381 dp phone showed six days and
            // half of the seventh with no scrollbar and no hint that a seventh
            // existed. The user's read was "the calendar is cut off", which is
            // exactly right.
            //
            // The alternatives were considered and rejected: shrinking the font
            // is out (`liquid_glass.dart` documents why, and
            // `absent_and_failed_states_test.dart` catches it), and clipping is
            // the defect itself. What *can* give is the air between the chips,
            // so the strip now takes the widest gap it can afford and only
            // falls through to scrolling when even zero does not fit — which is
            // the 3x system-font case the scroll view was actually built for.
            // **12, not 16, and it has to agree with the chip.** This is 6 per
            // side of `DateStripChip`'s padding plus the unselected chip's 1 px
            // hairline, which sits *inside* the padding rather than outside it —
            // so it changes the visual weight of the edge and not the box. It was
            // written as 16 while the chip was padded 8, which is the kind of
            // duplication that survives until one of the two moves. If the chip's
            // padding changes, this is the number to change with it.
            //
            // **`+ 1` is the hairline on each side, and it was missing from the
            // `needed` probe below** — which is why the chips sat edge to edge:
            // the width the probe asked for was narrower than the chip's own box.
            // **6 per side, and the chip's own box carries the hairline** --
            // `DateStripChip` paints it inside its padding, so it costs no
            // width. Asking for 13 made `needed` wider than the chip, and the
            // `max` below then sized every chip past its fair share until the
            // seven of them overflowed the row by 3.4 dp.
            const chipChrome = 12;
            final needed = _widestDayNameWidth(context) + chipChrome;
            final slack =
                (constraints.maxWidth - needed * days.length) /
                (days.length - 1);
            const ladder = [8.0, 6.0, 4.0, 2.0, 0.0];
            final gap = ladder.firstWhere(
              (g) => g <= slack,
              orElse: () => ladder.last,
            );

            final fairShare =
                (constraints.maxWidth - gap * (days.length - 1)) / days.length;

            // **Never narrower than the text needs.** `fairShare` is the share
            // the row can afford after the gap; `needed` is the floor the chip
            // cannot go under without wrapping its day name. Taking the max is
            // what keeps the ladder from buying a gap with the label, which is
            // the trade the comment above forbids.
            final chipWidth = needed > fairShare ? needed : fairShare;
            final scrolls = chipWidth > fairShare + 0.5;

            final chips = Row(
              // **`min`, so the row is as wide as its seven chips.** A `Row`
              // inside a scroll view still receives the viewport's tight width
              // as its constraint, and the default `max` main-axis size then
              // makes it *that* wide while its children need more — which is
              // the 3.4 px overflow the probe fix uncovered. The row has to
              // size to its content for the scroll view to have anything to
              // scroll over.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
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

}

/// One line describing the strip's current selection, e.g. `Today`, `Yesterday`
/// or `Sat, 11 Oct 2026`, or the two dates of a range.
///
/// **Top-level, because the trigger is no longer the strip's.** The calendar
/// button is a hero-card action now and this is its tooltip; the function used to
/// be private to [DateStrip] when the button lived in the strip's own header.
String dateSelectionLabel({
  required DateTime selectedDate,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  DateTime? now,
}) {
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  if (rangeStart != null && rangeEnd != null) {
    return '${rangeStart.day} ${monthName(rangeStart.month)} '
        '${rangeStart.year} \u2013 '
        '${rangeEnd.day} ${monthName(rangeEnd.month)} ${rangeEnd.year}';
  }
  final today = now ?? DateTime.now();
  if (sameDay(selectedDate, today)) return 'Today';
  if (sameDay(selectedDate, today.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  }
  return '${dayNameFull(selectedDate.weekday)}, '
      '${selectedDate.day} ${monthName(selectedDate.month)} ${selectedDate.year}';
}
