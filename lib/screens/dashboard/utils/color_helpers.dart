import 'package:flutter/material.dart';

import '../../../utils/solar_irradiance.dart';
import 'design_tokens.dart';

/// The categories of data this app shows.
///
/// **A category is what resolves a ThingsBoard key to something the app knows
/// how to plot, group and label — not a colour.** [categoryColor] returns the
/// one accent for all five, and that is deliberate: a categorical hue palette is
/// the same defect as the per-index hue rotation this file's predecessor was
/// reverted for, with a lookup table instead of a parameter. Both give the user
/// a colour they did not choose.
///
/// The enum earns its keep on the telemetry side. Its `keys` are the single
/// declaration of what belongs to a category, so a reading cannot appear in two
/// places under two different names, and `forKey` is the only path from a raw
/// ThingsBoard key to a category.
enum MetricCategory {
  /// Solar generation. `voltage_dc`, `current_dc`, `power_dc`, `energy_dc`.
  pv,

  /// House consumption. `voltage_ac`, `current_ac`, `power_ac`, `frequency_ac`,
  /// `energy_ac`, `pf_ac`.
  ac,

  /// Storage. `voltage`, `current`, `power`, `soc`, `cycles`,
  /// `remain_capacity_ah`, `full_capacity_ah`.
  battery,

  /// Greenhouse environment. `temp_dht`, `humidity_dht`, `temp_ds18b20`, `lux`,
  /// `tds_ppm`.
  environment,

  /// Water quality. `ph`, `suhu`, `turbidity_ntu`, `water_level_percent`.
  water;

  const MetricCategory();

  /// The telemetry keys this category owns.
  ///
  /// **One list, and it is the whole answer to "what colour is this reading".**
  /// Deriving the category from the key rather than from a widget's position is
  /// what stops the same number appearing in two colours in two places, which is
  /// the failure the old per-index rotation produced and then reverted.
  Iterable<String> get keys => switch (this) {
    MetricCategory.pv => const [
      'voltage_dc',
      'current_dc',
      'power_dc',
      'energy_dc',
    ],
    MetricCategory.ac => const [
      'voltage_ac',
      'current_ac',
      'power_ac',
      'frequency_ac',
      'energy_ac',
      'pf_ac',
    ],
    MetricCategory.battery => const [
      'voltage',
      'current',
      'power',
      'soc',
      'cycles',
      'remain_capacity_ah',
      'full_capacity_ah',
    ],
    MetricCategory.environment => const [
      'temp_dht',
      'humidity_dht',
      'temp_ds18b20',
      'lux',
      'tds_ppm',
    ],
    MetricCategory.water => const [
      'ph',
      'suhu',
      'turbidity_ntu',
      'water_level_percent',
    ],
  };

  /// The category a telemetry key belongs to, or `null` if it is not one of the
  /// app's readings — which is the answer for a derived value like a forecast.
  ///
  /// Built from [keys] rather than written out a second time, because two lists
  /// of the same 26 strings is the exact shape that produced the stale-surface
  /// bug this repo has already paid for once.
  static MetricCategory? forKey(String key) {
    for (final c in MetricCategory.values) {
      if (c.keys.contains(key)) return c;
    }
    return null;
  }
}

/// The colour a category is drawn in, which is the same for all five.
///
/// **There is one accent and it is [AppPalette.error], the cyan data accent.**
/// A category still exists, and still owns its telemetry keys: [MetricCategory]
/// is what resolves a ThingsBoard key to a thing the app knows how to plot, group
/// and label. Only the *colour* stopped being part of that.
///
/// A category is already carried by the page it is on, the tab, the label and the
/// row. Where the hue does mean "wrong", it is [statusBad] or [statusBadFill] and
/// it always ships with the word that says which.
Color categoryColor(MetricCategory category) => AppPalette.error;

/// The order a chart colours its series in when a group plots more than one.
///
/// **Four hues, fixed, and reused rather than extended.**
///
/// A single-series chart takes the accent. A multi-series group cannot: the PV
/// group plots four series that are all PV — voltage, current, power, energy —
/// and giving each of them the accent draws four lines in one colour.
///
/// **This list is the one place non-accent hues survive, and it is a data claim
/// rather than a decorative one.** A chart series is a line the user has to tell
/// apart from three other lines on a phone, so the order is fixed and reused. A
/// group longer than four wraps.
List<Color> get kChartSeriesOrder => [
  AppPalette.primary,
  AppPalette.secondary,
  AppPalette.chartViolet,
  AppPalette.chartCyan,
];

