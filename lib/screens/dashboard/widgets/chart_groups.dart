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
///
/// **The electrical pages plot three series each: voltage, current, power.**
/// That is the whole of what a PZEM meter is for — how much is coming in, how
/// hard it is working, and how much it is delivering — and it is what the user
/// asked for. The other keys a page owns (`energy_*`, `frequency_ac`, `pf_ac`,
/// `soc`, `cycles`, the two capacities) are still fetched and still shown in
/// the metric cards above the charts; they are simply not plotted, because a
/// chart with seven lines on one axis is not a reading, it is a texture, and
/// the energy integral in particular is a monotonically rising line that
/// carries no information per day.
///
/// The consequence is that each electrical group is a **multi-series** group,
/// so it takes the fixed series order in [kChartSeriesOrder] rather than its
/// category hue — see `chart_card.dart` for why a group cannot be coloured by
/// category when it has more than one series.
List<ChartGroup> chartGroupsForPrefix(String prefix) => switch (prefix) {
  'pv' => [
    ChartGroup('PV', [
      ChartSeriesSpec(key: 'voltage_dc', label: 'Voltage', unit: 'V'),
      ChartSeriesSpec(key: 'current_dc', label: 'Current', unit: 'A'),
      ChartSeriesSpec(key: 'power_dc', label: 'Power', unit: 'W'),
    ]),
  ],
  'ac' => [
    ChartGroup('AC', [
      ChartSeriesSpec(key: 'voltage_ac', label: 'Voltage', unit: 'V'),
      ChartSeriesSpec(key: 'current_ac', label: 'Current', unit: 'A'),
      ChartSeriesSpec(key: 'power_ac', label: 'Power', unit: 'W'),
    ]),
  ],
  'battery' => [
    ChartGroup('Battery', [
      ChartSeriesSpec(key: 'voltage', label: 'Voltage', unit: 'V'),
      ChartSeriesSpec(key: 'current', label: 'Current', unit: 'A'),
      ChartSeriesSpec(key: 'power', label: 'Power', unit: 'W'),
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

/// The keys each page is expected to request, pinned.
///
/// **This map is not read at runtime, and that is worth knowing before editing
/// it.** The actual request is derived: `historyKeysForPrefix` returns
/// `chartKeysForPrefix(prefix)`, i.e. the flat list of the groups declared
/// above. The direction of that derivation is the point — a chart can never plot
/// a key the request omitted, because the chart *is* where the request comes
/// from. This constant is the independent restatement of that list, and its only
/// reader is `chart_bounds_test.dart`.
///
/// So it is a pin, not a second source of truth, and it earns its place by being
/// *written down twice on purpose*: the test asserts the derived request equals
/// this literal, which catches a group gaining or losing a series without anyone
/// deciding that the request should change. A single derived list would make
/// that class of change invisible, because the test would compare the list to
/// itself.
///
/// **It was trimmed alongside the groups above, and the two must stay equal.**
/// Every key removed here is still fetched on the *live* path —
/// `ThingsBoardApi.pzemKeys` and `batteryKeys` keep all of them, and the metric
/// cards that display Energy, Frequency, Power Factor, State of Charge, Cycles
/// and both capacities read `latestValues`, not history. What was removed is the
/// plotting of them, not their existence.
const Map<String, List<String>> kHistoryKeysByPrefix = {
  'pv': ['voltage_dc', 'current_dc', 'power_dc'],
  'ac': ['voltage_ac', 'current_ac', 'power_ac'],
  'battery': ['voltage', 'current', 'power'],
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
