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

  /// Governed by `SettingsKeys.fishAlertsEnabled`: fish tank pH, water
  /// temperature and turbidity limits.
  fish,
}

/// Which ThingsBoard device a rule reads from.
///
/// Adding a value here has consequences well past this enum:
///
///  * `buildAlarmRules` loops `AlarmDevice.values`, so a new entry
///    immediately produces a `stale_<wireName>` and an `offline_<wireName>`
///    rule, and every one of them requires the device to be polled.
///  * `AlarmNotificationService._devicesFor` is a hand-written list, and
///    `AlarmRule.parseAlarmConfig` refuses any rule naming a device that is not
///    in it. Omit the device there and the stored config is rejected whole, so
///    every background tick ends at "no alarm config stored" and nothing is ever
///    notified again. No exception, no crash.
///  * `AlarmRule.kt` needs the same wire name, and both `_freshnessKeyFor`
///    (Dart) and `AlarmParityTest.freshnessKeyFor` (Kotlin) are exhaustive
///    `switch`es, so a missing branch is a compile error rather than a silence.
enum AlarmDevice {
  battery('battery', 'Battery'),
  pzem('pzem', 'PZEM'),
  sensor('sensor', 'Environment sensor'),
  fish('fish', 'Fish tank');

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

  /// The same test as [stale] with a longer window and a different meaning: the
  /// device is not merely behind, it has stopped responding.
  ///
  /// A separate comparison rather than a shared one because each carries its own
  /// `staleMinutes`, and the two alarms are deliberately distinct: a ten minute
  /// gap is a hiccup worth a warning, an hour is a dead sensor worth a critical
  /// one.
  offline,
}

/// Which wording to render, so the Dart and Kotlin formatters stay in step.
enum AlarmMessageKind {
  /// `Battery charge low: 15%`
  lowSoc,

  /// `No fresh data from Battery`
  stale,

  /// `PZEM has stopped reporting`
  offline,

  /// `Ambient temperature too low: 12.4 °C (limit 18.0 °C)`
  rangeLow,

