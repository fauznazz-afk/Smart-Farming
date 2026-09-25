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

  const AlarmRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.message,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'severity': severity.name,
    'message': message,
    if (value != null) 'value': value,
  };

  factory AlarmRecord.fromJson(Map<String, dynamic> json) {
    return AlarmRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: AlarmType.values.byName(json['type'] as String),
      severity: AlarmSeverity.values.byName(json['severity'] as String),
      message: json['message'] as String,
      value: (json['value'] as num?)?.toDouble(),
    );
  }

  AlarmRecord copyWith({
    String? id,
    DateTime? timestamp,
    AlarmType? type,
    AlarmSeverity? severity,
    String? message,
    double? value,
  }) {
    return AlarmRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      value: value ?? this.value,
    );
  }
}

/// Service that persists alarm history to SharedPreferences.
class AlarmHistoryService {
  static const _storageKey = 'alarm_history';
  static const int _maxEntries = 100;

  AlarmHistoryService._();

  static final AlarmHistoryService _instance = AlarmHistoryService._();
  factory AlarmHistoryService() => _instance;

  /// Adds an alarm record to persistent storage.
  /// Trims the list to [_maxEntries] entries, removing the oldest.
  Future<void> addAlarm(AlarmRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const [];
    final alarms = raw
        .map(
          (jsonStr) =>
              AlarmRecord.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
        )
        .toList();
    alarms.add(record);
    if (alarms.length > _maxEntries) {
      alarms.removeRange(0, alarms.length - _maxEntries);
    }
    await prefs.setStringList(
      _storageKey,
      alarms.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  /// Returns all alarm records, newest first.
  Future<List<AlarmRecord>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const [];
    final alarms = raw
        .map(
          (jsonStr) =>
              AlarmRecord.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>),
        )
        .toList();
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
}
