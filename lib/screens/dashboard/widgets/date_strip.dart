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
    required this.theme,
    required this.accentColor,
    required this.onSelectDate,
    required this.onPickRange,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  /// The appearance to paint, as an `AppTheme`.
  ///
  /// Required rather than a `bool`, and not optional either: the strip's only
  /// per-theme decision is the fill of the *selected* chip, and
  /// `DateStripChip` puts `raised` and `insetDeep` on opposite branches of the
  /// same widget. Passing a boolean down would give a Dracula chip the app's
  /// dark alphas, which are solved for a different page luminance.
  final AppTheme theme;

  final Color accentColor;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPickRange;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The width the widest day abbreviation needs at the current text scale.
  ///
  /// Measured with a real [TextPainter] rather than guessed, because the two
  /// inputs move independently: the abbreviation length is ours and fixed, and
  /// the scale is the user's and can be anything. A constant is therefore wrong
  /// on one of the two axes by construction.
  ///
  /// **The style is resolved from the ambient `DefaultTextStyle`, not written out
  /// here**, and that is the part that took a second attempt. The first version
  /// used `const TextStyle(fontSize: 10, fontWeight: w600)`, which is missing two
  /// things the theme supplies: `family: Roboto` and `letterSpacing: 0.3`. The
  /// letter spacing is 0.3 per character, so a three-letter name was under-
  /// measured by 0.9 px, and the strip went on clipping `Mon` and `Wed` at 2x
  /// after a "fix" that the test suite and a release build both accepted.
  ///
  /// A measurement that hand-writes the style it is measuring is a copy of the
  /// chip's own style, and copies drift — the same lesson `FEATURE.md` records
  /// about the surface list in `color_helpers_test.dart`, arriving from the
  /// opposite direction. Resolving it means there is nothing left to keep in
  /// sync except the two numbers in [DateStripChip] that describe the chip's
  /// box rather than its text.
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
              // **The `Material` is load-bearing, and so is the 48.**
              //
              // `IconButton` is an `InkWell`, and `Scaffold`'s single `Material`
              // paints its ink features *below* its own child subtree. The
              // dashboard body is `AppBackground` -> an opaque
              // `ColoredBox(AppSurfaces.page(theme))`, so an `IconButton` in the
              // body with no nearer `Material` has its splash painted underneath
              // that `ColoredBox`. The ripple is not faint; it is invisible.
              //
              // This app's whole vocabulary is "no ripple, geometric press
              // instead" -- the nav bar presses by changing its decoration -- so a
              // button with no ink was not quieter than its neighbours. It was the
              // one control in the row with no feedback at all, and the user had
              // no way to tell the tap had landed.
              //
              // `MaterialType.transparency` because the page colour behind the
              // strip must show through.
              //
              // The size is the other half. This was `tightFor(28, 28)` with
              // `VisualDensity.compact`, which lands at 26-28 dp against the 48 dp
              // floor -- and this is the only date control on the Power,
              // Hydroponics and Fish tabs. The row is already 68 dp tall because
              // of the chips, so 48 costs no vertical space; it moves the caption
              // 20 dp right, which is the honest trade for a target you can hit.
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
                    color: faintColor(theme.isDark),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // **A `Wrap`, and the row overflowed before this.**
              //
              // The trailing hint ("Pick a day") was a plain `Text` in the `Row`, so
              // it was a non-flex child and got unbounded main-axis width. At a 2x
              // system font scale on a 360 dp viewport it claimed 16 px more than
              // the row had and `RenderFlex` drew the stripe across it; at 3.0 it
              // was 37 px. Nothing caught it because at 1.0 there is roughly 150 px
              // of slack, and the two layouts that overflow are exactly the ones
              // nobody opens.
              //
              // `Wrap` rather than a second `Flexible` because the question is
              // genuinely "do these two fit on one line", and a `Wrap` answers that
              // by flowing the hint onto the next line instead of by letting both
              // halves become unreadable. Two flex children competing for one line
              // is a negotiation with no right answer; a second line is a right
              // answer.
              //
              // The label gets no `maxLines` for the same reason. It was `maxLines:
              // 2, ellipsis`, and at 2.5 on 381 dp the `Expanded` was left with so
              // little width by the greedy hint that it rendered as a bare `…`.
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _rangeLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: faintColor(theme.isDark),
                      ),
                    ),
                    Text(
                      rangeStart != null ? 'Range' : 'Pick a day',
                      style: TextStyle(
                        fontSize: 11,
                        color: faintColor(theme.isDark),
                      ),
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

            // **Chips get the width their text needs, and the strip scrolls when
            // that is more than a fair share.**
            //
            // This was measured on an emulator at a 2x system font scale, and the
            // result was worse than an overflow stripe: every day name was
            // ellipsised to a single letter, so the strip read
            // `S... M... W... T... T... F... S...`. The previous fix for this same
            // font-scale defect claimed in a comment that "a day name that reads
            // 'Mo' instead of 'Mon' is still a day name, unlike a truncated
            // reading" -- and that claim was wrong. `S` is not a day name, and it is
            // ambiguous on top of that: Sunday and Saturday are the same letter,
            // and so are Tuesday and Thursday. A row of single letters is a
            // calendar that cannot answer "which day is this".
            //
            // So the width is *derived* rather than guessed, and the strip degrades
            // by scrolling instead of by amputating text. Measuring is possible
            // because the abbreviation is ours, not the platform's locale: a
            // hard-coded 42 dp would be another number that is right on the phone
            // this was measured on and wrong on a narrower one.
            // The text's own width, plus the box the chip puts around it, plus one
            // logical pixel. The last term is not fudge: the measured width and
            // the laid-out width can differ by a fraction of a pixel through
            // rounding, and a chip that is 0.4 px too narrow clips — which is
            // exactly the failure the first attempt at this shipped.
            final needed =
                _widestDayNameWidth(context) +
                2 *
                    (DateStripChip.horizontalPadding +
                        DateStripChip.borderWidth) +
                1;
            final chipWidth = needed > fairShare ? needed : fairShare;
            final scrolls = chipWidth > fairShare + 0.5;

            final chips = Row(
              // **`crossAxisAlignment: start`, because the chips now grow with
              // the user's font scale** and `Row` centres its children by default.
              // At 1.0 every chip is the same height so this is a no-op; at 2.0 the
              // taller ones would otherwise be vertically centred against shorter
              // ones and the row would be taller than the content needs.
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
                      theme: theme,
                      accentColor: accentColor,
                      onTap: () => onSelectDate(days[i]),
                    ),
                  ),
                ],
              ],
            );

            if (!scrolls) return chips;

            // A scrollbar is deliberately not requested. This is a gesture-only
            // affordance on a control the user reaches by tapping a known position,
            // and a permanently visible track would sit inside the card's shadow
            // and read as part of the design. The cost is that the affordance is
            // invisible -- see the trade recorded below.
            //
            // The trade, stated: the strip starts scrolled to the oldest day, so a
            // user at 2x whose selection is *today* has to scroll to reach it. Today
            // is the last chip, and it is also the default, which is exactly the
            // wrong way round. Fixing that properly needs a `ScrollController` and
            // a `Scrollable.ensureVisible` after first layout, which cannot run from
            // a `LayoutBuilder` without a second frame -- so this is left as a
            // recorded gap rather than a guess, and the calendar button beside the
            // strip is the way to reach a specific day regardless of text size.
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

  /// States what the charts are actually showing.
  ///
  /// This used to describe the span of the seven chips instead, so tapping a
  /// chip left the label reading a range that no longer matched the selection,
  /// while the detail pages showed the correct single day. Two screens
  /// disagreed about the same state, and the Overview one was the wrong one.
  String _rangeLabel() {
    if (rangeStart != null && rangeEnd != null) {
      return '${rangeStart!.day} ${monthName(rangeStart!.month)} '
          '${rangeStart!.year} – '
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
