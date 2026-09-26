import '../../../models/telemetry_model.dart';

/// Formats a [DateTime] as a 24-hour `HH:MM` clock string.
String formatClock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

/// Order-sensitive list comparison, used to avoid redundant rebuilds.
bool sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

/// Returns true when [second] carries no value that differs from [first].
bool sameTelemetry(DeviceTelemetry? first, DeviceTelemetry second) {
  if (first == null) return false;
  if (first.latestValues.length != second.latestValues.length) return false;
  for (final entry in second.latestValues.entries) {
    if (first.latestValues[entry.key] != entry.value) return false;
  }
  return true;
}

/// Describes how long ago [cacheTime] happened, in Indonesian.
String describeCacheAge(DateTime? cacheTime) {
  if (cacheTime == null) return 'beberapa waktu lalu';
  final age = DateTime.now().difference(cacheTime);
  if (age.inMinutes < 1) return 'baru saja';
  if (age.inHours < 1) return '${age.inMinutes} menit lalu';
  if (age.inDays < 1) return '${age.inHours} jam lalu';
  return '${age.inDays} hari lalu';
}

/// Telemetry keys that belong to the battery device.
const Set<String> batteryTelemetryKeys = {
  'current',
  'power',
  'soc',
  'voltage',
  'cycles',
  'remain_capacity_ah',
  'full_capacity_ah',
};

/// Telemetry keys that belong to the PZEM device.
const Set<String> pzemTelemetryKeys = {
  'voltage_ac',
  'voltage_dc',
  'current_ac',
  'current_dc',
  'power_ac',
  'power_dc',
  'energy_ac',
  'energy_dc',
  'frequency_ac',
  'pf_ac',
};

/// Telemetry keys that belong to the environment sensor device.
const Set<String> sensorTelemetryKeys = {
  'humidity_dht',
  'lux',
  'tds_ppm',
  'temp_dht',
  'temp_ds18b20',
};

/// Cached telemetry values partitioned per device slot.
typedef CachedTelemetrySplit = ({
  Map<String, double> battery,
  Map<String, double> pzem,
  Map<String, double> sensor,
});

/// Splits a flat cached telemetry map into the three device buckets.
CachedTelemetrySplit splitCachedTelemetry(Map<String, double> values) {
  final battery = <String, double>{};
  final pzem = <String, double>{};
  final sensor = <String, double>{};
  values.forEach((key, value) {
    if (batteryTelemetryKeys.contains(key)) {
      battery[key] = value;
    } else if (pzemTelemetryKeys.contains(key)) {
      pzem[key] = value;
    } else if (sensorTelemetryKeys.contains(key)) {
      sensor[key] = value;
    }
  });
  return (battery: battery, pzem: pzem, sensor: sensor);
}
