/// Formats a number for axis display, removing trailing zeros.
String formatAxisNumber(double value) {
  final formatted = value.toStringAsFixed(2);
  return formatted.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Formats a timestamp as HH:MM for axis display.
String formatAxisTime(double value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

/// Formats a timestamp for an axis spanning more than one day.
///
/// A clock time is ambiguous across a multi-day range, so fall back to a date.
String formatAxisDate(double value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

const double _dayMs = 86400000;

/// Whether a tick is the first one on its calendar day, given the tick spacing.
///
/// The axis interval, not the range, is what decides this. A tick is a day
/// boundary when stepping back one interval from it crosses local midnight.
///
/// **The first version compared epoch days, and the sweep test caught it on the
/// first run.** `value / 86400000` counts days from the Unix epoch, whose day
/// boundary is midnight *UTC*. A user in WIB is seven hours ahead of that, so a
/// tick at local 00:00 is 17:00 UTC the previous day, and stepping back four
/// hours stays inside the same epoch day — the tick at the very start of a day
/// was not recognised as a day turn, and the label that should have carried the
/// date did not. Comparing `DateTime` fields compares the calendar the reader is
/// actually looking at.
bool isDayBoundaryTick(double value, double intervalMs) {
  if (intervalMs <= 0) return true;
  final here = DateTime.fromMillisecondsSinceEpoch(value.toInt());
  final before = DateTime.fromMillisecondsSinceEpoch(
    (value - intervalMs).toInt(),
  );
  return here.year != before.year ||
      here.month != before.month ||
      here.day != before.day;
}

/// Formats an axis tick so that no two adjacent labels say the same thing.
///
/// **The old rule was a switch on the range alone, and it produced four
/// identical labels.** `spansMultipleDays ? DD/MM : HH:MM` means that on any
/// window longer than a day, *every* tick inside a day renders as that day. On
/// the PV chart, which spans three days at a four-hour interval, the axis read
/// `29/09 30/09 30/09 30/09 30/09 01/10` — five ticks, three of them saying
/// nothing at all. A fixed format chosen from a single boolean is exactly the
/// "don't use fixed numbers" problem, one level above the labels.
///
/// The label now says whatever the tick's position makes necessary:
///
///  * a single-day window — the time alone is unambiguous, so it is the whole
///    label;
///  * a multi-day window with a tick interval of a day or more — every tick is a
///    new day, so the date alone is unambiguous and the shortest form wins;
///  * a multi-day window with sub-daily ticks — the date on the first tick of
///    each day and the time on the rest, so the day turns are visible *and* no
///    two neighbours collide.
///
/// The property that matters is the last one, and it is asserted in
/// `date_helpers_test.dart` rather than being left as an intention: for any
/// interval, no two adjacent labels are equal. That property is necessary and not
/// sufficient — the labels also have to *fit* their gap, which is why a day turn
/// prints the date alone. Asserting only distinctness would have passed the
/// version that overlapped on the device.
String formatAxisTick(
  double value, {
  required bool spansMultipleDays,
  double? tickIntervalMs,
}) {
  if (!spansMultipleDays) return formatAxisTime(value);
  if (tickIntervalMs == null || tickIntervalMs >= _dayMs) {
    return formatAxisDate(value);
  }
  return isDayBoundaryTick(value, tickIntervalMs)
      // The date *alone* at a day turn, never the date and the time together.
      //
      // The first version emitted `30/09 01:00`, which is unambiguous and also
      // unrenderable: eleven characters at a six-hour tick spacing is wider than
      // the gap, so on the device the axis read
      // `19:0000/09 01:00 07:00 13:00 19:0001/10 01:00` with the day-turn labels
      // printed on top of their neighbours. The date alone is five characters —
      // the same width as the `01:00` it replaces — and it cannot collide with
      // one, because the neighbours on both sides are times.
      //
      // This is the fix the sweep test could not have predicted and the device
      // found immediately: "no two adjacent labels are equal" is necessary and
      // not sufficient. Labels also have to *fit*.
      ? formatAxisDate(value)
      : formatAxisTime(value);
}

/// Returns the short English day name (Mon, Tue, etc.).
String dayNameShort(int weekday) => const [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
][(weekday - 1) % 7];

/// Returns the full English day name (Monday, Tuesday, etc.).
String dayNameFull(int weekday) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][(weekday - 1) % 7];

/// Returns the English month name.
String monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];