  /// `Ambient temperature too high: 31.2 °C (limit 30.0 °C)`
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
    required this.offlineMinutes,
    this.tempMin,
    this.tempMax,
    this.humidityMin,
    this.humidityMax,
    this.tdsMin,
    this.tdsMax,
    this.fishAlerts = true,
    this.fishPhMin,
    this.fishPhMax,
    this.fishTempMin,
    this.fishTempMax,
    this.fishTurbidityMax,
  });

  final bool energyAlerts;
  final bool environmentAlerts;
  final double lowSoc;
  final int staleMinutes;

  /// How long a device must be silent before it counts as dead.
  ///
  /// Deliberately much longer than [staleMinutes]. Ten minutes of silence is a
  /// hiccup in an MQTT pipeline; an hour is a sensor or gateway that has stopped,
  /// which is a different thing to be told about and a different thing to go fix.
  final int offlineMinutes;

  final double? tempMin;
  final double? tempMax;
  final double? humidityMin;
  final double? humidityMax;
  final double? tdsMin;

  /// Intentionally absent. See [defaultTdsMin]: there is no safe upper bound for
  /// TDS, and a low one makes the alert unreachable.
  final double? tdsMax;

  final bool fishAlerts;
  final double? fishPhMin;
  final double? fishPhMax;
  final double? fishTempMin;
  final double? fishTempMax;
  final double? fishTurbidityMax;

  /// The configured lower bound for a telemetry key, or null when that key is not
  /// one this app puts a limit on.
  ///
  /// This mapping used to be written out twice inside the environment grid — once
  /// to colour a card and once to caption it — and both switches ended in
  /// `_ => (null, null)`. That is a safe default for the two keys that had a case,
  /// and a silent one for anything added later: a new monitored sensor would have
  /// shown no verdict and no range with nothing to indicate the omission. It lives
  /// here instead because these are this class's own numbers.
  double? minFor(String metric) => switch (metric) {
    'temp_dht' => tempMin,
    'humidity_dht' => humidityMin,
    'tds_ppm' => tdsMin,
    'ph' => fishPhMin,
    'suhu' => fishTempMin,
    _ => null,
  };

  /// The configured upper bound for a telemetry key, or null. See [minFor].
  double? maxFor(String metric) => switch (metric) {
    'temp_dht' => tempMax,
    'humidity_dht' => humidityMax,
    'tds_ppm' => tdsMax,
    'ph' => fishPhMax,
    'suhu' => fishTempMax,
    'turbidity_ntu' => fishTurbidityMax,
    _ => null,
  };

  // Default environment limits, chosen for a tropical greenhouse and stated here
  // so the settings screen, the dashboard and the background check cannot
  // disagree about them.
  //
  // Night temperatures in a tropical greenhouse sit around 15-18 C and daytime
  // peaks pass 35 C, so the range is wide on purpose: a tighter window would
  // alarm on ordinary weather. Humidity above 85 percent is where fungal disease
  // starts, below 40 percent is where the plants start to suffer.
  static const double defaultTempMin = 15;
  static const double defaultTempMax = 35;
  static const double defaultHumidityMin = 40;
  static const double defaultHumidityMax = 85;

  /// Hydroponic nutrient solution runs 800-2000 ppm.
  ///
  /// Only a floor. An upper bound low enough to look safe would be crossed by
  /// every reading, and sea water sits near 35000 ppm, so any cap at all would
  /// be wrong for some legitimate input. This is the exact regression the
  /// `sensor bounds` tests in `test/settings_validation_test.dart` exist to
  /// catch, so it is recorded here too.
  static const double defaultTdsMin = 800;

  // Fish tank defaults, chosen for a tropical ornamental fish tank.
  //
  // pH 6.5-8.5 covers most tropical fish. Water temperature 20-30 C covers
  // the common range for tropical species.
  static const double defaultFishPhMin = 6.5;
  static const double defaultFishPhMax = 8.5;
  static const double defaultFishTempMin = 20;
  static const double defaultFishTempMax = 30;

  /// No default turbidity limit, and there is no number that could honestly be
  /// one.
  ///
  /// This used to ship as 100 NTU, chosen because real aquaculture guidance
  /// treats 100 NTU as visibly cloudy. The sensor on the test device reports
  /// 2396 NTU and later 2993.5 NTU for the same tank, which is about thirty
  /// times the clearest-water figure quoted for this kind of sensor. The scale
  /// is simply not the documented one, and nobody has established what it
  /// actually measures.
  ///
  /// That made the default a lie in both directions at once. Arming it, which
  /// is what happened the moment a user saved the Fish tank alerts section,
  /// produced a permanent warning alarm against a reading no configuration
  /// could satisfy: "Turbidity too high: 2993.5 NTU (limit 100.0 NTU)", every
  /// minute, indefinitely. And leaving it unconfigured meant the field showed a
  /// number that looked armed and was not.
  ///
  /// Any replacement would be a guess about a sensor nobody has calibrated, and
  /// a guess that fails high is worse than no limit at all: it manufactures an
  /// alarm that can never clear. The same reasoning already governs the display
  /// of `lux` and `water_level_percent` — displayed, never graded, because
  /// inventing a limit the user never set is worse than showing nothing. The
  /// upper bound is now unbounded too, so the user can set whatever the sensor
  /// actually reads once its scale is known.
  static const double? defaultFishTurbidityMax = null;

  static const int defaultLowSoc = 20;
  static const int defaultStaleMinutes = 10;
  static const int defaultOfflineMinutes = 60;

  /// The default configuration, matching every `?? fallback` in the app.
  static const AlarmThresholds defaults = AlarmThresholds(
    energyAlerts: true,
    environmentAlerts: true,
    fishAlerts: true,
    lowSoc: 20,
    staleMinutes: defaultStaleMinutes,
    offlineMinutes: defaultOfflineMinutes,
    tempMin: defaultTempMin,
    tempMax: defaultTempMax,
    humidityMin: defaultHumidityMin,
    humidityMax: defaultHumidityMax,
    tdsMin: defaultTdsMin,
    fishPhMin: defaultFishPhMin,
    fishPhMax: defaultFishPhMax,
    fishTempMin: defaultFishTempMin,
    fishTempMax: defaultFishTempMax,
    fishTurbidityMax: defaultFishTurbidityMax,
  );
}

/// One user-adjustable limit for a monitored sensor.
///
/// Shared between environment and fish sensors: the structure is identical, and
/// a second copy for the fish tank would drift from the first the moment a
/// field was added to one and not the other. The `decimals` field is per-sensor
/// because pH is reported to two decimals while temperatures and turbidity are
/// not.
class _EnvironmentLimit {
  const _EnvironmentLimit({
    required this.metric,
    required this.id,
    required this.label,
    required this.unit,
    required this.minimum,
    required this.maximum,
    this.decimals = 1,
  });

