import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

/// What a chart plots, declared once and used by the request builder, the
/// legend, the statistics row and the axis.
class ChartSeriesSpec {
  const ChartSeriesSpec({
    required this.key,
    required this.label,
    required this.unit,
    this.category,
  });

  final String key;
  final String label;
  final String unit;

  /// The metric category this series belongs to, determining its colour.
  /// If null, the series uses the user's accent (for single-series groups).
  final MetricCategory? category;

  Color color(Color fallbackAccent) {
    if (category == null) return fallbackAccent;
    return categoryColor(category!);
  }
}

/// The card height for a chart that draws one series on the greenhouse or the
/// fish tank.
const double _compactHeight = 260;

/// The two-sensor greenhouse temperature card, which keeps the multi-series
/// statistics block and so needs more of the plot back.
const double _compactTwoSeriesHeight = 300;

/// A single chart: a title and the series that share its Y axis.
class ChartGroup {
  const ChartGroup(
    this.title,
    this.series, {
    this.zeroAnchored = true,
    this.height,
  });

  final String title;
  final List<ChartSeriesSpec> series;
  final bool zeroAnchored;
  final double? height;

  List<String> get keys => [for (final s in series) s.key];
}

ChartSeriesSpec _pv(int index, String key, String label, String unit) {
  return ChartSeriesSpec(
    key: key,
    label: label,
    unit: unit,
    category: MetricCategory.pv,
  );
}

ChartSeriesSpec _ac(int index, String key, String label, String unit) {
  return ChartSeriesSpec(
    key: key,
    label: label,
    unit: unit,
    category: MetricCategory.ac,
  );
}

ChartSeriesSpec _battery(int index, String key, String label, String unit) {
  return ChartSeriesSpec(
    key: key,
    label: label,
    unit: unit,
    category: MetricCategory.battery,
  );
}

ChartSeriesSpec _env(String key, String label, String unit) {
  return ChartSeriesSpec(
    key: key,
    label: label,
    unit: unit,
    category: MetricCategory.environment,
  );
}

ChartSeriesSpec _water(String key, String label, String unit) {
  return ChartSeriesSpec(
    key: key,
    label: label,
    unit: unit,
    category: MetricCategory.water,
  );
}

/// Every chart a page prefix can draw, in display order.
List<ChartGroup> chartGroupsForPrefix(String prefix) => switch (prefix) {
  'pv' => [
    ChartGroup('PV', [
      _pv(0, 'voltage_dc', 'Voltage', 'V'),
      _pv(1, 'current_dc', 'Current', 'A'),
      _pv(2, 'power_dc', 'Power', 'W'),
      _pv(3, 'energy_dc', 'Energy', 'Wh'),
    ]),
  ],
  'ac' => [
    ChartGroup('AC', [
      _ac(0, 'voltage_ac', 'Voltage', 'V'),
      _ac(1, 'current_ac', 'Current', 'A'),
      _ac(2, 'power_ac', 'Power', 'W'),
      _ac(3, 'frequency_ac', 'Frequency', 'Hz'),
      _ac(4, 'energy_ac', 'Energy', 'Wh'),
      _ac(5, 'pf_ac', 'Power Factor', ''),
    ]),
  ],
  'battery' => [
    ChartGroup('Battery', [
      _battery(0, 'voltage', 'Voltage', 'V'),
      _battery(1, 'current', 'Current', 'A'),
      _battery(2, 'power', 'Power', 'W'),
      _battery(3, 'soc', 'State of Charge', '%'),
      _battery(4, 'cycles', 'Cycles', ''),
      _battery(5, 'remain_capacity_ah', 'Remaining Capacity', 'Ah'),
      _battery(6, 'full_capacity_ah', 'Full Capacity', 'Ah'),
    ]),
  ],
  'env' => const [
    ChartGroup('Temperature', [
      _env('temp_dht', 'Air', '°C'),
      _env('temp_ds18b20', 'Panel', '°C'),
    ], height: _compactTwoSeriesHeight),
    ChartGroup('Humidity', [
      _env('humidity_dht', 'Humidity', '%'),
    ], height: _compactHeight),
    ChartGroup('Light', [
      _env('lux', 'Light', 'lx'),
    ], height: _compactHeight),
    ChartGroup('TDS', [
      _env('tds_ppm', 'TDS', 'ppm'),
    ], height: _compactHeight),
  ],
  'fish' => const [
    ChartGroup('pH', [
      _water('ph', 'pH', ''),
    ], zeroAnchored: false, height: _compactHeight),
    ChartGroup('Temperature', [
      _water('suhu', 'Water', '°C'),
    ], height: _compactHeight),
    ChartGroup('Turbidity', [
      _water('turbidity_ntu', 'Turbidity', 'NTU'),
    ], height: _compactHeight),
  ],
  _ => const [],
};

/// Every telemetry key a prefix's charts need, flattened.
List<String> chartKeysForPrefix(String prefix) => [
  for (final group in chartGroupsForPrefix(prefix)) ...group.keys,
];

/// The keys each page requests, pinned.
const Map<String, List<String>> kHistoryKeysByPrefix = {
  'pv': ['voltage_dc', 'current_dc', 'power_dc', 'energy_dc'],
  'ac': ['voltage_ac', 'current_ac', 'power_ac', 'frequency_ac', 'energy_ac', 'pf_ac'],
  'battery': ['voltage', 'current', 'power', 'soc', 'cycles', 'remain_capacity_ah', 'full_capacity_ah'],
  'env': ['temp_dht', 'temp_ds18b20', 'humidity_dht', 'lux', 'tds_ppm'],
  'fish': ['ph', 'suhu', 'turbidity_ntu'],
};

/// The page title for a prefix, or null when the prefix draws no chart.
String? chartPageTitle(String prefix) => switch (prefix) {
  'pv' => 'PV',
  'ac' => 'AC',
  'battery' => 'Battery',
  'env' => 'Environment',
  'fish' => 'Fish tank',
  _ => null,
};