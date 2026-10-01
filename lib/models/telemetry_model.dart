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
      // Falls back to 0.0 for a payload it cannot read. **That is safe here and
      // only here**, because a history point with an unreadable value is a point
      // on a line rather than a claim about what a device is doing right now.
      // [DeviceTelemetry.fromJson] must not do this, for the reason its own
      // comment gives. Do not copy this fallback up a layer.
      value: double.tryParse(json['value'].toString()) ?? 0.0,
    );
  }

  /// The value, or `null` when the payload carries no readable number.
  ///
  /// Kept separate from [fromJson] deliberately. A `TelemetryPoint` is a dot on a
  /// line, so it needs a number and a fallback is harmless. The *snapshot* is a
  /// claim about the present state of a device, and there a fabricated zero is
  /// not a placeholder -- it is an assertion.
  ///
  /// `json['value']?.toString() ?? ''` rather than `.toString()`, because a
  /// missing key used to become the string `"null"`, which `double.tryParse`
  /// rejects, and the `?? 0.0` then turned that rejection into a zero. `''`
  /// fails to parse too -- but it fails on purpose, and the caller can see it.
  static double? tryValue(Map<String, dynamic> json) =>
      double.tryParse(json['value']?.toString() ?? '');

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
  ///
  /// **A key whose payload is not a readable number is left out of the map
  /// entirely, and that is the whole point of this factory.**
  ///
  /// It used to be `values[key] = point.value`, with `TelemetryPoint.fromJson`
  /// falling back to `0.0`. So a key that was *present* in a 200 response but
  /// carried `null` arrived as a confident `0.0`, indistinguishable from a real
  /// zero reading -- and `evaluateAlarmRules` reads `if (value == null) continue;`,
  /// so a present-but-null key never took that branch. It was compared instead.
  /// The consequence crossed into the alarm engine: a null `soc` produced
  /// `Battery charge low: 0%` at **critical** severity, persisted and notified.
  /// A null `tds_ppm` produced `TDS too low: 0.0 ppm`.
  ///
  /// Leaving the key out is what makes the existing rule work. `alarm_rules.dart`
  /// already states that a device which produced no reading is not stale and
  /// raises no value alarm; this is what makes that rule reachable for a key
  /// that is present but empty.
  ///
  /// `thingsboard_api.dart` documents the same hazard for the boolean
  /// `turbidity_keruh` key and avoids it by never requesting that key. That is a
  /// narrower fix than it looks: it protects one key while leaving the fallback
  /// in place for every numeric one, which is the case that reaches the alarms.
  ///
  /// **`lastUpdate` still advances for a skipped key, and deliberately.** The
  /// device answered; it just did not report a number. So the badge reads as
  /// fresh, which is true, while no value alarm fires for the metric, which is
  /// also true. Advancing it only for parseable keys would instead report a
  /// talking device as stale.
  factory DeviceTelemetry.fromJson(Map<String, dynamic> json) {
    final Map<String, double> values = {};
    DateTime? latestTs;

    json.forEach((key, list) {
      if (list is List && list.isNotEmpty) {
        final raw = list.first as Map<String, dynamic>;
        final point = TelemetryPoint.fromJson(raw);
        if (latestTs == null || point.timestamp.isAfter(latestTs!)) {
          latestTs = point.timestamp;
        }
        final parsed = TelemetryPoint.tryValue(raw);
        if (parsed != null) {
          values[key] = parsed;
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
  ///
  /// **Unparseable keys are skipped here too, for the same reason as in
  /// [fromJson].** The cache is written from a snapshot that already skipped
  /// them, so in practice this cannot add one -- but the old code turned an
  /// unreadable entry into `0.0` on the way back *in*, which means a cache written
  /// by an older build, or a partially corrupt one, could reintroduce exactly the
  /// fabricated zero that [fromJson] now refuses to create.
  factory DeviceTelemetry.fromCacheJson(Map<String, dynamic> json) {
    final values = <String, double>{};
    final raw = json['latestValues'];
    if (raw is Map) {
      raw.forEach((key, val) {
        final parsed = val is num
            ? val.toDouble()
            : double.tryParse(val?.toString() ?? '');
        if (parsed != null) {
          values[key.toString()] = parsed;
        }
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

  /// How long ago telemetry last arrived.
  ///
  /// Note there is no day bucket: three days old reads as "72 hours ago",
  /// which is honest but worth knowing.
  String get ageLabel {
    if (lastUpdate == null) return 'No data yet';
    final age = DateTime.now().difference(lastUpdate!);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inHours < 1) return 'Updated ${age.inMinutes} minutes ago';
    if (age.inDays < 1) return 'Updated ${age.inHours} hours ago';
    return 'Updated ${age.inDays} days ago';
  }
}
