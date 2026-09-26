import '../models/alarm_record.dart';
import 'alarm_rules.dart';

/// Maps an alert ID string to an [AlarmType].
///
/// Alert IDs are carried inside persisted alarm records, so this stays the
/// single mapping used when an id is classified outside the rule engine.
AlarmType alarmTypeFromId(String id) {
  if (id == 'low_soc') return AlarmType.lowSoc;
  if (id.startsWith('stale_')) return AlarmType.staleTelemetry;
  // Named rather than left to the fallback, so a typo in a rule id shows up here
  // instead of being silently reported as an offline device.
  if (id.startsWith('offline_')) return AlarmType.deviceOffline;
  if (id.startsWith('environment_ambient_temp')) {
    return AlarmType.environmentTemp;
  }
  if (id.startsWith('environment_humidity')) {
    return AlarmType.environmentHumidity;
  }
  if (id.startsWith('environment_tds')) return AlarmType.environmentTds;
  return AlarmType.deviceOffline;
}

/// Determines severity from the alert ID.
AlarmSeverity alarmSeverityFromId(String id) {
  // Critical means "act on this now": a low battery, or a device that has
  // stopped reporting entirely. Everything else is a warning.
  if (id == 'low_soc' || id.startsWith('offline_')) {
    return AlarmSeverity.critical;
  }
  return AlarmSeverity.warning;
}

/// Returns names of devices whose telemetry is stale.
///
/// Takes the same readings the rule engine uses, so the banner and the alarms
/// cannot disagree about which devices stopped reporting. Three of the six
/// parameters this used to take were read only as a "was this device read at
/// all" proxy, and the three device names were spelled out again here rather
/// than taken from [AlarmDevice].
List<String> staleDeviceNames({
  required List<AlarmReading> readings,
  required int staleMinutes,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return [
    for (final reading in readings)
      if (reading.lastUpdate != null && reading.isStale(staleMinutes, at))
        reading.device.label,
  ];
}
