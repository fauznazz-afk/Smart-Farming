import 'package:flutter/material.dart';

import '../../../utils/alarm_rules.dart';
import 'metric_grid.dart';

/// The greenhouse readings, in display order.
///
/// **Labels are slot names, not words.** `AMBIENT_T`, `PV_TEMP`, `LUX` — the
/// abbreviated, underscored, monospace vocabulary the Overview panel uses for
/// `PV_OUT` and `BAT_SOC`. A slot name is what the thing is called in the thing's
/// own system, and it is also one glyph per row wider to read than the word it
/// replaced. Only the label changed: `key` is the ThingsBoard telemetry key and
/// `metric` is the alarm-rule name, and neither is display text.
///
/// `temp_ds18b20` and `lux` carry no `metric`, which is the established way to
/// say "shown but not watched": the value appears, there is no verdict and no
/// range caption, because there is no limit on them to have an opinion about.
const List<MetricSpec> kEnvironmentSpecs = [
  MetricSpec('temp_dht', 'AMBIENT_T', '°C', Icons.thermostat,
      metric: 'temp_dht'),
  MetricSpec('humidity_dht', 'HUMIDITY', '%', Icons.water_drop,
      metric: 'humidity_dht'),
  MetricSpec('temp_ds18b20', 'PV_TEMP', '°C', Icons.device_thermostat),
  MetricSpec('lux', 'LUX', 'lx', Icons.light_mode),
  MetricSpec('tds_ppm', 'TDS', 'ppm', Icons.science, metric: 'tds_ppm'),
];

/// The fish tank readings, in display order.
///
/// pH, water temperature and turbidity carry a `metric` matching the keys
/// `AlarmThresholds.minFor` / `maxFor` know, so the grid grades them against the
/// same limits the background alarms use. `water_level_percent` has no configured
/// limit, so it stays un-monitored: displayed, never graded — the same precedent
/// as `lux` on the greenhouse grid.
const List<MetricSpec> kFishSpecs = [
  // pH is logarithmic, so the third decimal place is noise. Two digits is the
  // most that distinguishes a reading worth acting on.
  MetricSpec('ph', 'PH', '', Icons.science, metric: 'ph', decimals: 2),
  // The key is `suhu` because that is what the device publishes; the label is
  // the panel's slot vocabulary like every other one in the app.
  MetricSpec('suhu', 'WATER_T', '°C', Icons.thermostat, metric: 'suhu'),
  // NTU sensors are typically good to a few percent, so a fixed one decimal
  // would print 2395.5 for a 2395.534 reading and imply precision that is not
  // there. Zero decimals is the honest choice.
  MetricSpec('turbidity_ntu', 'TURBIDITY', 'NTU', Icons.blur_on,
      metric: 'turbidity_ntu', decimals: 0),
  MetricSpec('water_level_percent', 'WATER_LVL', '%', Icons.water_drop),
];

/// The configured range for a greenhouse reading, as a caption under the value.
///
/// Only the keys [AlarmThresholds] actually limits produce a caption, so a
/// reading with no limit shows no range rather than an empty one.
String? environmentLimitLabel(MetricSpec spec, AlarmThresholds thresholds) {
  final metric = spec.metric;
  if (metric == null) return null;
  final min = thresholds.minFor(metric);
  final max = thresholds.maxFor(metric);
  if (min != null && max != null) return '${_num(min)}–${_num(max)}';
  if (min != null) return '≥ ${_num(min)}';
  if (max != null) return '≤ ${_num(max)}';
  return null;
}

String _num(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
