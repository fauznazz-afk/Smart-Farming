import 'package:flutter/material.dart';

/// What a chart plots, declared once and used by the request builder, the
/// legend, the statistics row and the axis.
///
/// This exists because the chart used to hard-code three series by index —
/// `const suffixes = ['voltage', 'current', 'power']` — and every other thing
/// about a page's telemetry was derived from that one list. Greenhouse pH and
/// fish turbidity could not be charted at all, not because the data is missing
/// but because there was nowhere to say "this page has a pH chart with one
/// series in it".
///
/// The rule that decides how a page's readings are grouped is the **unit**.
/// Voltage, current and power share an axis because they are one electrical
/// system in comparable magnitudes. `temp_dht` and `temp_ds18b20` share an axis
/// because they are both degrees Celsius, which is a real comparison. `lux` and
/// `ppm` do not share an axis with anything, and putting them on one would
/// produce a chart whose shape is an artefact of the units rather than of the
/// greenhouse. So each becomes its own group, and that is a property of the data
/// rather than a layout decision.
class ChartSeriesSpec {
  const ChartSeriesSpec({
    required this.key,
    required this.label,
    required this.unit,
    this.light,
    this.dark,
  });

  /// The telemetry key exactly as `ThingsBoardApi.deviceKeysById` spells it, and
  /// as the history response stores it. Written out rather than composed from a
  /// label or an index, because deriving it is what let `suhu` and
  /// `turbidity_ntu` be unplottable in the first place.
  final String key;

  /// English, like every other label in the app.
  final String label;

  /// The unit, appended to every value and shown in the legend. Empty for pH,
  /// which is dimensionless.
  final String unit;

  /// The series colour per mode, or null to use the user's accent.
  ///
  /// Null means **this is the only series in its group**, and that is a real
  /// signal rather than a default. The fixed red/green/blue triad exists so
  /// three lines on one plot can be told apart, which is the exception
  /// `AGENTS.md` documents. A single-line chart has nothing to distinguish, and
  /// painting it red would give the same colour two meanings in the same app:
  /// "this is the voltage series" on one page and "something is wrong" on
  /// another, in an app whose own rule is that status colour means a condition
  /// rather than an identity.
  final int? light;
  final int? dark;

  Color color(bool isDark, Color accent) {
    if (light == null || dark == null) return accent;
    return Color(isDark ? dark! : light!);
  }
}

/// A single chart: a title and the series that share its Y axis.
class ChartGroup {
  const ChartGroup(this.title, this.series, {this.zeroAnchored = true});

  final String title;
  final List<ChartSeriesSpec> series;

  /// Whether the bottom of the Y axis is pinned to zero.
  ///
  /// True is correct for a **magnitude** — lux, watts, amperes, per cent, ppm —
  /// where zero is a real condition and the distance from zero *is* the reading.
  /// A lux series that never drops below 900 has not been near zero, and an axis
  /// from 0 makes that visible.
  ///
  /// False is correct for a **bounded dimensionless index**, where zero is
  /// arbitrary rather than meaningful. pH runs 0-14, and the fish device's data
  /// lives between 6.37 and 7.75, so a zero baseline squeezed the whole drop --
  /// which is the news on that page -- into roughly the top fifth of the plot.
  ///
  /// Declared here rather than derived inside `chart_data.dart` because this file
  /// is the one place that says what a page charts. A hardcoded key list over in
  /// the bounds code is the exact shape of the bug this file was written to
  /// kill: a key in one place and a label in another, agreeing only by
  /// coincidence of ordering.
  final bool zeroAnchored;

  /// Every telemetry key this group needs, flattened for the history request.
  List<String> get keys => [for (final s in series) s.key];
}

/// The red / green / blue triad, reused in the same order.
///
/// Not a palette. `AGENTS.md` records that a 40-degree hue rotation per index
/// was implemented so the PV, AC and battery pages could be told apart, and was
/// reverted because a colour the user did not choose is a colour they cannot
/// predict. This is the opposite decision and the reason for it: these are
/// series *identities* on a plot, and the plot is the one place in the app where
/// a fixed identity is worth more than theme consistency. Adding more hues
/// here would be the same mistake in the other direction, so the triad is
/// reused rather than extended.
const List<({int light, int dark})> kSeriesTriad = [
  (light: 0xFFE53935, dark: 0xFFFF5252),
  (light: 0xFF43A047, dark: 0xFF69F0AE),
  (light: 0xFF1E88E5, dark: 0xFF448AFF),
];

ChartSeriesSpec _triad(int index, String key, String label, String unit) {
  final c = kSeriesTriad[index];
  return ChartSeriesSpec(
    key: key,
    label: label,
    unit: unit,
    light: c.light,
    dark: c.dark,
  );
}

