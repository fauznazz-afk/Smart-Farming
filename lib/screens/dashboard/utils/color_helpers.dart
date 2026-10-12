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

/// The colour a category is drawn in, which is now the same for all five.
///
/// **There is one accent and it is [AppPalette.error].** This function used to
/// hand out lime for solar, blue for AC, violet for battery and cyan for water,
/// and every one of those was a hue the user did not choose. The rule that
/// killed per-index rotation in the previous system — *a colour the user did not
/// choose is a colour they cannot predict* — was never actually about rotation;
/// it was about hue, and a category palette is that same defect with a lookup
/// table instead of a parameter. So the categorical mapping is collapsed.
///
/// A category still exists, and still owns its telemetry keys: [MetricCategory]
/// is what resolves a ThingsBoard key to a thing the app knows how to plot, group
/// and label. Only the *colour* stopped being part of that.
///
/// ### What was given up, and what replaces it
///
/// The old doc argued that PV, AC and battery sit far enough apart in hue to
/// read as three series. They no longer do, because they are one colour. Nothing
/// needed them apart: those three are never three lines in one chart — the PV
/// group's four series go through [kChartSeriesOrder] precisely because three
/// lightness steps of one hue are indistinguishable on a phone — and the
/// category is already carried by the page it is on, the tab, the label and the
/// row.
///
/// ### Why this is not a status colour in disguise
///
/// Red here means *this is the accent*, not *this is wrong*. It draws the page
/// heading, the meter fill and the avatar ring on a day when every reading is
/// nominal. Where red *does* mean wrong, it is [statusBad] or [statusBadFill]
/// and it always ships with the word that says which. `test/color_helpers_test.dart`
/// pins that the accent is not equal to any of the ramp's four steps.
Color categoryColor(MetricCategory category) => AppPalette.error;

/// The order a chart colours its series in when a group plots more than one.
///
/// **Four hues, fixed, and reused rather than extended.**
///
/// A single-series chart takes the accent, because with the categorical palette
/// collapsed there is nothing else for it to be. A multi-series group cannot: the
/// PV group plots four series that are all PV — voltage, current, power, energy —
/// and giving each of them the accent draws four lines in one colour. That is
/// the "chart whose shape is an artefact of the units" failure the old soft-UI
/// system documented at length.
///
/// **This list is the one place non-red hues survive the conversion, and it is a
/// data claim rather than a decorative one.** A chart series is a line the user
/// has to tell apart from three other lines on a phone; a chart group with more
/// than one series cannot be drawn in one hue, and dash patterns to compensate
/// read as broken lines. So the order is untouched — four hues, fixed, reused and
/// never extended. A group longer than four wraps, and adding a hue to fit a
/// longer group would be the mistake the per-index rotation made in the other
/// direction.
List<Color> get kChartSeriesOrder => [
  AppPalette.primary,
  AppPalette.secondary,
  AppPalette.chartViolet,
  AppPalette.chartCyan,
];

/// The colour one series of a chart group is drawn in.
///
/// [index] is the series' position in the group and [count] the group's length.
/// With one series the category hue is used; with more than one, the fixed
/// order above.
Color chartSeriesColor(int index, {required int count, String? key}) {
  if (count <= 1) {
    return categoryColorForKey(key ?? '') ?? AppPalette.error;
  }
  return kChartSeriesOrder[index % kChartSeriesOrder.length];
}

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

/// Healthy. [AppPalette.success], 8.6:1 on [AppSurfaces.surfaceAlt].
///
/// **The one hue in this file that is not in the brief, and it is here because
/// the app needs a colour that means "nothing is wrong" and the brief has no
/// green.** A status that clears AA on every surface is the constraint; anything
/// darker moves the wrong way on a dark ramp.
Color get statusOk => AppPalette.success;

/// A warning. [AppPalette.accent] — amber is the brief's own caution colour and
/// the only one in the palette that reads that way. 7.4:1.
Color get statusWarn => AppPalette.accent;

/// An alert: serious, not yet a breach. `#FB923C`, measured 6.58:1 on
/// [AppSurfaces.surfaceAlt].
///
/// **The one colour in this file that is not in the brief's palette, and it is
/// here because the brief has two semantic hues and the app has four
/// severities.** Collapsing alert into `error` would have been the alternative
/// and it loses information the alarm history actually carries. If a future
/// palette revision supplies an amber-orange, this is the value to replace —
/// and the replacement has to clear 4.5:1 on `surfaceAlt`, which is the
/// constraint that decides it.
/// An alert: serious, not yet a breach. See [AppPalette.statusAlert] for why the
/// brief's palette has no fourth severity and this one does.
///
/// It used to be its own literal `#FB923C`, which compiled and looked fine until
/// the app grew a light palette: a literal cannot swap, so it stayed
/// amber-orange on a white page and measured **1.7:1**. It resolves to the
/// pinned value now, and `theme_palette_contrast_test.dart` measures both ramps.
Color get statusAlert => AppPalette.statusAlert;

