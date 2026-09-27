import 'package:flutter/material.dart';

import '../../../utils/alarm_rules.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';

/// A single environment reading card.
class _EnvSpec {
  const _EnvSpec(this.key, this.label, this.unit, this.icon, {this.metric});

  final String key;
  final String label;
  final String unit;
  final IconData icon;

  /// The key this card is judged against in the alarm rules, or null when the
  /// reading is displayed but not monitored. `temp_ds18b20` and `lux` are
  /// informational: there is no limit on them, so showing a verdict for them
  /// would be inventing one.
  final String? metric;
}

/// Labels are short. "Ambient Temp" used to ellipsise to
/// "Ambient T..." in a third-width card, which cost the reader the one thing
/// they needed most; the labels were shortened before a status icon was added,
/// and the icon has since been removed, so there is room to grow them back if
/// the cards ever get wider.
const _envSpecs = [
  _EnvSpec('temp_dht', 'Temperature', '°C', Icons.thermostat,
      metric: 'temp_dht'),
  _EnvSpec('humidity_dht', 'Humidity', '%', Icons.water_drop,
      metric: 'humidity_dht'),
  _EnvSpec('temp_ds18b20', 'PV Temp', '°C', Icons.device_thermostat),
  _EnvSpec('lux', 'Light', 'lx', Icons.light_mode),
  _EnvSpec('tds_ppm', 'TDS', 'ppm', Icons.science, metric: 'tds_ppm'),
];

/// Grid of environment sensor readings (temperature, humidity, lux, TDS).
///
/// Every card that has a limit also shows whether the reading is inside it, and
/// the grid is closed with a single verdict. Before this, the five numbers were
/// shown with no reference to the limits the user had just configured, so a
/// reading of 38 °C looked the same as a healthy one until the alert banner
/// appeared somewhere else on the screen.
class EnvironmentGrid extends StatelessWidget {
  const EnvironmentGrid({
    super.key,
    required this.values,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
    this.thresholds,
    this.staleMinutes = 10,
    this.lastUpdate,
  });

  final Map<String, double>? values;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  /// The user's current limits, used to grade each reading.
  final AlarmThresholds? thresholds;

  /// Used to decide whether the grid as a whole can be trusted.
  final int staleMinutes;

  final DateTime? lastUpdate;

