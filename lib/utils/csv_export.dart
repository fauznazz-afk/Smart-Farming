import '../models/telemetry_model.dart';

/// Builds a CSV of raw telemetry, one row per distinct sample time.
///
/// ## Why wide, and why with holes in it
///
/// A CSV has to choose between two shapes. The long one — `time, device, key,
/// value`, one row per sample — is lossless and trivial, and it is the right
/// answer for a pipeline. The wide one — `time, power_dc, power_ac, soc, …` —
/// is what a person opening the file in a spreadsheet actually wants, and it is
/// what a supervisor reading a report can read without writing a script.
///
/// The temptation with a wide table is to *forward-fill*: carry the last value
/// of a key forward until the next sample. **That is fabrication.** The PZEM
/// reports every 30 seconds and the fish tank reports every five minutes, and a
/// forward-filled row asserts the fish tank was fine at 09:00:30 when nothing
/// was actually said about it. Every hole in this table is a moment the device
/// did not speak, and it stays a hole.
///
/// ## Two timestamps that coincide become one row
///
/// That is a merge, not an average and not a choice between them. Two keys that
/// both reported at 09:00:00 both have that row; a key that did not report then
/// has an empty cell in it. No value is invented in either direction.
String buildTelemetryCsv({
  required Map<String, List<TelemetryPoint>> history,
}) {
  if (history.isEmpty) return '';

  // Union of every sample time across every key, de-duplicated. A `Set` plus a
  // sort keeps this O(n log n) without assuming any two keys share a clock.
  final stamps = <int>{};
  for (final points in history.values) {
    for (final point in points) {
      stamps.add(point.timestamp.millisecondsSinceEpoch);
    }
  }
  if (stamps.isEmpty) return '';
  final ordered = stamps.toList()..sort();

  // One pass per key into a map of epoch -> value, so the row loop below is a
  // lookup rather than a scan. With a fortnight of 30-second samples across
  // eight keys this is the difference between linear and quadratic.
  final byKey = <String, Map<int, double>>{};
  for (final entry in history.entries) {
    final rows = <int, double>{};
    for (final point in entry.value) {
      rows[point.timestamp.millisecondsSinceEpoch] = point.value;
    }
    byKey[entry.key] = rows;
  }

  final keys = history.keys.toList()..sort();

  final buffer = StringBuffer();
  buffer.writeln(['time', ...keys].map(_escapeCsv).join(','));
  for (final stamp in ordered) {
    final cells = <String>[_formatStamp(stamp)];
    for (final key in keys) {
      final value = byKey[key]?[stamp];
      // Empty, not zero. A missing sample and a sample of 0.0 are different
      // facts and this file is evidence.
      cells.add(value == null ? '' : _formatNumber(value));
    }
    buffer.writeln(cells.map(_escapeCsv).join(','));
  }
  return buffer.toString();
}

/// Wraps a cell per RFC 4180.
///
/// Only reached by a key or a timestamp that actually contains the delimiter,
/// which today is never — but the file is meant to survive someone adding a
/// device whose name has a comma in it, and doing that later means auditing
/// every consumer.
String _escapeCsv(String value) {
  if (!value.contains(RegExp(r'[",\n\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// Local wall-clock time, because this file is read by a person in the same
/// timezone as the greenhouse.
///
/// **Not `toIso8601String`, which is UTC.** A sample that arrived at 14:00 local
/// would be written as 07:00Z, and every row would then disagree with the app
/// that produced it — including across a DST boundary, where the same local
/// hour appears twice.
String _formatStamp(int epochMs) {
  final local = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final date =
      '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
  return '$date ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// Full precision, and always a decimal point.
///
/// **Never `toStringAsFixed`.** `850` and `850.4` are different measurements and
/// a spreadsheet must be able to tell them apart; rounding to one place here
/// would destroy data on the way out of an app whose whole job is to report what
/// a device said.
String _formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '';
  return value == value.roundToDouble() && value.abs() < 1e15
      ? value.toStringAsFixed(1)
      : value.toString();
}