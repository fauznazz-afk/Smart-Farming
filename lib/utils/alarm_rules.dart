import '../models/alarm_record.dart';

/// The alarm rule set, in one place.
///
/// This module is the single source of truth for *what counts as an alarm*.
/// Two consumers read it:
///
/// 1. `DashboardScreen` calls [evaluateAlarmRules] on every poll to drive the
///    in-app alert banner and the snackbar.
/// 2. `AlarmNotificationService` ships [alarmRulesToJson] to the native
///    `AlarmEvaluator`, which walks the very same rule list to decide whether
///    to raise a notification while the app is not running.
///
/// Because both sides consume one list, a rule can never mean one thing in the
/// app and something else in the background. That is the whole point: an alarm
/// the dashboard shows must be the same alarm the notification reports, with
/// the same wording, or the two disagree the moment a threshold is edited.
///
/// Everything here is pure: no widgets, no I/O, no clock of its own. [now] is
/// passed in so staleness is deterministic under test.

/// Which alert toggle governs a rule.
enum AlarmGroup {
  /// Governed by `SettingsKeys.energyAlertsEnabled`: low SOC and stale devices.
  energy,

  /// Governed by `SettingsKeys.environmentAlertsEnabled`: temperature, humidity
  /// and TDS limits.
  environment,
}

/// Which ThingsBoard device a rule reads from.
enum AlarmDevice {
  battery('battery', 'Baterai'),
  pzem('pzem', 'PZEM'),
  sensor('sensor', 'Sensor lingkungan');

  const AlarmDevice(this.wireName, this.label);

  /// Stable identifier used in the JSON handed to the native evaluator.
  final String wireName;

  /// Human-readable device name, used in the stale message.
  final String label;

  static AlarmDevice? fromWireName(String value) {
    for (final device in AlarmDevice.values) {
      if (device.wireName == value) return device;
    }
    return null;
  }
}

/// How a rule decides it is active.
enum AlarmComparison {
  /// Active while `value < limit`.
  lessThan,

  /// Active while `value > limit`.
  greaterThan,

  /// Active while the device's last telemetry is older than `staleMinutes`.
  /// `metric` and `limit` are unused.
  stale,
}

/// Which wording to render, so the Dart and Kotlin formatters stay in step.
enum AlarmMessageKind {
  /// `SOC baterai rendah: 15%`
  lowSoc,

  /// `Data Baterai belum diperbarui`
  stale,

  /// `Suhu lingkungan rendah: 12.4 °C (batas 18.0 °C)`
  rangeLow,

  /// `Suhu lingkungan tinggi: 31.2 °C (batas 30.0 °C)`
  rangeHigh,
}

/// One alarm condition, fully self-describing.
///
/// A rule carries its own [staleMinutes] rather than reading it from a
/// preference, so a serialised rule list can be evaluated by a process that
/// has no access to the app's settings store.
class AlarmRule {
  const AlarmRule({
    required this.id,
    required this.type,
    required this.severity,
    required this.group,
    required this.device,
    required this.metric,
    required this.comparison,
    required this.limit,
    required this.label,
    required this.unit,
    required this.decimals,
    required this.message,
    required this.staleMinutes,
    this.requireFreshSensor = false,
  });

  /// Stable identity of the condition, e.g. `low_soc`.
  ///
  /// It is persisted inside alarm records and used for notification
  /// de-duplication, so changing one is a breaking change for existing
  /// history and for the native `lastNotified` map.
  final String id;

  final AlarmType type;
  final AlarmSeverity severity;
  final AlarmGroup group;
  final AlarmDevice device;

  /// Telemetry key to read, or null for [AlarmComparison.stale].
  final String? metric;

  final AlarmComparison comparison;

  /// Threshold to compare against, or null for [AlarmComparison.stale].
  final double? limit;

  /// Subject used in the rendered message.
  final String label;

  /// Unit shown after the value, empty for rules that embed it in the wording.
  final String unit;

  /// Decimal places for the measured value.
  final int decimals;

  final AlarmMessageKind message;

  /// Staleness window in minutes, applied to this rule's own checks.
  final int staleMinutes;

  /// When true the rule stays quiet unless the *sensor* reading is fresh.
  ///
  /// The dashboard has always suppressed environment alerts while the sensor
  /// was stale: an out-of-date reading crossing a limit says nothing about the
  /// greenhouse, and firing anyway produced alerts for conditions that had
  /// already ended.
  final bool requireFreshSensor;
}

