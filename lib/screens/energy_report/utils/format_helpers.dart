/// Formats a date as DD/MM/YYYY.
String formatDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Formats a date as HH:00.
String formatHourLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:00';

/// Formats a date as MonthName YYYY (Indonesian).
String formatMonthLabel(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

const _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Escapes a value for CSV output.
String escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

/// Generates a comparison label between current and previous values.
String comparisonLabel(double current, double? previous) {
  if (previous == null) return 'Belum ada data pembanding';
  if (previous <= 0) return 'Periode sebelumnya: 0 kWh';
  final change = ((current - previous) / previous * 100).round();
  if (change == 0) return 'Sama dengan periode sebelumnya';
  return '${change > 0 ? '+' : ''}$change% dari periode sebelumnya';
}