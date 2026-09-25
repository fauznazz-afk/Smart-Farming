import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_history_service.dart';
import 'thingsboard_api.dart';

const _channelId = 'energrow_alarms';
const _backgroundAlarmId = 71025;

final _notifications = FlutterLocalNotificationsPlugin();

class AlarmNotificationService {
  AlarmNotificationService._();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@drawable/ic_energrow');
    await _notifications.initialize(
      const InitializationSettings(android: android),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> initializeBackgroundMonitoring() async {
    await AndroidAlarmManager.initialize();
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 15),
      _backgroundAlarmId,
      backgroundAlarmCallback,
      exact: false,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> notifyAlarm({
    required String id,
    required String title,
    required String message,
    required bool critical,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('alarm_notification_$id');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null &&
        now - last < const Duration(minutes: 5).inMilliseconds) {
      return;
    }
    await prefs.setInt('alarm_notification_$id', now);
    await _notifications.show(
      id.hashCode,
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'EnerGrow alarms',
          channelDescription: 'Alerts from PLTS monitoring',
          importance: critical ? Importance.max : Importance.high,
          priority: critical ? Priority.max : Priority.high,
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          icon: '@drawable/ic_energrow',
        ),
      ),
    );
  }

  static Future<void> checkInBackground() async {
    final api = ThingsBoardApi();
    if (!await api.loadSavedToken()) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('energy_alerts_enabled') ?? true)) return;

    try {
      final battery = await api.fetchBatteryData();
      final soc = battery.latestValues['soc'];
      final threshold = prefs.getInt('low_soc_threshold') ?? 20;
      if (soc != null && soc < threshold) {
        final message = 'SOC baterai rendah: ${soc.toStringAsFixed(0)}%';
        await _recordAndNotify(
          id: 'low_soc',
          type: AlarmType.lowSoc,
          severity: AlarmSeverity.critical,
          message: message,
          value: soc,
        );
      }

      final staleMinutes = prefs.getInt('stale_telemetry_minutes') ?? 10;
      final devices = [
        ('battery', 'Baterai', battery),
        ('pzem', 'PZEM', await api.fetchPzemData()),
        ('sensor', 'Sensor lingkungan', await api.fetchSensorData()),
      ];
      for (final (id, name, telemetry) in devices) {
        if (!telemetry.isStale(minutes: staleMinutes)) continue;
        await _recordAndNotify(
          id: 'stale_$id',
          type: AlarmType.staleTelemetry,
          severity: AlarmSeverity.warning,
          message: 'Data $name belum diperbarui',
        );
      }
    } catch (_) {
      // Background jobs must fail quietly; the next scheduled run retries.
    }
  }

  static Future<void> _recordAndNotify({
    required String id,
    required AlarmType type,
    required AlarmSeverity severity,
    required String message,
    double? value,
  }) async {
    final record = AlarmRecord(
      id: '${id}_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      severity: severity,
      message: message,
      value: value,
    );
    await AlarmHistoryService().addAlarm(record);
    await notifyAlarm(
      id: id,
      title:
          'EnerGrow: ${severity == AlarmSeverity.critical ? 'Critical' : 'Warning'} alarm',
      message: message,
      critical: severity == AlarmSeverity.critical,
    );
  }
}

@pragma('vm:entry-point')
Future<void> backgroundAlarmCallback() async {
  await AlarmNotificationService.initialize();
  await AlarmNotificationService.checkInBackground();
}
