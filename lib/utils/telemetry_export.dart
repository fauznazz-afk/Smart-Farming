import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../models/telemetry_model.dart';
import '../screens/dashboard/utils/history_range.dart';
import '../services/thingsboard_api.dart';
import 'csv_export.dart';

/// A stable, short column prefix per device, so a file from two installations
/// of this app reads the same way.
String deviceColumnPrefix(String deviceId) => switch (deviceId) {
  ThingsBoardApi.devicePzem => 'pzem',
  ThingsBoardApi.deviceBattery => 'bat',
  ThingsBoardApi.deviceSensor => 'env',
  ThingsBoardApi.deviceFish => 'fish',
  _ => 'dev',
};

/// A CSV of every telemetry key for the selected window, or null when the
/// window holds nothing.
///
/// **It fetches rather than dumping what is on screen.** The dashboard's
/// `_history` only holds the current tab's prefix, so exporting it would produce
/// a file whose columns depend on which tab the user happened to be on — a CSV
/// that silently changes shape is worse than no CSV at all.
///
/// **Columns are prefixed with the device.** The four devices publish keys this
/// app knows about and nothing currently collides, so a bare key name would work
/// today. It would not survive a second voltage sensor, and the collision would
/// overwrite one column with another rather than fail.
Future<String?> buildTelemetryCsvForWindow(
  ThingsBoardApi api, {
  required DateTime selectedDate,
  required DateTime? rangeStart,
  required DateTime? rangeEnd,
}) async {
  final window = historyTimeWindow(
    rangeStart: rangeStart ?? selectedDate,
    rangeEnd: rangeEnd,
    now: DateTime.now(),
  );
  final columns = <String, List<TelemetryPoint>>{};
  for (final entry in ThingsBoardApi.deviceKeysById.entries) {
    final prefix = deviceColumnPrefix(entry.key);
    final histories = await api.fetchHistoryForKeys(
      entry.key,
      entry.value,
      start: window.start,
      end: window.end,
      intervalMs: 30 * 60 * 1000,
      limit: 2000,
    );
    for (final series in histories.entries) {
      columns['$prefix.${series.key}'] = series.value;
    }
  }
  final csv = buildTelemetryCsv(history: columns);
  return csv.isEmpty ? null : csv;
}

/// Shares a CSV as a file attachment. Split from the build above so a test can
/// check the CSV without the platform share channel.
Future<void> shareTelemetryCsv(String csv, String stamp) async {
  await SharePlus.instance.share(
    ShareParams(
      title: 'EnerGrow telemetry',
      subject: 'EnerGrow telemetry — $stamp',
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(csv)),
          mimeType: 'text/csv',
          name: 'energrow.csv',
        ),
      ],
      fileNameOverrides: ['energrow.csv'],
    ),
  );
}
