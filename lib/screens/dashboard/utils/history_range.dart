import '../../../services/thingsboard_api.dart';

/// The telemetry keys requested for a dashboard page prefix.
class HistoryKeys {
  const HistoryKeys(this.voltage, this.current, this.power);

  final String voltage;
  final String current;
  final String power;
}

/// A resolved time-series request window plus its sampling interval.
typedef HistoryWindow = ({
  DateTime start,
  DateTime end,
  int intervalMs,
  HistoryKeys keys,
  String deviceId,
});

/// Maps a page prefix to the telemetry keys it charts.
HistoryKeys historyKeysForPrefix(String prefix) => switch (prefix) {
  'pv' => const HistoryKeys('voltage_dc', 'current_dc', 'power_dc'),
  'ac' => const HistoryKeys('voltage_ac', 'current_ac', 'power_ac'),
  _ => const HistoryKeys('voltage', 'current', 'power'),
};

/// Maps a page prefix to its ThingsBoard device id.
String historyDeviceForPrefix(String prefix) => prefix == 'battery'
    ? ThingsBoardApi.deviceBattery
    : ThingsBoardApi.devicePzem;

/// Builds a stable cache key for a selected day or custom range.
String historySelectionKey({required DateTime rangeStart, DateTime? rangeEnd}) =>
    '${rangeStart.millisecondsSinceEpoch}:${rangeEnd?.millisecondsSinceEpoch ?? ''}';

/// Normalizes any timestamp to midnight of that day.
DateTime startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Resolves the start/end timestamps for a history request.
///
/// A custom range wins, then "today" (rolling 24h), then a whole past day.
({DateTime start, DateTime end}) historyTimeWindow({
  required DateTime rangeStart,
  required DateTime? rangeEnd,
  required DateTime now,
}) {
  if (rangeEnd != null) {
    return (
      start: rangeStart,
      end: DateTime(
        rangeEnd.year,
        rangeEnd.month,
        rangeEnd.day,
        23,
        59,
        59,
        999,
      ),
    );
  }
  if (rangeStart == startOfDay(now)) {
    return (start: now.subtract(const Duration(hours: 24)), end: now);
  }
  return (
    start: rangeStart,
    end: DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
      23,
      59,
      59,
    ),
  );
}

/// Picks a sampling interval that keeps the point count reasonable per span.
int historyIntervalFor(Duration duration) {
  if (duration <= const Duration(days: 1)) return 5 * 60 * 1000;
  if (duration <= const Duration(days: 7)) return 30 * 60 * 1000;
  if (duration <= const Duration(days: 30)) return 2 * 60 * 60 * 1000;
  return 6 * 60 * 60 * 1000;
}

/// Resolves the full request description for a page prefix.
HistoryWindow historyWindowFor({
  required String prefix,
  required DateTime rangeStart,
  required DateTime? rangeEnd,
  required DateTime now,
}) {
  final window = historyTimeWindow(
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    now: now,
  );
  return (
    start: window.start,
    end: window.end,
    intervalMs: historyIntervalFor(window.end.difference(window.start)),
    keys: historyKeysForPrefix(prefix),
    deviceId: historyDeviceForPrefix(prefix),
  );
}
