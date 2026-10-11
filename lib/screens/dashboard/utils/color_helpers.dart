import 'package:flutter/material.dart';

import '../../../utils/solar_irradiance.dart';
import 'design_tokens.dart';

/// The categories of data this app shows, and the hue each one owns.
///
/// **This replaces an accent seed, and that is the single biggest reversal in
/// the app.** The previous system let the user pick one accent from four
/// swatches, and `metricColor` accepted an `index` that it *deliberately
/// ignored* — there was a test that failed loudly if it ever started using it,
/// because "a colour the user did not choose is a colour they cannot predict".
/// That reasoning was sound for a single-accent app. It does not survive a
/// design whose entire premise is that a category of data owns a hue and every
/// appearance of that category reuses it. The rule has been inverted on
/// purpose, and `test/color_helpers_test.dart` has been rewritten to assert the
/// inversion rather than forbid it.
///
/// What did **not** reverse is the other half of that rule, which is the one
/// that actually mattered: a hue is never assigned to something that has no
/// category, and a hue never means two things. See [categoryColor] for the
/// collision analysis and the two places where the palette made that hard.
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

/// The hue a category owns.
///
/// **Five hues for five categories, and the palette has seven entries because
/// two of them are semantic.** [AppPalette.success] and [AppPalette.error] are
/// not available to a category, which is a deliberate refusal to use colours
/// that are available — see below for why `success` in particular had to stay
/// out.
///
/// | category      | hue         | hex       | worst surface | hue angle |
/// |---------------|-------------|-----------|---------------|-----------|
/// | PV / solar    | `primary`   | `#C6FF00` | 11.4:1        | 71.8°     |
/// | AC / load     | `secondary` | `#4A9EFF` | 4.6:1         | 214.0°    |
/// | battery       | `chartViolet` | `#C084FC` | 4.8:1      | 280.0°    |
/// | environment   | `error`     | `#FF6B6B` | 4.5:1         | 0.0°      |
/// | water         | `chartCyan` | `#22D3EE` | 7.0:1         | 187.0°    |
///
/// "Worst surface" is [#AppSurfaces.surfaceAlt], the lightest of the three a
/// caption can land on, so a figure that clears AA there clears it everywhere.
/// The two near the line — `secondary` at 4.6:1 and `error` at 4.5:1 — are the
/// brief's own values and are the reason the palette was measured rather than
/// assumed.
///
/// **Why solar is lime.** The brief reserves lime for the primary CTA, the
/// active tab and the "peak bar in charts", and PV power is the peak data this
/// app charts. Sharing the brand hue with the hero metric is the brief's own
/// reuse pattern, and it keeps lime to the one thing on the dashboard that is
/// actually the peak. It is used as an icon, a border and a series line here —
/// never as a fill — so the rule that lime is never a card background holds.
///
/// ### The three that must separate
///
/// PV, AC and battery are the only categories that share a screen, and they sit
/// 142°, 208° and 66° apart. `test/color_helpers_test.dart` asserts a 50° floor
/// on each pair, which is the property that makes three hues readable as three
/// series rather than as three shades of one thing.
///
/// ### Why `success` is not a category
///
/// Green means "a problem is absent" in this app: it is `statusOk`, the CCTV
/// `LIVE` dot, the healthy end of a verdict. A category whose page identity was
/// green would make green mean both "this page" and "nothing is wrong", and the
/// old system already learned that lesson the hard way with a permanent green
/// "semua normal" badge.
///
/// ### The collision this palette cannot avoid
///
/// `environment` and the breach fill are the same hue, and `statusBad` ink is
/// 0.4° from both. This is a property of a palette with one red, and it cannot
/// be fixed by reassigning: the categorical set is four and the app has five
/// categories.
///
/// What keeps it legible is that the two never take the same *role*. A category
/// hue is an icon, a border, a chart line or a badge wash, while a breach is
/// always accompanied by its text — "1 out of range", the alarm banner — and the
/// label carries the meaning. **This is a structural mitigation and it is the
/// one failure mode `flutter analyze` cannot see and no test can reach.** It
/// needs a device: the specific case is the Environment page, which is the page
/// most likely to be showing its own breach.
Color categoryColor(MetricCategory category) => switch (category) {
  MetricCategory.pv => AppPalette.primary,
  MetricCategory.ac => AppPalette.secondary,
  MetricCategory.battery => AppPalette.chartViolet,
  MetricCategory.environment => AppPalette.error,
  MetricCategory.water => AppPalette.chartCyan,
};

