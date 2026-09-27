/// Formats a date as DD/MM/YYYY.
String formatDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Formats a date as HH:00.
String formatHourLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:00';

/// Formats a date as MonthName YYYY.
String formatMonthLabel(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Escapes a value for CSV output.
String escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

/// Generates a comparison label between current and previous values.
String comparisonLabel(double current, double? previous) {
  if (previous == null) return 'No comparison data yet';
  if (previous <= 0) return 'Previous period: 0 kWh';
  final change = ((current - previous) / previous * 100).round();
  if (change == 0) return 'Same as the previous period';
  return '${change > 0 ? '+' : ''}$change% from the previous period';
}