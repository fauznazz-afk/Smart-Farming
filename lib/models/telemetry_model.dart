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

  /// Serialize to JSON for caching in SharedPreferences.
  Map<String, dynamic> toJson() => {
    'ts': timestamp.millisecondsSinceEpoch,
    'value': value.toString(),
  };
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
        final point = TelemetryPoint.fromJson(
          list.first as Map<String, dynamic>,
        );
        values[key] = point.value;
        if (latestTs == null || point.timestamp.isAfter(latestTs!)) {
          latestTs = point.timestamp;
        }
      }
    });

    return DeviceTelemetry(latestValues: values, lastUpdate: latestTs);
  }

  double get(String key, {double fallback = 0.0}) =>
      latestValues[key] ?? fallback;

  /// Serialize to JSON for caching in SharedPreferences.
  Map<String, dynamic> toJson() => {
    'latestValues': latestValues,
    'lastUpdate': lastUpdate?.toIso8601String(),
  };

  /// Deserialize from JSON (cached in SharedPreferences).
  factory DeviceTelemetry.fromCacheJson(Map<String, dynamic> json) {
    final values = <String, double>{};
    final raw = json['latestValues'];
    if (raw is Map) {
      raw.forEach((key, val) {
        values[key.toString()] = (val is num)
            ? val.toDouble()
            : double.tryParse(val.toString()) ?? 0.0;
      });
    }
    final lastUpdateStr = json['lastUpdate'] as String?;
    return DeviceTelemetry(
      latestValues: values,
      lastUpdate: lastUpdateStr != null
          ? DateTime.tryParse(lastUpdateStr)
          : null,
    );
  }

  /// Cek apakah data terakhir lebih tua dari [minutes] menit (buat badge "stale data")
  bool isStale({int minutes = 10}) {
    if (lastUpdate == null) return true;
    return DateTime.now().difference(lastUpdate!).inMinutes > minutes;
  }

  /// How long ago telemetry last arrived, in Indonesian.
  ///
  /// Every other string the user reads is Indonesian, and this one sat in the
  /// hero card next to the biggest number on the screen, so it was the most
  /// visible remaining English. Note there is no day bucket: three days old
  /// reads as "72 jam lalu", which is honest but worth knowing.
  String get ageLabel {
    if (lastUpdate == null) return 'Belum ada data';
    final age = DateTime.now().difference(lastUpdate!);
    if (age.inMinutes < 1) return 'Baru saja';
    if (age.inHours < 1) return 'Diperbarui ${age.inMinutes} menit lalu';
    if (age.inDays < 1) return 'Diperbarui ${age.inHours} jam lalu';
    return 'Diperbarui ${age.inDays} hari lalu';
  }
}
