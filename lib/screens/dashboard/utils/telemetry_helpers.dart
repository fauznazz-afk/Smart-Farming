import '../../../models/telemetry_model.dart';
import '../../../services/thingsboard_api.dart';

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

/// Describes how long ago [cacheTime] happened.
String describeCacheAge(DateTime? cacheTime) {
  if (cacheTime == null) return 'a while ago';
  final age = DateTime.now().difference(cacheTime);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes} minutes ago';
  if (age.inDays < 1) return '${age.inHours} hours ago';
  return '${age.inDays} days ago';
}

/// Cached telemetry values partitioned per device slot.
typedef CachedTelemetrySplit = ({
  Map<String, double> battery,
  Map<String, double> pzem,
  Map<String, double> sensor,
  Map<String, double> fish,
});

/// Splits a flat cached telemetry map into the device buckets.
CachedTelemetrySplit splitCachedTelemetry(Map<String, double> values) {
  final battery = <String, double>{};
  final pzem = <String, double>{};
  final sensor = <String, double>{};
  final fish = <String, double>{};
  values.forEach((key, value) {
    // The key lists live on ThingsBoardApi and nowhere else. They used to
    // be written out here a second time, which is precisely the duplication the
    // comment on those constants exists to prevent: adding a key to one side
    // would silently drop it from the offline cache with no error anywhere.
    //
    // A key in none of the lists is dropped silently, by design. That is exactly
    // what happened to the fish device's keys when only ThingsBoardApi knew about
    // them: the REST poll looked healthy, the card showed live numbers, and the
    // offline fallback came up empty for that page alone.
    if (ThingsBoardApi.batteryKeys.contains(key)) {
      battery[key] = value;
    } else if (ThingsBoardApi.pzemKeys.contains(key)) {
      pzem[key] = value;
    } else if (ThingsBoardApi.sensorKeys.contains(key)) {
      sensor[key] = value;
    } else if (ThingsBoardApi.fishKeys.contains(key)) {
      fish[key] = value;
    }
  });
  return (battery: battery, pzem: pzem, sensor: sensor, fish: fish);
}
