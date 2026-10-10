import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';

/// What a chart plots, declared once and used by the request builder, the
/// legend, the statistics row and the axis.
class ChartSeriesSpec {
  const ChartSeriesSpec({
    required this.key,
    required this.label,
    required this.unit,
  });

  final String key;
  final String label;
  final String unit;

  /// The metric category this series belongs to, derived from [key].
  ///
  /// **A getter, and that is the whole change.** The constructor field this
  /// replaces was filled in by one of five tiny helper functions at the
  /// declaration site (`_pv`, `_ac`, `_battery`, `_env`, `_water`), which made
  /// it a second copy of a fact the key already determines — the same "a key in
  /// one place and a label in another" shape this repo has already paid for
  /// twice, with the chart storage key and with the hand-written surface list.
  /// `MetricCategory.forKey` is the single resolution, and
  /// `color_helpers_test.dart` pins it for every telemetry key below.
  ///
  /// The key is the source of truth, so a series whose key belongs to no
  /// category resolves to `null` here and to the accent in [color] — visible on
  /// a device rather than silently wrong.
  MetricCategory? get category => MetricCategory.forKey(key);

  /// The series hue: its category's, or [fallbackAccent] for a value that
  /// belongs to no category.
  ///
  /// `categoryColorForKey` rather than `categoryColor(category!)`, so there is
  /// one path from key to hue in the app. Every series declared below already
  /// resolves through it: the four PV keys are all `MetricCategory.pv`, the six
  /// AC keys all `ac`, and so on, which is what "one hue per category" means
  /// here.
  Color color(Color fallbackAccent) =>
      categoryColorForKey(key) ?? fallbackAccent;
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

/// Every chart a page prefix can draw, in display order.
///
/// **No per-series helper functions.** They existed to stamp a `MetricCategory`
/// onto each series, which the key already determines; see
/// [ChartSeriesSpec.category]. The category of every series below is read from
/// its key, exactly as every other colour in the app reads it.
List<ChartGroup> chartGroupsForPrefix(String prefix) => switch (prefix) {
  'pv' => [
    ChartGroup('PV', [
      ChartSeriesSpec(key: 'voltage_dc', label: 'Voltage', unit: 'V'),
      ChartSeriesSpec(key: 'current_dc', label: 'Current', unit: 'A'),
      ChartSeriesSpec(key: 'power_dc', label: 'Power', unit: 'W'),
      ChartSeriesSpec(key: 'energy_dc', label: 'Energy', unit: 'Wh'),
    ]),
  ],
  'ac' => [
    ChartGroup('AC', [
      ChartSeriesSpec(key: 'voltage_ac', label: 'Voltage', unit: 'V'),
      ChartSeriesSpec(key: 'current_ac', label: 'Current', unit: 'A'),
      ChartSeriesSpec(key: 'power_ac', label: 'Power', unit: 'W'),
      ChartSeriesSpec(key: 'frequency_ac', label: 'Frequency', unit: 'Hz'),
      ChartSeriesSpec(key: 'energy_ac', label: 'Energy', unit: 'Wh'),
      ChartSeriesSpec(key: 'pf_ac', label: 'Power Factor', unit: ''),
    ]),
  ],
  'battery' => [
    ChartGroup('Battery', [
      ChartSeriesSpec(key: 'voltage', label: 'Voltage', unit: 'V'),
      ChartSeriesSpec(key: 'current', label: 'Current', unit: 'A'),
      ChartSeriesSpec(key: 'power', label: 'Power', unit: 'W'),
      ChartSeriesSpec(key: 'soc', label: 'State of Charge', unit: '%'),
      ChartSeriesSpec(key: 'cycles', label: 'Cycles', unit: ''),
      ChartSeriesSpec(
        key: 'remain_capacity_ah',
        label: 'Remaining Capacity',
        unit: 'Ah',
      ),
      ChartSeriesSpec(
        key: 'full_capacity_ah',
        label: 'Full Capacity',
        unit: 'Ah',
      ),
    ]),
  ],
  'env' => [
    ChartGroup('Temperature', [
      ChartSeriesSpec(key: 'temp_dht', label: 'Air', unit: '°C'),
      ChartSeriesSpec(key: 'temp_ds18b20', label: 'Panel', unit: '°C'),
    ], height: _compactTwoSeriesHeight),
    ChartGroup('Humidity', [
      ChartSeriesSpec(key: 'humidity_dht', label: 'Humidity', unit: '%'),
    ], height: _compactHeight),
    ChartGroup('Light', [
      ChartSeriesSpec(key: 'lux', label: 'Light', unit: 'lx'),
    ], height: _compactHeight),
    ChartGroup('TDS', [
      ChartSeriesSpec(key: 'tds_ppm', label: 'TDS', unit: 'ppm'),
    ], height: _compactHeight),
  ],
  'fish' => [
    ChartGroup(
      'pH',
      [ChartSeriesSpec(key: 'ph', label: 'pH', unit: '')],
      zeroAnchored: false,
      height: _compactHeight,
    ),
    ChartGroup('Temperature', [
      ChartSeriesSpec(key: 'suhu', label: 'Water', unit: '°C'),
    ], height: _compactHeight),
    ChartGroup('Turbidity', [
      ChartSeriesSpec(key: 'turbidity_ntu', label: 'Turbidity', unit: 'NTU'),
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
  'ac': [
    'voltage_ac',
    'current_ac',
    'power_ac',
    'frequency_ac',
    'energy_ac',
    'pf_ac',
  ],
  'battery': [
    'voltage',
    'current',
    'power',
    'soc',
    'cycles',
    'remain_capacity_ah',
    'full_capacity_ah',
  ],
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
