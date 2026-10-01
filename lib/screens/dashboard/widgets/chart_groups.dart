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
/// `temp_dht` and `temp_ds18b20` share an axis because they are both degrees
/// Celsius, which is a real comparison. `lux` and `ppm` do not share an axis with
/// anything, and putting them on one would produce a chart whose shape is an
/// artefact of the units rather than of the greenhouse. So each becomes its own
/// group, and that is a property of the data rather than a layout decision.
///
/// **The one exception, and it is the weakest claim in this file.** Voltage,
/// current and power share an axis because they are "one electrical system in
/// comparable magnitudes". Measured on the test instance on 2 October 2026, on
/// the AC page: 220 V, 0.11 A and 18.5 W. That is three orders of magnitude, and
/// the resulting chart drew all three series as horizontal lines — 220, 18 and 0
/// on a 0–300 axis — so the shape of every curve on it was a property of the
/// units rather than of the grid. On PV only the power curve carries information;
/// voltage and current are flat because the power scale is about 100× their size.
///
/// Splitting the electrical pages into one group per quantity was implemented and
/// measured, and is **not** in this file. It throws away the
/// voltage/current/power relationship that an electrician reads an inverter for,
/// it costs three times the vertical space on the three most-used pages, and each
/// resulting single-series group loses the red/green/blue triad and takes the
/// user's accent instead. None of that can be judged from a screenshot, and at the
/// time it was written no device was reachable.
///
/// So: the grouping below is a deliberate choice with a **false justification**,
/// and the honest position is that the justification is the defect, not the
/// grouping. Anyone revisiting this should decide it in front of the user rather
/// than on the strength of a comment. The history request is unaffected either way,
/// because [chartKeysForPrefix] flattens the groups — so changing this list cannot
/// desynchronise what is fetched from what is plotted, and the change is
/// reversible in one list.
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

/// The card height for a chart that draws one series on the greenhouse or the
/// fish tank.
///
/// 400 is the default everywhere else and it is sized for a three-series card
/// with a three-line statistics block. A one-series card on those pages carries a
/// legend of one name and a single line of statistics instead, so the same
/// 400dp is mostly empty plot. The arithmetic behind the reduction is on
/// [ChartGroup.height].
const double _compactHeight = 260;

/// The two-sensor greenhouse temperature card, which keeps the multi-series
/// statistics block and so needs more of the plot back.
///
/// It is the one chart on those pages that genuinely needs its height: the whole
/// point of putting the air and panel sensors on one axis is seeing the gap
/// between them, and on the test device that gap is 45.88 against 62.53 degrees.
/// A flat band 140dp tall would still show it, but 120 would start to cost.
const double _compactTwoSeriesHeight = 300;

/// A single chart: a title and the series that share its Y axis.
class ChartGroup {  const ChartGroup(
    this.title,
    this.series, {
    this.zeroAnchored = true,
    this.height,
  });

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

  /// This card's height, or null for the default.
  ///
  /// **Set on the greenhouse and the fish tank, at the user's request: those
  /// pages had become a long scroll.** Four charts on Hydroponics and three on
  /// Fish, each a fixed 400dp card, put the fourth chart about 1,600dp down a
  /// page — and on a phone that is a scroll to remember, on the two pages whose
  /// whole point is a glance at a few numbers.
  ///
  /// The default is right for the Power page and wrong here, and the reason is
  /// how much each card is actually saying. A PV/AC/Battery card carries a
  /// three-series legend, a three-line statistics block per series, and a plot
  /// that has to be tall enough to show where a 383 W spike sits between two
  /// near-zero plateaus. A greenhouse card carries **one** series, a legend of
  /// one name, and a single line of statistics. It is the same number of pixels
  /// saying a third as much.
  ///
  /// 260 is not arbitrary: it is the default minus the height the single-series
  /// statistics line does not need. The multi-series block is three lines of
  /// 11sp with 2dp between them, roughly 60dp, and the plot above it still has
  /// enough vertical room for the shape to read — which matters most for the
  /// two-sensor temperature card, the one chart on those pages that genuinely
  /// needs its height.
  ///
  /// Declared here for the same reason as [zeroAnchored]: it is a property of
  /// what the page charts, and the alternative was a page-index conditional in
  /// the screen, which is the shape this file exists to prevent.
  final double? height;

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
    ], zeroAnchored: false, height: _compactHeight),
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
///
/// This is what the history request asks for. It is derived from
/// [chartGroupsForPrefix] rather than written separately, because the two were
/// separate lists in the previous version and could not be checked against each
/// other — which is how a page ended up able to request keys nothing plotted.
List<String> chartKeysForPrefix(String prefix) => [
  for (final group in chartGroupsForPrefix(prefix)) ...group.keys,
];

/// The keys each page requests, pinned.
///
/// Derived from [chartGroupsForPrefix] in the app and *listed* here, which looks
/// like exactly the kind of copy this file exists to prevent — and normally it
/// would be. The difference is that this list is a change detector, not a second
/// source: nothing reads it, and it exists so that regrouping a page's charts
/// cannot silently change what is fetched from ThingsBoard.
///
/// That is not hypothetical. Splitting the electrical pages into one group per
/// quantity is a live proposal (see the note on the grouping rule), and anyone
/// attempting it will find the flattened key list comes out byte-for-byte
/// identical — which is the property worth proving, because it is what makes the
/// experiment safe to try and trivial to undo.
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