  @override
  Widget build(BuildContext context) {
    final verdicts = _Verdicts.of(values, thresholds, lastUpdate, staleMinutes);
    final monitored = _envSpecs.where((spec) => spec.metric != null).toList();
    final breached = monitored
        .where((spec) => verdicts.isBreached(spec))
        .length;

    Widget card(_EnvSpec spec) => Expanded(
      child: _EnvCard(
        spec: spec,
        value: values?[spec.key],
        verdict: verdicts.verdictFor(spec),
        limit: _limitLabel(spec),
        isDark: isDark,
        seedColor: seedColor,
        performanceMode: performanceMode,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Environment',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const Spacer(),
            // Only speaks up when there is something wrong. The green "Semua
            // normal" state with a tick was the other half of the checklist
            // effect: five sensors always in range is the boring case, and
            // asserting it permanently put a permanent badge on the screen.
            if (verdicts.isStale)
              _Tag(
                text: 'Stale data',
                color: statusWarn(isDark),
                isDark: isDark,
              )
            else if (breached > 0)
              _Tag(
                text: '$breached out of range',
                color: statusBad(isDark),
                isDark: isDark,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            card(_envSpecs[0]),
            const SizedBox(width: 8),
            card(_envSpecs[1]),
            const SizedBox(width: 8),
            card(_envSpecs[2]),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            card(_envSpecs[3]),
            const SizedBox(width: 8),
            card(_envSpecs[4]),
          ],
        ),
      ],
    );
  }

  /// The configured range, as a caption under the value.
  String? _limitLabel(_EnvSpec spec) {
    final t = thresholds;
    final metric = spec.metric;
    if (t == null || metric == null) return null;
    final (min, max) = switch (metric) {
      'temp_dht' => (t.tempMin, t.tempMax),
      'humidity_dht' => (t.humidityMin, t.humidityMax),
      'tds_ppm' => (t.tdsMin, t.tdsMax),
      _ => (null, null),
    };
    if (min != null && max != null) {
      return '${_num(min)}–${_num(max)}';
    }
    if (min != null) return '≥ ${_num(min)}';
    if (max != null) return '≤ ${_num(max)}';
    return null;
  }

  static String _num(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

/// Whether each monitored reading sits inside its configured range.
class _Verdicts {
  const _Verdicts(this.breached, this.isStale);

  final Map<String, bool> breached;
  final bool isStale;

  static _Verdicts of(
    Map<String, double>? values,
    AlarmThresholds? thresholds,
    DateTime? lastUpdate,
    int staleMinutes,
  ) {
    final result = <String, bool>{};
    if (values != null && thresholds != null) {
      for (final spec in _envSpecs) {
        final metric = spec.metric;
        final value = metric == null ? null : values[metric];
        if (metric == null || value == null) continue;
        final (min, max) = switch (metric) {
          'temp_dht' => (thresholds.tempMin, thresholds.tempMax),
          'humidity_dht' => (thresholds.humidityMin, thresholds.humidityMax),
          'tds_ppm' => (thresholds.tdsMin, thresholds.tdsMax),
          _ => (null, null),
        };
        result[metric] = (min != null && value < min) || (max != null && value > max);
      }
    }
    // A stale reading says nothing about the current climate, so the grid must
    // not claim everything is fine while the sensor is dead.
    final stale = lastUpdate == null ||
        DateTime.now().difference(lastUpdate).inMinutes > staleMinutes;
    return _Verdicts(result, stale);
  }

  bool isBreached(_EnvSpec spec) =>
      spec.metric != null && breached[spec.metric] == true;

  /// Null means "no verdict", which is different from "within range".
  bool? verdictFor(_EnvSpec spec) {
    final metric = spec.metric;
    if (metric == null) return null;
    final out = breached[metric];
    if (out == null) return null;
    return !out;
  }
}

/// The grid's single verdict, shown only when something is wrong.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.isDark});

  final String text;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _EnvCard extends StatelessWidget {
  const _EnvCard({
    required this.spec,
    required this.value,
    required this.verdict,
    required this.limit,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
  });

  final _EnvSpec spec;
  final double? value;

  /// True when inside the range, false when outside, null when unjudgeable.
  final bool? verdict;

  /// The configured range, shown so a number has something to be read against.
  final String? limit;

  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(isDark);
    final accent = metricColor(
      seedColor: seedColor,
      index: 3,
      isDark: isDark,
    );
    // Only a breach is coloured. A reading inside its range keeps the card's own
    // accent-tinted outline and an ordinary caption, because "fine" is the
    // boring case and green is not information: it is a second colour system
    // sitting next to the theme, and in an amber or cyan theme the page filled
    // up with green text the user had never chosen. The grid's verdict at the
    // top already counts what is out of range.
    final breached = verdict == false;
    final status = breached ? statusBad(isDark) : null;

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(8),
      borderColor: status?.withValues(alpha: isDark ? 0.45 : 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 14, color: accent),
              const SizedBox(width: 4),
              // No tick or warning glyph. Out-of-range used to be signalled
              // three ways on one card — a tick, a warning triangle, and a red
              // border — which turned a reading into a checklist item. The
              // coloured border and the range caption below are enough, and they
              // stay visible in peripheral vision the way an icon did not.
              Expanded(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value == null ? '--' : value!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 3),
              Text(spec.unit, style: TextStyle(fontSize: 11, color: faint)),
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: 2),
            Text(
              limit!,
              style: TextStyle(fontSize: 9, color: status ?? faint),
            ),
          ],
        ],
      ),
    );
  }
}