  final String metric;
  final String id;
  final String label;
  final String unit;
  final double? minimum;
  final double? maximum;
  final int decimals;
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
          id: 'offline_${device.wireName}',
          type: AlarmType.deviceOffline,
          severity: AlarmSeverity.critical,
          group: AlarmGroup.energy,
          device: device,
          metric: null,
          comparison: AlarmComparison.offline,
          limit: null,
          label: device.label,
          unit: '',
          decimals: 0,
          message: AlarmMessageKind.offline,
          staleMinutes: thresholds.offlineMinutes,
        ),
      );
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
        label: 'Ambient temperature',
        unit: '°C',
        minimum: thresholds.tempMin,
        maximum: thresholds.tempMax,
      ),
      _EnvironmentLimit(
        metric: 'humidity_dht',
        id: 'humidity',
        label: 'Humidity',
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
            decimals: sensor.decimals,
            message: bound.messageKind,
            staleMinutes: staleMinutes,
            requireFreshSensor: true,
          ),
        );
      }
    }
  }

  if (thresholds.fishAlerts) {
    final sensors = <_EnvironmentLimit>[
      _EnvironmentLimit(
        metric: 'ph',
        id: 'ph',
        label: 'pH',
        unit: '',
        minimum: thresholds.fishPhMin,
        maximum: thresholds.fishPhMax,
        decimals: 2,
      ),
      _EnvironmentLimit(
        metric: 'suhu',
        id: 'water_temp',
        label: 'Water temperature',
        unit: '°C',
        minimum: thresholds.fishTempMin,
        maximum: thresholds.fishTempMax,
      ),
      _EnvironmentLimit(
        metric: 'turbidity_ntu',
        id: 'turbidity',
        label: 'Turbidity',
        unit: 'NTU',
        minimum: null,
        maximum: thresholds.fishTurbidityMax,
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
        if (bound.limit == null) continue;
        rules.add(
          AlarmRule(
            id: 'fish_${sensor.id}_${bound.suffix}',
            type: _fishType(sensor.id),
            severity: AlarmSeverity.warning,
            group: AlarmGroup.fish,
            device: AlarmDevice.fish,
            metric: sensor.metric,
            comparison: bound.comparison,
            limit: bound.limit,
            label: sensor.label,
            unit: sensor.unit,
            decimals: sensor.decimals,
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

AlarmType _fishType(String id) => switch (id) {
  'ph' => AlarmType.fishPh,
  'water_temp' => AlarmType.fishTemp,
  _ => AlarmType.fishTurbidity,
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

    if (rule.comparison == AlarmComparison.stale ||
        rule.comparison == AlarmComparison.offline) {
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
      final device = byDevice[rule.device];
      if (device == null || device.isStale(rule.staleMinutes, now)) continue;
    }

    final limit = rule.limit;
    if (limit == null) continue;
    final breached = switch (rule.comparison) {
      AlarmComparison.lessThan => value < limit,
      AlarmComparison.greaterThan => value > limit,
      AlarmComparison.stale ||
      AlarmComparison.offline => false,
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
/// not running. `android/app/src/test/resources/alarm_parity_vectors.json` pins
/// both sides to the same expected strings; if one drifts, its test fails.
///
/// **The unit is optional, and the template used to make that visible as broken
/// whitespace.** pH is the one rule built with an empty `unit`, and the old
/// template emitted `' $unit '` unconditionally, so a pH alarm read
/// `pH too high: 9.10  (limit 8.5 )` -- two spaces before the parenthesis and one
/// before the closing paren. That string reached the user three ways: the in-app
/// banner, the persisted `AlarmRecord.message`, and the background notification,
/// because all three call this function.
///
/// It survived because the parity fixture is *generated from* these strings, so
/// `flutter test` and `:app:testDebugUnitTest` were both green with the malformed
/// text pinned as expected output on both language sides. A golden fixture
/// generated from the thing under test cannot catch a defect in it. That is the
/// general lesson, and it is narrower than it looks: the fixture pins the two
/// languages to each other, and it was never a claim that the shared text is
/// correct.
///
/// The unit now goes through a helper that collapses the padding when there is
/// nothing to pad. Only the pH vectors change, which is what makes the fixture
/// diff worth reading.
String formatAlarmMessage(AlarmRule rule, {required double? value}) {
  return switch (rule.message) {
    AlarmMessageKind.lowSoc =>
      'Battery charge low: ${_fixed(value ?? 0, rule.decimals)}%',
    AlarmMessageKind.stale => 'No fresh data from ${rule.label}',
    AlarmMessageKind.offline => '${rule.label} has stopped reporting',
    AlarmMessageKind.rangeLow =>
      '${rule.label} too low: ${_fixed(value ?? 0, rule.decimals)}${_unit(rule)} '
          '(limit ${rule.limit}${_unit(rule)})',
    AlarmMessageKind.rangeHigh =>
      '${rule.label} too high: ${_fixed(value ?? 0, rule.decimals)}${_unit(rule)} '
          '(limit ${rule.limit}${_unit(rule)})',
  };
}

String _fixed(double value, int decimals) => value.toStringAsFixed(decimals);

/// ` ppm` for a rule that carries a unit, and the empty string for one that does
/// not, so an absent unit leaves no gap behind. Leading space only: the space
/// that separates `5.80` from `(limit` is a literal in the template, which is why
/// adding one here as well would double it on every rule that *does* have a unit.
String _unit(AlarmRule rule) => rule.unit.isEmpty ? '' : ' ${rule.unit}';

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