/// The category of a telemetry key, resolved once.
///
/// Convenience for the very common `categoryColor(MetricCategory.forKey(key)!)`
/// at a call site that already holds a key. Returns `null` for a derived value,
/// which a caller must handle — a forecast is not a sensor reading and has no
/// category hue of its own.
Color? categoryColorForKey(String key) {
  final c = MetricCategory.forKey(key);
  return c == null ? null : categoryColor(c);
}

// ── Status ─────────────────────────────────────────────────────────────────────

/// A severity ramp, ordered by hue: green, yellow, orange, red.
///
/// Four levels because the app has four: healthy, `stale_*` warnings, energy
/// alerts, and critical `offline_*` and battery breaches. Hue is monotonic
/// across the four, which is what makes it read as a scale rather than as four
/// unrelated colours, and the steps are 24° and 23° apart — too close to
/// separate as *categories*, which is fine, because these always ship with a
/// text label and the label carries the meaning.
///

/// Healthy. [AppPalette.success] — the **card** value.
///
/// **Use [statusOkOnPage] instead for anything drawn on the page.** The two getters
/// describe different grounds even when they resolve to the same number in a
/// single-ramp system.
Color get statusOk => AppPalette.success;

/// Healthy, as drawn **on the page** rather than on a card.
Color get statusOkOnPage => AppPalette.successOnPage;

/// A warning. [AppPalette.accent] — the **card** value.
///
/// **Use [statusWarnOnPage] on the page.** Same reason as [statusOk].
Color get statusWarn => AppPalette.accent;

/// A warning, as drawn **on the page**.
Color get statusWarnOnPage => AppPalette.warningOnPage;

/// An alert: serious, not yet a breach.
///
/// **The brief has two semantic hues and the app has four severities.**
/// Collapsing alert into `error` would have been the alternative and it loses
/// information the alarm history actually carries.
Color get statusAlert => AppPalette.statusAlert;

/// A breach, as a **fill**. [AppPalette.statusBad].
///
/// This value is for a solid block, a dot or a ring — somewhere the thing is a
/// shape, not a sentence. Anything the user reads goes through [statusBad].
Color get statusBadFill => AppPalette.statusBad;

/// A breach, as **ink**. [AppPalette.statusBad].
///
/// A token and not a literal, so a palette change moves it. WattVision's red
/// `#FF453A` clears AA on the dark card surfaces.
Color get statusBad => AppPalette.statusBad;

/// A breach, as **ink on the page** rather than on a card.
Color get statusBadOnPage => AppPalette.statusBadOnPage;

/// Alarm severity, for the alarm history list.
///
/// Both resolve to the pinned status values rather than carrying their own, so
/// they cannot drift from the ramp.
Color alarmCritical() => statusBad;

Color alarmWarning() => statusWarn;

/// The colour a sky condition is drawn in.
///
/// **The accent for daylight, a neutral for night.** The card's glyph and its
/// brightness bar are [AppPalette.error], so a third hue here would make one card
/// read as three colours. Clear, partly cloudy and overcast are three answers to
/// "how bright is it", and the card already answers that with a lux figure and a
/// wattage next to the label — painting them three different hues would assert a
/// severity that is not there. **Night takes [AppSurfaces.onSurfaceVariant] rather
/// than a hue**, so the one case where the reading genuinely means something
/// different is the one that stops shouting.
Color skyConditionColor(SkyCondition condition) => switch (condition) {
  SkyCondition.clear => AppPalette.error,
  SkyCondition.partlyCloudy => AppPalette.error,
  SkyCondition.overcast => AppPalette.error,
  SkyCondition.night => AppSurfaces.onSurfaceVariant,
};

/// The colour for secondary text: units, captions, timestamps.
///
/// **A getter rather than a `final`.** As a top-level `final` it captured
/// whichever surface ramp was active when the library loaded and then never
/// moved. `test/theme_palette_contrast_test.dart` measures it against the live
/// ramp now.
Color get faintColor => AppSurfaces.onSurfaceVariant;
