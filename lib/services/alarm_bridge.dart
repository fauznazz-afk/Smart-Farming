import 'dart:async';

import 'package:flutter/services.dart';

import '../utils/alarm_rules.dart';

/// Where the background check's own alarm history lives.
///
/// The native module keeps a separate store from [AlarmHistoryService] on
/// purpose. The Dart one writes through `shared_preferences`, which stores a
/// `List<String>` as a Base64 Java-serialized blob; reproducing that byte for
/// byte in Kotlin would tie the native module to a plugin's private encoding and
/// break the first time the plugin changed it. A private JSON file on each side,
/// merged on read, is the version that cannot rot.
class NativeAlarmRecord {
  const NativeAlarmRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.message,
    required this.acknowledged,
    required this.resolved,
    this.value,
  });

  final String id;
  final DateTime timestamp;
  final String type;
  final String severity;
  final String message;
  final bool acknowledged;
  final bool resolved;
  final double? value;
}

/// Thin wrapper over the native alarm module's method channel.
///
/// Every method is defensive. The native side may be absent, which is the case
/// on every non-Android platform and in widget tests, and a monitoring app whose
/// dashboard stops working because a background feature is unavailable on the
/// test platform would be a poor trade.
class AlarmBridge {
  AlarmBridge._();

  static final AlarmBridge instance = AlarmBridge._();

  static const MethodChannel _channel = MethodChannel('tech.mbkm.energrow/alarm');

  bool _unavailable = false;

  /// True when the platform has no native alarm module and calls are being
  /// skipped, so the dashboard can explain itself instead of looking broken.
  bool get isUnavailable => _unavailable;

  /// Hands the armed rules and credentials to the native side and arms the
  /// repeating check.
  Future<void> configure({
    required List<AlarmRule> rules,
    required List<Map<String, dynamic>> devices,
    required String baseUrl,
    String? accessToken,
    String? refreshToken,
    bool arm = true,
  }) async {
    final payload = <String, dynamic>{
      ...alarmRulesToJson(rules),
      'baseUrl': baseUrl,
      'devices': devices,
    };
    await _invoke<void>('configure', {
      'config': payload,
      // Deliberately separate from `config`, which is written to disk as plain
      // JSON. The credentials belong to AlarmTokenStore, encrypted under an
      // AndroidKeyStore key, and must never end up inside that file.
      'accessToken': ?accessToken,
      'refreshToken': ?refreshToken,
      'arm': arm,
    });
  }

  /// Cancels the check and forgets the stored configuration and credentials.
  Future<void> disable() => _invoke<void>('disable');

  /// Alarm IDs that are currently active and have already been reported.
  Future<Set<String>> activeAlerts() async {
    final ids = await _invoke<List<dynamic>>('activeAlerts');
    if (ids == null) return <String>{};
    return ids.whereType<String>().toSet();
  }

  /// Shares the active set with the native side so an alarm reported in the
  /// background is not reported again by the dashboard.
  Future<void> setActiveAlerts(Set<String> ids) =>
      _invoke<void>('setActiveAlerts', {'ids': ids.toList()});

  Future<List<NativeAlarmRecord>> history() async {
    final raw = await _invoke<List<dynamic>>('history');
    if (raw == null) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          NativeAlarmRecord(
            id: '${entry['id'] ?? ''}',
            timestamp:
                DateTime.tryParse('${entry['timestamp'] ?? ''}') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            type: '${entry['type'] ?? ''}',
            severity: '${entry['severity'] ?? ''}',
            message: '${entry['message'] ?? ''}',
            acknowledged: entry['acknowledged'] == true,
            resolved: entry['resolved'] == true,
            value: (entry['value'] as num?)?.toDouble(),
          ),
    ];
  }

  Future<bool> acknowledge(String id) async =>
      await _invoke<bool>('acknowledge', {'id': id}) ?? false;

  Future<bool> resolve(String id) async =>
      await _invoke<bool>('resolve', {'id': id}) ?? false;

  Future<void> clearHistory() => _invoke<void>('clearHistory');

  /// Runs a check immediately instead of waiting for the next tick.
  ///
  /// Returns as soon as the work is queued; the check itself runs on a native
  /// background thread because it does network I/O.
  Future<void> checkNow() => _invoke<void>('checkNow');

  /// Diagnostics for the background check, for the settings screen.
  Future<AlarmBridgeStatus?> status() async {
    final raw = await _invoke<Map<dynamic, dynamic>>('status');
    if (raw == null) return null;
    return AlarmBridgeStatus(
      scheduled: raw['scheduled'] == true,
      intervalMinutes: (raw['intervalMinutes'] as num?)?.toInt() ?? 0,
      hasCredentials: raw['hasCredentials'] == true,
      lastCheckAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['lastCheckAt'] as num?)?.toInt() ?? 0,
      ),
      lastOutcome: '${raw['lastOutcome'] ?? ''}',
    );
  }

  /// Tells the native side whether the dashboard is on screen.
  ///
  /// While it is, the dashboard evaluates the same rules on a much shorter
  /// poll, so the background check stands down instead of duplicating the work
  /// and doubling the request rate against the ThingsBoard instance.
  Future<void> setForeground(bool value) =>
      _invoke<void>('setForeground', {'value': value});

  /// Whether Android already exempts the app from battery optimisation.
  Future<bool> isExemptFromBatteryOptimisations() async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? false;

  /// Opens the system screen that can exempt the app from battery optimisation.
  ///
  /// Returns false when the platform has no such screen, or when the app is
  /// already exempt, in which case there is nothing to do.
  Future<bool> requestIgnoreBatteryOptimizations() async =>
      await _invoke<bool>('requestIgnoreBatteryOptimizations') ?? false;

  /// Creates the notification channels.
  ///
  /// The native module does this on every notification, but the dashboard can
  /// raise one before any background check has run, and a notification with no
  /// channel is dropped without an error on Android 8 and newer.
  Future<void> ensureChannels() => _invoke<void>('ensureChannels');

  /// Returns the alarm ID from a notification tap, or null if the app was
  /// launched normally.
  ///
  /// The native side receives `EXTRA_ALARM_ID` via `onNewIntent` when the user
  /// taps an alarm notification. This method reads that ID so the dashboard can
  /// navigate to the alarm history screen.
  Future<String?> launchAlarmId() async {
    final id = await _invoke<String>('launchAlarmId');
    return id?.isEmpty == true ? null : id;
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    if (_unavailable) return null;
    try {
      final result = await _channel.invokeMethod<T>(method, arguments);
      return result;
    } on MissingPluginException {
      // No native module: a non-Android platform, or a test.
      _unavailable = true;
      return null;
    } on PlatformException catch (error) {
      // A bad configuration should not be retried on every call, but the rest
      // of the app must keep working, so this is reported and swallowed.
      _lastError = '$method: ${error.message}';
      return null;
    }
  }

  String? _lastError;

  /// The most recent bridge failure, for diagnostics.
  String? get lastError => _lastError;
}

/// A snapshot of the background check's state, read for display only.
class AlarmBridgeStatus {
  const AlarmBridgeStatus({
    required this.scheduled,
    required this.intervalMinutes,
    required this.hasCredentials,
    required this.lastCheckAt,
    required this.lastOutcome,
  });

  final bool scheduled;
  final int intervalMinutes;
  final bool hasCredentials;
  final DateTime lastCheckAt;
  final String lastOutcome;
}
