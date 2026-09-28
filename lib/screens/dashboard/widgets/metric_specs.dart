import 'package:flutter/material.dart';

import '../../../utils/alarm_rules.dart';
import 'metric_grid.dart';

/// The greenhouse readings, in display order.
///
/// Labels are short. "Ambient Temp" used to ellipsise to "Ambient T..." in a
/// third-width card, which cost the reader the one thing they needed most; the
/// labels were shortened before a status icon was added, and the icon has since
/// been removed, so there is room to grow them back if the cards ever get wider.
///
/// `temp_ds18b20` and `lux` carry no `metric`, which is the established way to
/// say "shown but not watched": the value appears, there is no verdict and no
/// range caption, because there is no limit on them to have an opinion about.
const List<MetricSpec> kEnvironmentSpecs = [
  MetricSpec('temp_dht', 'Temperature', '°C', Icons.thermostat,
      metric: 'temp_dht'),
  MetricSpec('humidity_dht', 'Humidity', '%', Icons.water_drop,
      metric: 'humidity_dht'),
  MetricSpec('temp_ds18b20', 'PV Temp', '°C', Icons.device_thermostat),
  MetricSpec('lux', 'Light', 'lx', Icons.light_mode),
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
  MetricSpec('ph', 'pH', '', Icons.science, metric: 'ph', decimals: 2),
  // The key is `suhu` because that is what the device publishes; the label is
  // English like every other one in the app.
  MetricSpec('suhu', 'Temperature', '°C', Icons.thermostat, metric: 'suhu'),
  // NTU sensors are typically good to a few percent, so a fixed one decimal
  // would print 2395.5 for a 2395.534 reading and imply precision that is not
  // there. Zero decimals is the honest choice.
  MetricSpec('turbidity_ntu', 'Turbidity', 'NTU', Icons.blur_on,
      metric: 'turbidity_ntu', decimals: 0),
  MetricSpec('water_level_percent', 'Water Level', '%', Icons.water_drop),
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
