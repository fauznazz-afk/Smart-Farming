import '../../../services/alarm_history_service.dart';

/// Maps an alert ID string to an [AlarmType].
AlarmType alarmTypeFromId(String id) {
  if (id == 'low_soc') return AlarmType.lowSoc;
  if (id.startsWith('stale_')) return AlarmType.staleTelemetry;
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
  // Low SOC and device offline are critical; others are warnings.
  if (id == 'low_soc') return AlarmSeverity.critical;
  if (id.startsWith('stale_')) return AlarmSeverity.warning;
  return AlarmSeverity.warning;
}

/// Extracts the triggering numeric value from the alert ID.
double? alarmValueFromId(String id, {
  required Map<String, double>? batteryValues,
  required Map<String, double>? sensorValues,
}) {
  if (id == 'low_soc') return batteryValues?['soc'];
  if (id.startsWith('environment_ambient_temp')) {
    return sensorValues?['temp_dht'];
  }
  if (id.startsWith('environment_humidity')) {
    return sensorValues?['humidity_dht'];
  }
  if (id.startsWith('environment_tds')) {
    return sensorValues?['tds_ppm'];
  }
  return null;
}

/// Returns names of devices with stale telemetry.
List<String> staleDeviceNames({
  required Map<String, double>? batteryValues,
  required DateTime? batteryLastUpdate,
  required Map<String, double>? pzemValues,
  required DateTime? pzemLastUpdate,
  required Map<String, double>? sensorValues,
  required DateTime? sensorLastUpdate,
  required int staleMinutes,
}) {
  final devices = <(String, Map<String, double>?, DateTime?)>[
    ('Baterai', batteryValues, batteryLastUpdate),
    ('PZEM', pzemValues, pzemLastUpdate),
    ('Sensor lingkungan', sensorValues, sensorLastUpdate),
  ];
  return devices
      .where(
        (entry) =>
            entry.$2 != null &&
            entry.$3 != null &&
            DateTime.now().difference(entry.$3!).inMinutes > staleMinutes,
      )
      .map((entry) => entry.$1)
      .toList();
}