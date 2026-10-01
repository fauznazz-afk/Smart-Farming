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
              Expanded(
                child: Text(
                  _rangeLabel(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: faintColor(theme.isDark),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rangeStart != null ? 'Range' : 'Pick a day',
                style: TextStyle(fontSize: 11, color: faintColor(theme.isDark)),
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