/// The numeric and freshness state of one device, as the evaluator needs it.
class AlarmReading {
  const AlarmReading({
    required this.device,
    required this.values,
    required this.lastUpdate,
  });

  final AlarmDevice device;
  final Map<String, double> values;
  final DateTime? lastUpdate;

  /// Mirrors `DeviceTelemetry.isStale`, including its treatment of a device
  /// that has never reported as stale.
  bool isStale(int minutes, DateTime now) {
    final last = lastUpdate;
    if (last == null) return true;
    return now.difference(last).inMinutes > minutes;
  }

  double? operator [](String key) => values[key];
}

/// An active rule together with its rendered message.
class AlarmSignal {
  const AlarmSignal({required this.rule, required this.message, this.value});

  final AlarmRule rule;
  final String message;

  /// The measurement that triggered the rule, if it came from a metric.
  final double? value;

  String get id => rule.id;
  AlarmType get type => rule.type;
  AlarmSeverity get severity => rule.severity;

  bool get isCritical => severity == AlarmSeverity.critical;
}

/// The user-configurable limits, resolved from settings and defaults.
class AlarmThresholds {
  const AlarmThresholds({
    required this.energyAlerts,
    required this.environmentAlerts,
    required this.lowSoc,
    required this.staleMinutes,
    this.tempMin,
    this.tempMax,
    this.humidityMin,
    this.humidityMax,
    this.tdsMin,
    this.tdsMax,
  });

  final bool energyAlerts;
  final bool environmentAlerts;
  final double lowSoc;
  final int staleMinutes;
  final double? tempMin;
  final double? tempMax;
  final double? humidityMin;
  final double? humidityMax;
  final double? tdsMin;
  final double? tdsMax;

  /// The default configuration, matching every `?? fallback` in the app.
  static const AlarmThresholds defaults = AlarmThresholds(
    energyAlerts: true,
    environmentAlerts: false,
    lowSoc: 20,
    staleMinutes: 10,
  );
}

/// One user-adjustable limit for an environment sensor.
class _EnvironmentLimit {
  const _EnvironmentLimit({
    required this.metric,
    required this.id,
    required this.label,
    required this.unit,
    required this.minimum,
    required this.maximum,
  });

  final String metric;
  final String id;
  final String label;
  final String unit;
  final double? minimum;
  final double? maximum;
}

/// One side of an [\_EnvironmentLimit], as a rule.
class _EnvironmentBound {
  const _EnvironmentBound({
    required this.suffix,
    required this.comparison,
    required this.limit,
    required this.messageKind,
  });

  final String suffix;
  final AlarmComparison comparison;
  final double? limit;
  final AlarmMessageKind messageKind;
}