/// Every chart a page prefix can draw, in display order.
///
/// The electrical pages keep the single three-series group they have always had,
/// spelled out with the same keys and the same colours, so nothing about PV, AC
/// or Battery changes.
List<ChartGroup> chartGroupsForPrefix(String prefix) => switch (prefix) {
  'pv' => [
    ChartGroup('PV', [
      _triad(0, 'voltage_dc', 'Voltage', 'V'),
      _triad(1, 'current_dc', 'Current', 'A'),
      _triad(2, 'power_dc', 'Power', 'W'),
    ]),
  ],
  'ac' => [
    ChartGroup('AC', [
      _triad(0, 'voltage_ac', 'Voltage', 'V'),
      _triad(1, 'current_ac', 'Current', 'A'),
      _triad(2, 'power_ac', 'Power', 'W'),
    ]),
  ],
  'battery' => [
    ChartGroup('Battery', [
      _triad(0, 'voltage', 'Voltage', 'V'),
      _triad(1, 'current', 'Current', 'A'),
      _triad(2, 'power', 'Power', 'W'),
    ]),
  ],

  // The greenhouse. `temp_dht` is the air sensor and `temp_ds18b20` is the panel
  // sensor, and plotting them together is the whole point: the gap between them
  // is the panel running hotter than the air, which is the reading a grower
  // actually wants and which two separate charts would hide.
  //
  // The remaining three are their own group each because their units are their
  // own: percent, lux and parts per million do not share an axis with anything,
  // and lux on a shared axis would flatten everything else to a flat line.
  'env' => const [
    ChartGroup('Temperature', [
      ChartSeriesSpec(
        key: 'temp_dht',
        label: 'Air',
        unit: '°C',
        light: 0xFFE53935,
        dark: 0xFFFF5252,
      ),
      ChartSeriesSpec(
        key: 'temp_ds18b20',
        label: 'Panel',
        unit: '°C',
        light: 0xFF43A047,
        dark: 0xFF69F0AE,
      ),
    ]),
    ChartGroup('Humidity', [
      ChartSeriesSpec(key: 'humidity_dht', label: 'Humidity', unit: '%'),
    ]),
    ChartGroup('Light', [
      ChartSeriesSpec(key: 'lux', label: 'Light', unit: 'lx'),
    ]),
    ChartGroup('TDS', [
      ChartSeriesSpec(key: 'tds_ppm', label: 'TDS', unit: 'ppm'),
    ]),
  ],

  // The fish tank. Three charts rather than four: `water_level_percent` is
  // un-monitored everywhere else in the app, with no configured limit and no
  // `metric`, and a chart here would present it as a first-class trend it has
  // never been treated as.
  // The pH group is the one that asks not to be anchored at zero: 0-14 is an
  // arbitrary scale, not a magnitude, and the readings sit at 6.37-7.75.
  //
  // Turbidity is deliberately left zero-anchored, and that is a decision rather
  // than an oversight. `settings_validation_test.dart` records the reason: the
  // sensor on the test device reads 2396 NTU, which is why its `maxAllowed` is
  // `null` and uncapped. NTU is a magnitude with a real zero -- perfectly clear
  // water reads 0 -- and the readings are hundreds or thousands of units away
  // from it, so zero costs this chart nothing and is the honest baseline. pH's
  // zero is a number on a ruler; turbidity's is a state of the water.
  'fish' => const [
    ChartGroup('pH', [
      ChartSeriesSpec(key: 'ph', label: 'pH', unit: ''),
    ], zeroAnchored: false),
    ChartGroup('Temperature', [
      ChartSeriesSpec(key: 'suhu', label: 'Water', unit: '°C'),
    ]),
    ChartGroup('Turbidity', [
      ChartSeriesSpec(key: 'turbidity_ntu', label: 'Turbidity', unit: 'NTU'),
    ]),
  ],

  _ => const [],
};

/// Every telemetry key a prefix's charts need, flattened.
///
/// This is what the history request asks for. It is derived from
/// [chartGroupsForPrefix] rather than written separately, because the two were
/// separate lists in the previous version and could not be checked against each
/// other — which is how a page ended up able to request keys nothing plotted.
List<String> chartKeysForPrefix(String prefix) => [
  for (final group in chartGroupsForPrefix(prefix)) ...group.keys,
];

/// The page title for a prefix, or null when the prefix draws no chart.
String? chartPageTitle(String prefix) => switch (prefix) {
  'pv' => 'PV',
  'ac' => 'AC',
  'battery' => 'Battery',
  'env' => 'Environment',
  'fish' => 'Fish tank',
  _ => null,
};
