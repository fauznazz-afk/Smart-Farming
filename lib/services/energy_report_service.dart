import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

const energySpreadsheetCsvUrl =
    'https://docs.google.com/spreadsheets/d/1xhqranU4CQrOrC8pqHDnbbPItQeEYnkPVMJGal2nx2w/export?format=csv&gid=1401376274';

class EnergyBucket {
  const EnergyBucket({
    required this.hour,
    required this.pvKwh,
    required this.acKwh,
    required this.sampleCount,
  });

  final DateTime hour;
  final double pvKwh;
  final double acKwh;
  final int sampleCount;
}

class EnergyReportData {
  const EnergyReportData({
    required this.buckets,
    required this.firstSample,
    required this.lastSample,
    required this.sampleCount,
    required this.skippedGaps,
  });

  final List<EnergyBucket> buckets;
  final DateTime firstSample;
  final DateTime lastSample;
  final int sampleCount;
  final int skippedGaps;

  double get pvKwh => buckets.fold(0, (sum, item) => sum + item.pvKwh);
  double get acKwh => buckets.fold(0, (sum, item) => sum + item.acKwh);

  factory EnergyReportData.fromMap(Map<String, dynamic> map) {
    final buckets = (map['buckets'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (item) => EnergyBucket(
            hour: DateTime.fromMillisecondsSinceEpoch(item['hour'] as int),
            pvKwh: (item['pv'] as num).toDouble(),
            acKwh: (item['ac'] as num).toDouble(),
            sampleCount: item['samples'] as int,
          ),
        )
        .toList(growable: false);
    return EnergyReportData(
      buckets: buckets,
      firstSample: DateTime.fromMillisecondsSinceEpoch(map['first'] as int),
      lastSample: DateTime.fromMillisecondsSinceEpoch(map['last'] as int),
      sampleCount: map['count'] as int,
      skippedGaps: map['gaps'] as int,
    );
  }
}

class EnergyReportService {
  static Future<EnergyReportData>? _cachedRequest;

  Future<EnergyReportData> load({bool refresh = false}) {
    if (refresh || _cachedRequest == null) {
      _cachedRequest = _load();
    }
    return _cachedRequest!;
  }

  Future<EnergyReportData> _load() async {
    final response = await http
        .get(Uri.parse(energySpreadsheetCsvUrl))
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw Exception('Spreadsheet gagal dimuat (${response.statusCode}).');
    }
    final csv = response.body;
    return EnergyReportData.fromMap(
      await Isolate.run(() => _parseEnergyCsv(csv)),
    );
  }
}

Map<String, dynamic> _parseEnergyCsv(String text) {
  final rows = _parseCsv(text);
  if (rows.length < 2) throw const FormatException('CSV tidak memiliki data.');

  final header = rows.first.map((value) => value.trim().toLowerCase()).toList();
  final dcIndex = header.indexWhere((value) => value.contains('power dc'));
  final acIndex = header.indexWhere((value) => value.contains('power ac'));
  if (dcIndex < 0 || acIndex < 0) {
    throw const FormatException(
      'Kolom Power DC (W) dan Power AC (W) tidak ditemukan.',
    );
  }

  final samples = <({DateTime time, double dc, double ac})>[];
  for (final row in rows.skip(1)) {
    if (row.length <= math.max(dcIndex, acIndex)) continue;
    final time = _parseSheetTimestamp(row.first.trim());
    final dc = double.tryParse(row[dcIndex].trim());
    final ac = double.tryParse(row[acIndex].trim());
    if (time == null || dc == null || ac == null) continue;
    samples.add((time: time, dc: dc, ac: ac));
  }
  if (samples.isEmpty) {
    throw const FormatException('Tidak ada baris daya valid.');
  }
  samples.sort((a, b) => a.time.compareTo(b.time));

  final buckets = <int, Map<String, dynamic>>{};
  var skippedGaps = 0;
  for (var i = 0; i < samples.length; i++) {
    final current = samples[i];
    final hour = DateTime(
      current.time.year,
      current.time.month,
      current.time.day,
      current.time.hour,
    );
    final bucket = buckets.putIfAbsent(
      hour.millisecondsSinceEpoch,
      () => {
        'hour': hour.millisecondsSinceEpoch,
        'pv': 0.0,
        'ac': 0.0,
        'samples': 0,
      },
    );
    bucket['samples'] = (bucket['samples'] as int) + 1;

    if (i == 0) continue;
    final previous = samples[i - 1];
    final gapMs = current.time.difference(previous.time).inMilliseconds;
    if (gapMs <= 0) continue;
    if (gapMs > const Duration(seconds: 60).inMilliseconds) {
      skippedGaps++;
      continue;
    }

    var cursorMs = previous.time.millisecondsSinceEpoch;
    final endMs = current.time.millisecondsSinceEpoch;
    while (cursorMs < endMs) {
      final cursorTime = DateTime.fromMillisecondsSinceEpoch(cursorMs);
      final nextHour = DateTime(
        cursorTime.year,
        cursorTime.month,
        cursorTime.day,
        cursorTime.hour + 1,
      ).millisecondsSinceEpoch;
      final segmentEnd = endMs < nextHour ? endMs : nextHour;
      final leftFraction =
          (cursorMs - previous.time.millisecondsSinceEpoch) / gapMs;
      final rightFraction =
          (segmentEnd - previous.time.millisecondsSinceEpoch) / gapMs;
      final segmentMs = segmentEnd - cursorMs;
      final hourStart = DateTime(
        cursorTime.year,
        cursorTime.month,
        cursorTime.day,
        cursorTime.hour,
      );
      final target = buckets.putIfAbsent(
        hourStart.millisecondsSinceEpoch,
        () => {
          'hour': hourStart.millisecondsSinceEpoch,
          'pv': 0.0,
          'ac': 0.0,
          'samples': 0,
        },
      );
      target['pv'] =
          (target['pv'] as double) +
          _trapezoidKwh(
            previous.dc,
            current.dc,
            leftFraction,
            rightFraction,
            segmentMs,
          );
      target['ac'] =
          (target['ac'] as double) +
          _trapezoidKwh(
            previous.ac,
            current.ac,
            leftFraction,
            rightFraction,
            segmentMs,
          );
      cursorMs = segmentEnd;
    }
  }

  final orderedBuckets = buckets.values.toList()
    ..sort((a, b) => (a['hour'] as int).compareTo(b['hour'] as int));
  return {
    'buckets': orderedBuckets,
    'first': samples.first.time.millisecondsSinceEpoch,
    'last': samples.last.time.millisecondsSinceEpoch,
    'count': samples.length,
    'gaps': skippedGaps,
  };
}

double _trapezoidKwh(
  double first,
  double second,
  double leftFraction,
  double rightFraction,
  int durationMs,
) {
  final left = math
      .max(0.0, first + (second - first) * leftFraction)
      .toDouble();
  final right = math
      .max(0.0, first + (second - first) * rightFraction)
      .toDouble();
  return (left + right) / 2 * durationMs / 3600000000;
}

DateTime? _parseSheetTimestamp(String value) {
  final match = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})$',
  ).firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match[3]!),
    int.parse(match[2]!),
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  for (var i = input.startsWith('\uFEFF') ? 1 : 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell = StringBuffer();
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(char);
    }
  }
  if (cell.length > 0 || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
  }
  return rows;
}