/// The order a chart colours its series in when a group plots more than one.
///
/// **Four hues, fixed, and reused rather than extended.**
///
/// A single-series chart takes its category's hue, so a chart is colour-coded
/// the way its card and its page are. A multi-series group cannot: the PV group
/// plots four series that are all PV — voltage, current, power, energy — and
/// giving each of them the category hue draws four lines in one colour. That is
/// the "chart whose shape is an artefact of the units" failure the old soft-UI
/// system documented at length, reproduced by a palette with five category hues
/// and a group with four series in one category.
///
/// The previous system used a fixed red/green/blue triad for this and pinned it
/// with a test; this is the same idea on the current palette, in the brief's own
/// precedence — brand first, then the categorical hues in the order
/// [AppPalette] lists them. Four, not five: a group longer than four wraps, and
/// adding a hue to fit a longer group is exactly the mistake the per-index
/// rotation made in the other direction.
const List<Color> kChartSeriesOrder = [
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
  if (count <= 1) return categoryColorForKey(key ?? '') ?? AppPalette.primary;
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
const Color statusOk = AppPalette.success;

/// A warning. [AppPalette.accent] — amber is the brief's own caution colour and
/// the only one in the palette that reads that way. 7.4:1.
const Color statusWarn = AppPalette.accent;

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
const Color statusAlert = Color(0xFFFB923C);

/// A breach, as a **fill**. [AppPalette.error], 3.96:1 on
/// [AppSurfaces.surfaceAlt].
///
/// **Below AA for text, which is why [statusBad] exists.** This value is for a
/// solid block, a dot or a ring — somewhere the thing is a shape, not a
/// sentence. Anything the user reads goes through [statusBad].
const Color statusBadFill = AppPalette.error;

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
const Color statusBad = Color(0xFFFF5C5C);

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
/// **The status ramp, and that is deliberate.** A sky condition is a judgement
/// about the day, so it takes the app's quality scale rather than a categorical
/// hue: clear is the "nothing is wrong" colour and overcast is the "look at
/// this" one. Lime is deliberately *not* the clear-sky colour — lime is reserved
/// for the sun itself, and the figure on the card *is* the sun, so the label
/// stays neutral and the lime lives in the number.
///
/// Clear and mostly clear share a colour, and partly cloudy and overcast share
/// one, because the scale has four steps and this ramp has three hues; the
/// label beside it carries the distinction.
Color skyConditionColor(SkyCondition condition) => switch (condition) {
  SkyCondition.clear => AppPalette.secondary,
  SkyCondition.mostlyClear => AppPalette.secondary,
  SkyCondition.partlyCloudy => AppPalette.accent,
  SkyCondition.overcast => AppPalette.accent,
  SkyCondition.heavilyOvercast => AppPalette.error,
};

/// The colour for secondary text: units, captions, timestamps.
///
/// This is [#AppSurfaces.onSurfaceVariant] and it is no longer a function. The
/// version this replaces had a light/dark pair whose light value was re-measured
/// twice against a page colour that had itself been restyled once, and the test
/// that should have caught it measured against a hand-written surface list that
/// had gone stale in the opposite direction. With one surface ramp there is one
/// value and it is the same constant the surfaces are measured against.
///
/// 7.47:1 on the page, 6.78:1 on a card, 5.81:1 on a well.
const Color faintColor = AppSurfaces.onSurfaceVariant;

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
