import 'dart:math' as math;

import '../models/telemetry_model.dart';
import 'thingsboard_api.dart';

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
  });

  final List<EnergyBucket> buckets;
  final DateTime firstSample;
  final DateTime lastSample;
  final int sampleCount;

  double get pvKwh => buckets.fold(0, (sum, item) => sum + item.pvKwh);
  double get acKwh => buckets.fold(0, (sum, item) => sum + item.acKwh);
}

/// Loads hourly power aggregates from ThingsBoard's stored device telemetry.
class EnergyReportService {
  EnergyReportService(this._api);

  final ThingsBoardApi _api;

  Future<EnergyReportData> load({required DateTime referenceDate}) async {
    final currentMonth = DateTime(referenceDate.year, referenceDate.month);
    final start = DateTime(currentMonth.year, currentMonth.month - 1);
    final now = DateTime.now();
    final requestedEnd = DateTime(currentMonth.year, currentMonth.month + 1);
    final end = requestedEnd.isAfter(now) ? now : requestedEnd;
    if (!end.isAfter(start)) {
      throw Exception('Rentang laporan tidak valid.');
    }

    final histories = <String, List<TelemetryPoint>>{
      'power_dc': <TelemetryPoint>[],
      'power_ac': <TelemetryPoint>[],
    };
    // This ThingsBoard instance caps aggregate queries below a full 31-day
    // window. Fetch 28-day chunks (672 hourly intervals) to stay under it.
    const maxQueryDuration = Duration(days: 28);
    var cursor = start;
    while (cursor.isBefore(end)) {
      final chunkEnd = cursor.add(maxQueryDuration).isBefore(end)
          ? cursor.add(maxQueryDuration)
          : end;
      final result = await _api.fetchHistoryForKeys(
        ThingsBoardApi.devicePzem,
        const ['power_dc', 'power_ac'],
        start: cursor,
        end: chunkEnd,
        intervalMs: const Duration(hours: 1).inMilliseconds,
        limit: 720,
      );
      for (final key in histories.keys) {
        histories[key]!.addAll(result[key] ?? const <TelemetryPoint>[]);
      }
      cursor = chunkEnd;
    }
    final dc = histories['power_dc'] ?? const <TelemetryPoint>[];
    final ac = histories['power_ac'] ?? const <TelemetryPoint>[];
    if (dc.isEmpty && ac.isEmpty) {
      throw Exception('ThingsBoard belum memiliki histori daya pada periode ini.');
    }

    final byHour = <DateTime, _MutableEnergyBucket>{};
    DateTime? firstSample;
    DateTime? lastSample;
    for (final point in dc) {
      final hour = _hourOf(point.timestamp);
      final bucket = byHour.putIfAbsent(hour, () => _MutableEnergyBucket());
      bucket.pvKwh = math.max(0, point.value) / 1000;
      bucket.sampleCount++;
      firstSample = _earlier(firstSample, point.timestamp);
      lastSample = _later(lastSample, point.timestamp);
    }
    for (final point in ac) {
      final hour = _hourOf(point.timestamp);
      final bucket = byHour.putIfAbsent(hour, () => _MutableEnergyBucket());
      bucket.acKwh = math.max(0, point.value) / 1000;
      bucket.sampleCount++;
      firstSample = _earlier(firstSample, point.timestamp);
      lastSample = _later(lastSample, point.timestamp);
    }

    final buckets = byHour.entries
        .map(
          (entry) => EnergyBucket(
            hour: entry.key,
            pvKwh: entry.value.pvKwh,
            acKwh: entry.value.acKwh,
            sampleCount: entry.value.sampleCount,
          ),
        )
        .toList()
      ..sort((a, b) => a.hour.compareTo(b.hour));

    return EnergyReportData(
      buckets: buckets,
      firstSample: firstSample!,
      lastSample: lastSample!,
      sampleCount: buckets.fold(0, (sum, item) => sum + item.sampleCount),
    );
  }
}

DateTime _hourOf(DateTime value) =>
    DateTime(value.year, value.month, value.day, value.hour);

DateTime _earlier(DateTime? current, DateTime candidate) =>
    current == null || candidate.isBefore(current) ? candidate : current;

DateTime _later(DateTime? current, DateTime candidate) =>
    current == null || candidate.isAfter(current) ? candidate : current;

class _MutableEnergyBucket {
  double pvKwh = 0;
  double acKwh = 0;
  int sampleCount = 0;
}
