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

/// Returns the short Indonesian day name (Sen, Sel, Rab, etc.).
String dayNameShort(int weekday) => const [
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
][(weekday - 1) % 7];

/// Returns the full Indonesian day name (Senin, Selasa, etc.).
String dayNameFull(int weekday) => const [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
][(weekday - 1) % 7];

/// Returns the Indonesian month name.
String monthName(int month) => const [
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
][month - 1];