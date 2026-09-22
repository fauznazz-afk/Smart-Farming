/// Model buat satu titik data telemetry (value + timestamp)
class TelemetryPoint {
  final DateTime timestamp;
  final double value;

  TelemetryPoint({required this.timestamp, required this.value});

  /// ThingsBoard balikin timeseries dalam format:
  /// { "power": [ { "ts": 1234567890000, "value": "12.5" }, ... ] }
  factory TelemetryPoint.fromJson(Map<String, dynamic> json) {
    return TelemetryPoint(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
      value: double.tryParse(json['value'].toString()) ?? 0.0,
    );
  }
}

/// Snapshot semua telemetry terkini dari satu device
class DeviceTelemetry {
  final Map<String, double> latestValues;
  final DateTime? lastUpdate;

  DeviceTelemetry({required this.latestValues, this.lastUpdate});

  /// Parse response dari endpoint /values/timeseries (latest only)
  /// Format: { "power": [{"ts":..., "value":"12.5"}], "soc": [{"ts":..., "value":"97"}] }
  factory DeviceTelemetry.fromJson(Map<String, dynamic> json) {
    final Map<String, double> values = {};
    DateTime? latestTs;

    json.forEach((key, list) {
      if (list is List && list.isNotEmpty) {
        final point = TelemetryPoint.fromJson(list.first as Map<String, dynamic>);
        values[key] = point.value;
        if (latestTs == null || point.timestamp.isAfter(latestTs!)) {
          latestTs = point.timestamp;
        }
      }
    });

    return DeviceTelemetry(latestValues: values, lastUpdate: latestTs);
  }

  double get(String key, {double fallback = 0.0}) => latestValues[key] ?? fallback;

  /// Cek apakah data terakhir lebih tua dari [minutes] menit (buat badge "stale data")
  bool isStale({int minutes = 10}) {
    if (lastUpdate == null) return true;
    return DateTime.now().difference(lastUpdate!).inMinutes > minutes;
  }

  String get ageLabel {
    if (lastUpdate == null) return 'No update received';
    final age = DateTime.now().difference(lastUpdate!);
    if (age.inMinutes < 1) return 'Updated just now';
    if (age.inHours < 1) return 'Updated ${age.inMinutes} min ago';
    return 'Updated ${age.inHours} hr ago';
  }
}
