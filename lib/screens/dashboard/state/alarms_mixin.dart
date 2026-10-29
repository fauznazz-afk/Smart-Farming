import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/alarm_bridge.dart';
import '../../../services/alarm_history_service.dart';
import '../../../services/alarm_notification_service.dart';
import '../../../services/thingsboard_api.dart';
import '../../../utils/alarm_rules.dart';
import '../utils/telemetry_helpers.dart';

/// The alarm half of the dashboard: rule evaluation, the active set, and the
/// two side effects an alarm has (history record, notification).
///
/// A mixin on the screen's `State` rather than a service object because the
/// rules read the same four device fields the cards do, and the banner is
/// rebuilt from the same notifier the evaluation writes. A service would need
/// every reading passed in on each telemetry frame.
mixin DashboardAlarms<T extends StatefulWidget> on State<T> {
  final _alarmHistoryService = AlarmHistoryService();
  final ValueNotifier<List<String>> alertMessages = ValueNotifier(const []);

  AlarmThresholds _thresholds = AlarmThresholds.defaults;

  /// The rule list, rebuilt only when the thresholds change.
  ///
  /// This was a getter, so every read rebuilt the whole list from scratch --
  /// roughly fifteen `AlarmRule` objects plus nine short-lived helper instances.
  /// `evaluateEnergyAlerts` reads it on every telemetry frame the socket
  /// delivers, and does so *before* its own `if (!changed) return` bail-out, so
  /// the common case of nothing having changed still paid for a fresh rule list.
  /// The thresholds only move in `_setThresholds`, which is the only writer.
  late List<AlarmRule> _alarmRules = buildAlarmRules(_thresholds);

  /// Alarms currently raised, and the subset of them already reported.
  ///
  /// Seeded from the native alarm module so an alarm the background check
  /// already notified about is not notified about again here, and published
  /// back to it so the reverse also holds.
  Set<String> activeAlertIds = {};

  /// Whether the background module's active set has been read yet.
  bool _activeAlertsPrimed = false;

  AlarmThresholds get thresholds => _thresholds;

  int get staleTelemetryMinutes => _thresholds.staleMinutes;

  /// The readings the rules judge. Implemented by the screen.
  List<AlarmReading> get alarmReadings;

  /// Fetches the current ThingsBoard session, for the notification module.
  ThingsBoardApi get alarmApi;

  void setThresholds(AlarmThresholds value) {
    if (identical(value, _thresholds)) return;
    _thresholds = value;
    _alarmRules = buildAlarmRules(value);
  }

  /// Reads the set of alarms the background check has already reported.
  ///
  /// Awaited during startup, before anything is allowed to announce an alarm.
  /// Doing it lazily inside the evaluation was the earlier mistake: the read is
  /// asynchronous, so the first evaluation always saw an empty set and reported
  /// alarms that the background had already reported, which is exactly the
  /// duplicate the shared set exists to prevent.
  Future<void> primeActiveAlerts() async {
    if (_activeAlertsPrimed) return;
    _activeAlertsPrimed = true;
    final background = await AlarmBridge.instance.activeAlerts();
    if (!mounted || background.isEmpty) return;
    activeAlertIds = {...activeAlertIds, ...background};
  }

  void evaluateEnergyAlerts() {
    final now = DateTime.now();
    final signals = evaluateAlarmRules(
      rules: _alarmRules,
      readings: alarmReadings,
      now: now,
    );
    final alerts = {for (final signal in signals) signal.id: signal.message};

    final newSignals = newlyActiveSignals(
      signals: signals,
      alreadyActive: activeAlertIds,
    );
    final nextMessages = signals.map((signal) => signal.message).toList();
    final changed =
        alerts.length != activeAlertIds.length ||
        !alerts.keys.every(activeAlertIds.contains) ||
        !sameStrings(nextMessages, alertMessages.value);
    if (!changed) return;
    activeAlertIds = alerts.keys.toSet();
    alertMessages.value = nextMessages;
    unawaited(AlarmBridge.instance.setActiveAlerts(activeAlertIds));

    // Nothing is announced until the background module's active set has been
    // read. Before that read completes every alarm looks new, because a fresh
    // process starts with an empty set, and the first evaluation would report
    // alarms the background had already reported. The banner still updates, so
    // the user sees the state immediately either way.
    if (_activeAlertsPrimed && newSignals.isNotEmpty) {
      for (final signal in newSignals) {
        _persistAlarm(signal, now);
      }
    }
    // No SnackBar here, deliberately. The same messages already render in
    // `EnergyAlertBanner` at the top of the list, above the greeting, so the
    // SnackBar was the same sentence twice — once where the user was already
    // looking and once over the bottom of the screen, where it covered the
    // energy card and the navigation bar. Worse, it re-fired on every message
    // change rather than on every new alarm, so a reading drifting in and out
    // of range popped a bar every few seconds while the banner just sat there.
    // The banner is persistent, non-modal, and does not obscure content; that
    // is the right shape for a condition that is still true.
  }

  void _persistAlarm(AlarmSignal signal, DateTime now) {
    unawaited(
      _alarmHistoryService.addAlarm(
        AlarmRecord(
          id: '${now.millisecondsSinceEpoch}_${signal.id}',
          timestamp: now,
          type: signal.type,
          severity: signal.severity,
          message: signal.message,
          value: signal.value,
        ),
      ),
    );
    unawaited(
      AlarmNotificationService.notifyAlarm(
        id: signal.id,
        title: signal.isCritical
            ? 'EnerGrow: Critical alarm'
            : 'EnerGrow: Warning alarm',
        message: signal.message,
        critical: signal.isCritical,
      ),
    );
  }
}