/// A breach, as a **fill**. [AppPalette.error], 3.96:1 on
/// [AppSurfaces.surfaceAlt].
///
/// **Below AA for text, which is why [statusBad] exists.** This value is for a
/// solid block, a dot or a ring — somewhere the thing is a shape, not a
/// sentence. Anything the user reads goes through [statusBad].
Color get statusBadFill => AppPalette.error;

/// A breach, as **ink**. `#FF5C5C` at 4.92:1 on [AppSurfaces.surfaceAlt].
///
/// **Derived by scaling every channel of `#EF4444` by 1.35, and the direction is
/// the whole point.** The obvious fix for a colour that fails contrast on a dark
/// surface is to darken it, and that is exactly backwards: it takes the red
/// *further* from white. Measured, on `surfaceAlt`: 1.00× gives 3.96:1, 0.92×
/// gives 3.42:1, 0.88× gives 3.16:1. Going up, 1.15× gives 4.58:1 and 1.35×
/// gives **4.92:1**.
///
/// Scaled per channel rather than stepped in HSL, so hue is preserved exactly —
/// measured 0.00° before and after. The old file recorded this lesson already:
/// stepping HSL lightness on a saturated colour moved `faintColor` from 150.00°
/// to 146.67° at a 0.6% darkening, and a caption that shifts hue when you
/// change it reads warm beside a green theme.
/// A breach, as **ink**. See [AppPalette.statusBad] for the `#EF4444` scaling
/// measurement that chose the value.
///
/// It was its own literal `#FF5C5C` for the same reason `statusAlert` was, and
/// it failed the same way: a literal cannot swap, so the red stayed light on a
/// white page at 2.3:1.
Color get statusBad => AppPalette.statusBad;

/// Alarm severity, for the alarm history list.
///
/// These were a second, unpinned red and amber living one file away from the
/// status colours, and both light values failed WCAG AA as the 11 to 13dp text
/// they are used at. Duplicating the palette is what let the two drift, so these
/// resolve to the pinned values instead of carrying their own.
Color alarmCritical() => statusBad;

Color alarmWarning() => statusWarn;

/// The colour a sky condition is drawn in.
///
/// **The accent for daylight, a neutral for night.** The card's glyph and its
/// brightness bar are [AppPalette.error], so a third hue here made one card
/// read as three colours — the label, the icon and the bar beside each other
/// each making their own statement. That was true of the amber it replaced too,
/// and of the blue night carried before that: the label was never the thing
/// carrying the day/night distinction on this card.
///
/// Clear, partly cloudy and overcast are three answers to "how bright is it",
/// and the card already answers that with a lux figure and a wattage next to the
/// label — painting them three different hues would assert a severity that is
/// not there. **Night takes [AppSurfaces.onSurfaceVariant] rather than a hue**,
/// so the one case where the reading genuinely means something different is the
/// one that stops shouting, which is the same trade every other label on the card
/// makes.
Color skyConditionColor(SkyCondition condition) => switch (condition) {
  SkyCondition.clear => AppPalette.error,
  SkyCondition.partlyCloudy => AppPalette.error,
  SkyCondition.overcast => AppPalette.error,
  SkyCondition.night => AppSurfaces.onSurfaceVariant,
};

/// The colour for secondary text: units, captions, timestamps.
///
/// This is [AppSurfaces.onSurfaceVariant] and it is no longer a function. The
/// version this replaces had a light/dark pair whose light value was re-measured
/// twice against a page colour that had itself been restyled once, and the test
/// that should have caught it measured against a hand-written surface list that
/// had gone stale in the opposite direction.
///
/// **A getter rather than a `final`, because it was the one that went quiet.**
/// As a top-level `final` it captured whichever surface ramp was active when
/// the library loaded — dark — and then never moved, so every caption drawn in
/// it was white no matter what the user had picked. `test/theme_palette_
/// contrast_test.dart` measures it against both ramps now, and the failure it
/// caught was 1.11:1: white on white.
Color get faintColor => AppSurfaces.onSurfaceVariant;

/// The ink to put **on top of** a saturated categorical fill.
///
/// Measured across the whole palette rather than assumed: [#AppPalette.onHue] is
/// 11.4:1 on `primary`, 4.6 on `secondary`, 7.4 on `accent`, 9.1 on `success`,
/// 4.9 on `chartViolet`, 8.0 on `chartCyan` and 4.6 on `error` — so dark ink is
/// correct on every one, and the two tightest are `secondary` and `error`.
///
/// Picked by luminance rather than hard-coded per call site, so a future palette
/// entry is handled without a second rule in a different file, which is how the
/// previous version's two independent ink rules drifted apart.
Color onPrimaryInk(Color fill) =>
    fill.computeLuminance() > 0.18 ? AppPalette.onHue : Colors.white;
