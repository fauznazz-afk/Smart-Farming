/// The shape of one recorded alarm.
///
/// Lives in `models/` rather than in the service that stores it, so the rule
/// engine in `utils/` can depend on [AlarmType] and [AlarmSeverity] without
/// dragging in `SharedPreferences` or a method channel. Keeping that edge out of
/// the rule engine is what lets it be exercised by a plain Dart tool as well as
/// by `flutter test`.
library;

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