/// Builds the rules that are currently armed.
///
/// Rules belonging to a disabled group are omitted rather than carried with a
/// flag, so both consumers work from the same already-filtered list and cannot
/// disagree about whether an alert is enabled. A range with no limit is
/// omitted for the same reason: Settings treats blank as "not monitored".
List<AlarmRule> buildAlarmRules(AlarmThresholds thresholds) {
  final rules = <AlarmRule>[];
  final staleMinutes = thresholds.staleMinutes;

  if (thresholds.energyAlerts) {
    rules.add(
      AlarmRule(
        id: 'low_soc',
        type: AlarmType.lowSoc,
        severity: AlarmSeverity.critical,
        group: AlarmGroup.energy,
        device: AlarmDevice.battery,
        metric: 'soc',
        comparison: AlarmComparison.lessThan,
        limit: thresholds.lowSoc,
        label: AlarmDevice.battery.label,
        unit: '%',
        decimals: 0,
        message: AlarmMessageKind.lowSoc,
        staleMinutes: staleMinutes,
      ),
    );
    for (final device in AlarmDevice.values) {
      rules.add(
        AlarmRule(
          id: 'stale_${device.wireName}',
          type: AlarmType.staleTelemetry,
          severity: AlarmSeverity.warning,
          group: AlarmGroup.energy,
          device: device,
          metric: null,
          comparison: AlarmComparison.stale,
          limit: null,
          label: device.label,
          unit: '',
          decimals: 0,
          message: AlarmMessageKind.stale,
          staleMinutes: staleMinutes,
        ),
      );
    }
  }

  if (thresholds.environmentAlerts) {
    final sensors = <_EnvironmentLimit>[
      _EnvironmentLimit(
        metric: 'temp_dht',
        id: 'ambient_temp',
        label: 'Suhu lingkungan',
        unit: '°C',
        minimum: thresholds.tempMin,
        maximum: thresholds.tempMax,
      ),
      _EnvironmentLimit(
        metric: 'humidity_dht',
        id: 'humidity',
        label: 'Kelembapan',
        unit: '%',
        minimum: thresholds.humidityMin,
        maximum: thresholds.humidityMax,
      ),
      _EnvironmentLimit(
        metric: 'tds_ppm',
        id: 'tds',
        label: 'TDS',
        unit: 'ppm',
        minimum: thresholds.tdsMin,
        maximum: thresholds.tdsMax,
      ),
    ];
    for (final sensor in sensors) {
      final bounds = <_EnvironmentBound>[
        _EnvironmentBound(
          suffix: 'low',
          comparison: AlarmComparison.lessThan,
          limit: sensor.minimum,
          messageKind: AlarmMessageKind.rangeLow,
        ),
        _EnvironmentBound(
          suffix: 'high',
          comparison: AlarmComparison.greaterThan,
          limit: sensor.maximum,
          messageKind: AlarmMessageKind.rangeHigh,
        ),
      ];
      for (final bound in bounds) {
        // A blank limit in Settings means "not monitored", so the rule is not
        // built at all rather than built inert.
        if (bound.limit == null) continue;
        rules.add(
          AlarmRule(
            id: 'environment_${sensor.id}_${bound.suffix}',
            type: _environmentType(sensor.id),
            severity: AlarmSeverity.warning,
            group: AlarmGroup.environment,
            device: AlarmDevice.sensor,
            metric: sensor.metric,
            comparison: bound.comparison,
            limit: bound.limit,
            label: sensor.label,
            unit: sensor.unit,
            decimals: 1,
            message: bound.messageKind,
            staleMinutes: staleMinutes,
            requireFreshSensor: true,
          ),
        );
      }
    }
  }

  return rules;
}

AlarmType _environmentType(String id) => switch (id) {
  'ambient_temp' => AlarmType.environmentTemp,
  'humidity' => AlarmType.environmentHumidity,
  _ => AlarmType.environmentTds,
};

/// Evaluates [rules] against [readings] and returns the active ones.
///
/// [now] is injected so that staleness is testable; callers pass
/// `DateTime.now()`.
List<AlarmSignal> evaluateAlarmRules({
  required List<AlarmRule> rules,
  required List<AlarmReading> readings,
  required DateTime now,
}) {
  final byDevice = <AlarmDevice, AlarmReading>{
    for (final reading in readings) reading.device: reading,
  };
  final signals = <AlarmSignal>[];

  for (final rule in rules) {
    final reading = byDevice[rule.device];
    // A device that has not been read at all cannot raise an alert. This
    // differs from a stale device, which does: staleness is the alarm.
    if (reading == null) continue;

    if (rule.comparison == AlarmComparison.stale) {
      if (reading.isStale(rule.staleMinutes, now)) {
        signals.add(
          AlarmSignal(
            rule: rule,
            message: formatAlarmMessage(rule, value: null),
          ),
        );
      }
      continue;
    }

    final metric = rule.metric;
    if (metric == null) continue;
    final value = reading[metric];
    if (value == null) continue;

    if (rule.requireFreshSensor) {
      final sensor = byDevice[AlarmDevice.sensor];
      if (sensor == null || sensor.isStale(rule.staleMinutes, now)) continue;
    }

    final limit = rule.limit;
    if (limit == null) continue;
    final breached = switch (rule.comparison) {
      AlarmComparison.lessThan => value < limit,
      AlarmComparison.greaterThan => value > limit,
      AlarmComparison.stale => false,
    };
    if (!breached) continue;

    signals.add(
      AlarmSignal(
        rule: rule,
        message: formatAlarmMessage(rule, value: value),
        value: value,
      ),
    );
  }

  return signals;
}

/// The signals that have not been reported before.
///
/// An alarm is announced when it starts, not on every check. [alreadyActive]
/// holds the IDs reported so far, which is shared with the native background
/// check so an alarm it reported is not announced a second time by the app, and
/// an alarm the app reported is not announced again by the background.
///
/// Extracted rather than written inline in the dashboard because it is the rule
/// that keeps notifications from repeating every polling interval, and because a
/// regression here is invisible until a user complains about spam.
List<AlarmSignal> newlyActiveSignals({
  required List<AlarmSignal> signals,
  required Set<String> alreadyActive,
}) => [
  for (final signal in signals)
    if (!alreadyActive.contains(signal.id)) signal,
];

