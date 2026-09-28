import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm_record.dart';
import 'alarm_bridge.dart';

export '../models/alarm_record.dart';

/// Service that persists alarm history to SharedPreferences.
///
/// This store is the one the dashboard writes to. Alarms detected by the
/// background check land in a separate native store, because the Dart and Kotlin
/// sides cannot share the `SharedPreferences` encoding of a list: the plugin
/// stores a `List<String>` as a Base64 Java-serialized blob, which the native
/// module would have to reproduce byte for byte. Reads merge the two, newest
/// first, so the history screen shows the same timeline either way.
///
/// Both stores are capped at [_maxEntries] independently, so the merged list can
/// hold up to twice that.
class AlarmHistoryService {
  static const _storageKey = 'alarm_history';
  static const int _maxEntries = 100;
  static const Duration defaultCooldown = Duration(minutes: 5);

  AlarmHistoryService._();

  static final AlarmHistoryService _instance = AlarmHistoryService._();
  factory AlarmHistoryService() => _instance;

  /// Adds an alarm record to persistent storage.
  /// Trims the list to [_maxEntries] entries, removing the oldest.
  Future<void> addAlarm(
    AlarmRecord record, {
    Duration cooldown = defaultCooldown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = _decode(prefs.getStringList(_storageKey));
    final duplicate = alarms.any(
      (alarm) =>
          alarm.type == record.type &&
          alarm.message == record.message &&
          record.timestamp.difference(alarm.timestamp) >= Duration.zero &&
          record.timestamp.difference(alarm.timestamp) <= cooldown,
    );
    if (duplicate) return;
    alarms.add(record);
    await _save(prefs, alarms);
  }

  /// Returns all alarm records, newest first.
  ///
  /// Merges the records the background check wrote natively. A record is keyed by
  /// its id in both stores, so a duplicate would mean the same alarm was
  /// persisted twice, which the merge drops rather than showing twice.
  Future<List<AlarmRecord>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = _decode(prefs.getStringList(_storageKey));
    final merged = <String, AlarmRecord>{
      for (final alarm in alarms) alarm.id: alarm,
      for (final alarm in await _nativeRecords()) alarm.id: alarm,
    }.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  /// The background module's records, translated into the same model.
  Future<List<AlarmRecord>> _nativeRecords() async {
    final native = await AlarmBridge.instance.history();
    return [
      for (final record in native)
        AlarmRecord(
          id: record.id,
          timestamp: record.timestamp,
          type: _typeFromName(record.type),
          severity: record.severity == 'critical'
              ? AlarmSeverity.critical
              : AlarmSeverity.warning,
          message: record.message,
          value: record.value,
          acknowledged: record.acknowledged,
          resolved: record.resolved,
        ),
    ];
  }

  AlarmType _typeFromName(String name) => AlarmType.values
      .where((value) => value.name == name)
      .firstOrNull ??
      AlarmType.deviceOffline;

  /// Removes all alarm records from storage, on both sides.
  Future<void> clearAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await AlarmBridge.instance.clearHistory();
  }

  Future<void> updateAlarm(AlarmRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = _decode(prefs.getStringList(_storageKey));
    final index = alarms.indexWhere((alarm) => alarm.id == record.id);
    if (index != -1) {
      alarms[index] = record;
      await _save(prefs, alarms);
    }
    // Always sync to the native store so the merged list reflects the change.
    // Without this, an acknowledgement or resolution is lost the next time the
    // screen reloads from the merged list.
    if (record.resolved) {
      await AlarmBridge.instance.resolve(record.id);
    } else if (record.acknowledged) {
      await AlarmBridge.instance.acknowledge(record.id);
    }
    // Reopen (acknowledged=false, resolved=false) has no native equivalent,
    // but the Dart store update above is the source of truth for the UI.
  }

  List<AlarmRecord> _decode(List<String>? raw) {
    return (raw ?? const [])
        .map((jsonStr) {
          try {
            return AlarmRecord.fromJson(
              jsonDecode(jsonStr) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AlarmRecord>()
        .toList();
  }

  Future<void> _save(SharedPreferences prefs, List<AlarmRecord> alarms) async {
    alarms.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (alarms.length > _maxEntries) {
      alarms.removeRange(0, alarms.length - _maxEntries);
    }
    await prefs.setStringList(
      _storageKey,
      alarms.map((alarm) => jsonEncode(alarm.toJson())).toList(),
    );
  }
}
