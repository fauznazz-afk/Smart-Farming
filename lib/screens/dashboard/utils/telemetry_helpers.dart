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
///
/// **Singular at 1, and that is the second age formatter in the app to need it.**
/// `TelemetrySensor.ageLabel` got the same treatment; this one was left behind,
/// so the solar cache said "1 minutes ago" while the meter said "1 minute ago" —
/// two grammars for the same number, sometimes on the same screen. They are
/// still two functions, in two layers, which is a larger problem than the typo;
/// this is the cheap half of it.
String describeCacheAge(DateTime? cacheTime) {
  if (cacheTime == null) return 'a while ago';
  final age = DateTime.now().difference(cacheTime);
  if (age.inMinutes < 1) return 'just now';
  final (count, unit) = age.inHours < 1
      ? (age.inMinutes, 'minute')
      : age.inDays < 1
      ? (age.inHours, 'hour')
      : (age.inDays, 'day');
  return '$count $unit${count == 1 ? '' : 's'} ago';
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

/// The highest PV power in [history] for the current window, or null if there is
/// nothing to report.
///
/// **`power_dc` alone, not every key under the `pv` prefix.**
/// `chartKeysForPrefix('pv')` is `voltage_dc`, `current_dc`, `power_dc` — three
/// series in three different units, and a max across them is only right for as
/// long as watts happen to outnumber both volts and amps. That is an accident of
/// this array's ratings, not a rule, and the result is printed beside an 88 dp
/// figure whose unit is `W`.
///
/// **The live reading is part of the window.** The hero beside this figure is
/// the live reading, and history is fetched on its own slower cadence — so the
/// panel printed `PEAK 286` directly under a hero reading `291`. A peak below
/// the present value is a contradiction on the one row whose whole claim is
/// "the best this period has managed".
///
/// Null, NaN and negative samples are skipped rather than treated as zero: a
/// sensor reporting -1 V during a reboot must not lower the peak, and a missing
/// reading must not make a good day look like it never produced anything.
double? pvPeakWatts(List<TelemetryPoint> history, {double? livePower}) {
  var peak = double.negativeInfinity;
  var seen = false;
  for (final point in history) {
    final value = point.value;
    if (value.isNaN || value < 0) continue;
    seen = true;
    if (value > peak) peak = value;
  }
  if (livePower != null && !livePower.isNaN && livePower > 0) {
    seen = true;
    if (livePower > peak) peak = livePower;
  }
  return seen ? peak : null;
}