/// Renders the message for [rule].
///
/// The wording is duplicated in the native formatter
/// (`AlarmMessageFormat.kt`) because the notification is built while Dart is
/// not running. `test/fixtures/alarm_parity_vectors.json` pins both sides to
/// the same expected strings; if one drifts, its test fails.
String formatAlarmMessage(AlarmRule rule, {required double? value}) {
  return switch (rule.message) {
    AlarmMessageKind.lowSoc =>
      'SOC baterai rendah: ${_fixed(value ?? 0, rule.decimals)}%',
    AlarmMessageKind.stale => 'Data ${rule.label} belum diperbarui',
    AlarmMessageKind.rangeLow =>
      '${rule.label} rendah: ${_fixed(value ?? 0, rule.decimals)} ${rule.unit} '
          '(batas ${rule.limit} ${rule.unit})',
    AlarmMessageKind.rangeHigh =>
      '${rule.label} tinggi: ${_fixed(value ?? 0, rule.decimals)} ${rule.unit} '
          '(batas ${rule.limit} ${rule.unit})',
  };
}

String _fixed(double value, int decimals) => value.toStringAsFixed(decimals);

/// Serialises [rules] for the native evaluator.
///
/// The native side must not contain threshold or wording knowledge, so
/// everything it needs to evaluate and to write a history record travels in
/// this payload. [version] guards the shape against an app that upgrades its
/// Dart rules while an older native build is still installed.
Map<String, dynamic> alarmRulesToJson(List<AlarmRule> rules) {
  return {
    'version': 1,
    'rules': [
      for (final rule in rules)
        {
          'id': rule.id,
          'type': rule.type.name,
          'severity': rule.severity.name,
          'group': rule.group.name,
          'device': rule.device.wireName,
          'metric': rule.metric,
          'comparison': rule.comparison.name,
          'limit': rule.limit,
          'label': rule.label,
          'unit': rule.unit,
          'decimals': rule.decimals,
          'message': rule.message.name,
          'staleMinutes': rule.staleMinutes,
          'requireFreshSensor': rule.requireFreshSensor,
        },
    ],
  };
}

/// Parses a payload produced by [alarmRulesToJson].
///
/// Used by the Dart test that replays the native fixtures, so a change to the
/// wire shape fails in `flutter test` rather than silently on a device.
List<AlarmRule> alarmRulesFromJson(Map<String, dynamic> json) {
  final raw = json['rules'];
  if (raw is! List) {
    throw const FormatException('alarm rules payload has no "rules" list');
  }
  return [
    for (final entry in raw)
      _ruleFromJson((entry as Map).cast<String, dynamic>()),
  ];
}

AlarmRule _ruleFromJson(Map<String, dynamic> json) {
  final typeName = json['type'] as String;
  final severityName = json['severity'] as String;
  final deviceName = json['device'] as String;
  final comparisonName = json['comparison'] as String;
  final messageName = json['message'] as String;
  final device = AlarmDevice.fromWireName(deviceName);
  if (device == null) {
    throw FormatException('unknown alarm device "$deviceName"');
  }
  return AlarmRule(
    id: json['id'] as String,
    type: AlarmType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => throw FormatException('unknown alarm type "$typeName"'),
    ),
    severity: AlarmSeverity.values.firstWhere(
      (value) => value.name == severityName,
      orElse: () => throw FormatException(
        'unknown alarm severity "$severityName"',
      ),
    ),
    group: AlarmGroup.values.firstWhere(
      (value) => value.name == json['group'],
      orElse: () => throw FormatException('unknown alarm group'),
    ),
    device: device,
    metric: json['metric'] as String?,
    comparison: AlarmComparison.values.firstWhere(
      (value) => value.name == comparisonName,
      orElse: () => throw FormatException(
        'unknown alarm comparison "$comparisonName"',
      ),
    ),
    limit: (json['limit'] as num?)?.toDouble(),
    label: json['label'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    decimals: (json['decimals'] as num?)?.toInt() ?? 1,
    message: AlarmMessageKind.values.firstWhere(
      (value) => value.name == messageName,
      orElse: () => throw FormatException('unknown alarm message "$messageName"'),
    ),
    staleMinutes: (json['staleMinutes'] as num?)?.toInt() ?? 10,
    requireFreshSensor: json['requireFreshSensor'] == true,
  );
}
