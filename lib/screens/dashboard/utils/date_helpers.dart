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

/// Formats an axis tick, choosing a clock time or a date for the range.
String formatAxisTick(double value, {required bool spansMultipleDays}) =>
    spansMultipleDays ? formatAxisDate(value) : formatAxisTime(value);

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