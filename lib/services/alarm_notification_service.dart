import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/alarm_rules.dart';
import 'alarm_bridge.dart';
import 'alarm_settings.dart';
import 'thingsboard_api.dart';

/// Notification channels.
///
/// The ids are shared with the native alarm module, which creates them at
/// `AlarmNotifier`. Reusing them means a background alarm and a dashboard alarm
/// land in the same place and replace one another by id, instead of stacking a
/// separate notification for every condition.
const _channelWarning = 'energrow_alarms';
const _channelCritical = 'energrow_critical_alarms';

final _notifications = FlutterLocalNotificationsPlugin();

/// Owns everything to do with raising an alarm, in the foreground or not.
///
/// The background half of the job is done by native Kotlin
/// (`tech.mbkm.energrow.alarm`) rather than by a Dart isolate, because an
/// `AlarmManager` callback delivered through `android_alarm_manager_plus` has to
/// spin up a Flutter engine, which costs tens of megabytes of resident memory
/// and a second or more per tick. The native module does the same HTTP requests
/// with `HttpURLConnection` and stays around 5 MB.
///
/// This class therefore does not poll anything itself. It hands the native side
/// a list of rules and a token, and stays out of the way.
class AlarmNotificationService {
  AlarmNotificationService._();

  static bool _initialized = false;

  /// Prepares notifications for alarms the dashboard itself detects.
  ///
  /// Safe to call repeatedly and safe to call on platforms without the plugin.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    const android = AndroidInitializationSettings('@drawable/ic_energrow');
    try {
      await _notifications.initialize(
        const InitializationSettings(android: android),
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } on Exception catch (error) {
      // A missing icon or a denied permission must not stop the app from
      // starting. The previous implementation swallowed this too, and the result
      // was a release build where alarms silently never appeared and nothing
      // said why.
      debugPrint('Alarm notification initialization failed: $error');
    }
    // The native side owns the channels, but the dashboard can raise a
    // notification before any background check has run.
    await AlarmBridge.instance.ensureChannels();
  }

  /// Pushes the current rules and credentials to the native alarm module.
  ///
  /// Returns whether the background check is now armed. Call this after login,
  /// after the settings screen saves, and on launch, because the rules are a
  /// function of the thresholds and the token is a function of the session.
  static Future<bool> sync({ThingsBoardApi? api}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final thresholds = readAlarmThresholds(preferences);
      final rules = buildAlarmRules(thresholds);
      final armed = rules.isNotEmpty;

      // Logged because a background check that arms the wrong rules without
      // saying so cannot be diagnosed from a notification that did or did not
      // appear.
      debugPrint(
        'Alarm sync: energy=${thresholds.energyAlerts} '
        'environment=${thresholds.environmentAlerts} '
        'lowSoc=${thresholds.lowSoc} stale=${thresholds.staleMinutes} '
        'rules=${rules.map((rule) => rule.id).join(',')}',
      );

      String? accessToken;
      String? refreshToken;
      if (armed) {
        final client = api ?? ThingsBoardApi();
        final loaded = await client.loadSavedToken();
        accessToken = client.accessToken;
        refreshToken = client.refreshToken;
        debugPrint(
          'Alarm sync: session loaded=$loaded '
          'hasAccessToken=${accessToken != null && accessToken.isNotEmpty} '
          'hasRefreshToken=${refreshToken != null && refreshToken.isNotEmpty}',
        );
      }

      await AlarmBridge.instance.configure(
        rules: rules,
        devices: _devicesFor(rules),
        baseUrl: ThingsBoardApi.baseUrl,
        accessToken: accessToken,
        refreshToken: refreshToken,
        arm: armed,
      );
      return armed;
    } on Exception catch (error) {
      debugPrint('Could not sync the background alarm check: $error');
      return false;
    }
  }

  /// Stops the background check and forgets its configuration.
  ///
  /// Called on logout, so a signed-out device is not left polling ThingsBoard
  /// with a token the user expects to be gone.
  static Future<void> disable() async {
    await AlarmBridge.instance.disable();
  }

  /// Raises a notification for an alarm the dashboard just detected.
  ///
  /// The background module has its own notification path, so this is only for
  /// alarms found while the app is open. De-duplication against the background
  /// is handled by the shared active-alert set rather than by a timer here.
  static Future<void> notifyAlarm({
    required String id,
    required String title,
    required String message,
    required bool critical,
  }) async {
    try {
      await _notifications.show(
        id.hashCode,
        title,
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            critical ? _channelCritical : _channelWarning,
            critical ? 'EnerGrow critical alarms' : 'EnerGrow alarms',
            channelDescription: 'Alerts from PLTS monitoring',
            importance: critical ? Importance.max : Importance.high,
            priority: critical ? Priority.max : Priority.high,
            category: AndroidNotificationCategory.alarm,
            enableVibration: true,
            icon: '@drawable/ic_energrow',
          ),
        ),
      );
    } on Exception catch (error) {
      debugPrint('Could not show the notification for $id: $error');
    }
  }

  /// Builds the ThingsBoard device list the background check should poll.
  ///
  /// Only the keys the armed rules actually read are requested, so a background
  /// check with just a low-SOC rule downloads one number instead of the
  /// twenty-two the dashboard charts. A device with no armed rule is omitted
  /// entirely, except that a device needing only a staleness check still gets
  /// one key, because the timestamp has to come from a series that exists.
  static List<Map<String, dynamic>> _devicesFor(List<AlarmRule> rules) {
    final byDevice = <AlarmDevice, Set<String>>{};
    for (final rule in rules) {
      byDevice
          .putIfAbsent(rule.device, () => <String>{})
          .add(rule.metric ?? _freshnessKeyFor(rule.device));
    }
    return [
      (AlarmDevice.battery, ThingsBoardApi.deviceBattery),
      (AlarmDevice.pzem, ThingsBoardApi.devicePzem),
      (AlarmDevice.sensor, ThingsBoardApi.deviceSensor),
      // Without this entry buildAlarmRules still emits stale_fish/offline_fish,
      // and parseAlarmConfig then rejects the entire config, so the background
      // check stops notifying altogether while Settings still reports "ok".
      (AlarmDevice.fish, ThingsBoardApi.deviceFish),
    ].where((entry) => byDevice.containsKey(entry.$1)).map((entry) {
      return {
        'device': entry.$1.wireName,
        'deviceId': entry.$2,
        'keys': byDevice[entry.$1]!.toList(),
      };
    }).toList();
  }

  /// A key that is certain to exist, used when a device only needs a timestamp.
  static String _freshnessKeyFor(AlarmDevice device) => switch (device) {
    AlarmDevice.battery => ThingsBoardApi.batteryKeys.first,
    AlarmDevice.pzem => ThingsBoardApi.pzemKeys.first,
    AlarmDevice.sensor => ThingsBoardApi.sensorKeys.first,
    AlarmDevice.fish => ThingsBoardApi.fishKeys.first,
  };
}
