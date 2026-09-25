import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channelId = 'energrow_alarms';

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
}
