import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Type of alarm that can be recorded.
enum AlarmType {
  lowSoc,
  staleTelemetry,
  environmentTemp,
  environmentHumidity,
  environmentTds,
  deviceOffline;

  String get label => switch (this) {
    lowSoc => 'Low SOC',
    staleTelemetry => 'Stale Telemetry',
    environmentTemp => 'Environment Temp',
    environmentHumidity => 'Environment Humidity',
    environmentTds => 'Environment TDS',
    deviceOffline => 'Device Offline',
  };
}

/// Severity level of an alarm.
enum AlarmSeverity { warning, critical }

/// A single alarm record persisted in SharedPreferences.
class AlarmRecord {
  final String id;
  final DateTime timestamp;
  final AlarmType type;
  final AlarmSeverity severity;
  final String message;
  final double? value;
  final bool acknowledged;
  final bool resolved;

  const AlarmRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.message,
    this.value,
    this.acknowledged = false,
    this.resolved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'severity': severity.name,
    'message': message,
    if (value != null) 'value': value,
    'acknowledged': acknowledged,
    'resolved': resolved,
  };

  factory AlarmRecord.fromJson(Map<String, dynamic> json) {
    AlarmType parseType() {
      final name = json['type'];
      return AlarmType.values
              .where((value) => value.name == name)
              .firstOrNull ??
          AlarmType.deviceOffline;
    }

    AlarmSeverity parseSeverity() {
      final name = json['severity'];
      return AlarmSeverity.values
              .where((value) => value.name == name)
              .firstOrNull ??
          AlarmSeverity.warning;
    }

    return AlarmRecord(
      id: json['id']?.toString() ?? '${DateTime.now().microsecondsSinceEpoch}',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      type: parseType(),
      severity: parseSeverity(),
      message: json['message']?.toString() ?? 'Unknown alarm',
      value: (json['value'] as num?)?.toDouble(),
      acknowledged: json['acknowledged'] == true,
      resolved: json['resolved'] == true,
    );
  }

  AlarmRecord copyWith({
    String? id,
    DateTime? timestamp,
    AlarmType? type,
    AlarmSeverity? severity,
    String? message,
    double? value,
    bool? acknowledged,
    bool? resolved,
  }) {
    return AlarmRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      value: value ?? this.value,
      acknowledged: acknowledged ?? this.acknowledged,
      resolved: resolved ?? this.resolved,
    );
  }
}

/// Service that persists alarm history to SharedPreferences.
class AlarmHistoryService {
  static const _storageKey = 'alarm_history';
  static const int _maxEntries = 100;
  static const Duration defaultCooldown = Duration(minutes: 5);

  AlarmHistoryService._();

  static final AlarmHistoryService _instance = AlarmHistoryService._();
  factory AlarmHistoryService() => _instance;

  /// Adds an alarm record to persistent storage.
  /// Trims the list to [_maxEntries] entries, removing the oldest.
  Future<void> addAlarm(
    AlarmRecord record, {
    Duration cooldown = defaultCooldown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = _decode(prefs.getStringList(_storageKey));
    final duplicate = alarms.any(
      (alarm) =>
          alarm.type == record.type &&
          alarm.message == record.message &&
          record.timestamp.difference(alarm.timestamp) >= Duration.zero &&
          record.timestamp.difference(alarm.timestamp) <= cooldown,
    );
    if (duplicate) return;
    alarms.add(record);
    await _save(prefs, alarms);
  }

  /// Returns all alarm records, newest first.
  Future<List<AlarmRecord>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = _decode(prefs.getStringList(_storageKey));
    alarms.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alarms;
  }

  /// Returns alarm records since [since], newest first.
  Future<List<AlarmRecord>> getAlarmsSince(DateTime since) async {
    final all = await getAlarms();
    return all.where((a) => a.timestamp.isAfter(since)).toList();
  }

  /// Removes all alarm records from storage.
  Future<void> clearAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> updateAlarm(AlarmRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = _decode(prefs.getStringList(_storageKey));
    final index = alarms.indexWhere((alarm) => alarm.id == record.id);
    if (index == -1) return;
    alarms[index] = record;
    await _save(prefs, alarms);
  }

  Future<void> acknowledgeAlarm(String id) async {
    final alarm = await _find(id);
    if (alarm != null) {
      await updateAlarm(alarm.copyWith(acknowledged: true));
    }
  }

  Future<void> resolveAlarm(String id) async {
    final alarm = await _find(id);
    if (alarm != null) {
      await updateAlarm(alarm.copyWith(acknowledged: true, resolved: true));
    }
  }

  Future<AlarmRecord?> _find(String id) async {
    final alarms = await getAlarms();
    for (final alarm in alarms) {
      if (alarm.id == id) return alarm;
    }
    return null;
  }

  List<AlarmRecord> _decode(List<String>? raw) {
    return (raw ?? const [])
        .map((jsonStr) {
          try {
            return AlarmRecord.fromJson(
              jsonDecode(jsonStr) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AlarmRecord>()
        .toList();
  }

  Future<void> _save(SharedPreferences prefs, List<AlarmRecord> alarms) async {
    alarms.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (alarms.length > _maxEntries) {
      alarms.removeRange(0, alarms.length - _maxEntries);
    }
    await prefs.setStringList(
      _storageKey,
      alarms.map((alarm) => jsonEncode(alarm.toJson())).toList(),
    );
  }
}
