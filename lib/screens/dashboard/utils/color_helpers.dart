import 'package:flutter/material.dart';

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
    MetricCategory.pv => const ['voltage_dc', 'current_dc', 'power_dc', 'energy_dc'],
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
    MetricCategory.water => const ['ph', 'suhu', 'turbidity_ntu', 'water_level_percent'],
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
/// | PV / solar    | `accent`    | `#FCE570` | 11.76:1       | 50.1°     |
/// | AC / load     | `secondary` | `#8E99F3` | 5.67:1        | 233.5°    |
/// | battery       | `primary`   | `#F7A5A5` | 7.72:1        | 0.0°      |
/// | environment   | `chartViolet` | `#C084FC` | 5.64:1      | 270.0°    |
/// | water         | `chartCoral` | `#FF8577` | 6.29:1       | 6.2°      |
///
/// "Worst surface" is [#AppSurfaces.surfaceAlt], the lightest of the three, so a
/// figure that clears AA there clears it everywhere. Every one clears AA for
/// normal text with at least 1.14 to spare.
///
/// **Why solar is yellow and not coral.** Butter yellow is the sun. That is a
/// genuine reason rather than a rhyme, and it happens to also be the widest
/// separation available: 176.7° from `secondary` and 140.1° from `chartViolet`.
/// The Power tab's three sub-tabs are the only place three category hues share a
/// screen, and no two of them are under 50° apart.
///
/// ### Why `success` is not a category
///
/// It is the one remaining free hue and it is refused on purpose. Green in this
/// app means "a problem is absent" — it is `statusOk`, it is the CCTV `LIVE`
/// dot, it is the healthy end of a verdict. A category whose page identity was
/// green would make green mean both "this page" and "nothing is wrong", and the
/// old system already learned that lesson the hard way: a permanent green
/// "semua normal" badge asserted a condition that is boring when true and
/// permanently occupied the space where a real warning needed to go.
///
/// ### The collision this palette cannot avoid
///
/// `primary` and `error` are **the same hue** — both 0.0° — and `chartCoral` is
/// 6.2° away. So two of the five categories sit in the same hue family as the
/// breach colour. This is a property of the brief's palette, not a choice made
/// here, and it cannot be fixed by reassigning: there are only six non-semantic
/// hues and five categories need one each.
///
/// What keeps it legible is that the two never take the same *role*. A category
/// hue is a **fill** — an icon tile, a progress fill, a chart line, a badge
/// background — while `error` is **ink only**: small text, a hairline, a dot.
/// They also separate on luminance: the closest category fill is 7.34:1 and the
/// breach ink is 5.74:1.
///
/// **This is a structural mitigation and it is the one failure mode that
/// `flutter analyze` cannot see and no test can reach.** It needs a device. The
/// specific case to look at is the Battery page, which is the page most likely to
/// be showing its own breach: `low_soc` and `offline_battery` are both
/// `error`-hued ink sitting on a page whose identity is `primary`.
Color categoryColor(MetricCategory category) => switch (category) {
  MetricCategory.pv => AppPalette.accent,
  MetricCategory.ac => AppPalette.secondary,
  MetricCategory.battery => AppPalette.primary,
  MetricCategory.environment => AppPalette.chartViolet,
  MetricCategory.water => AppPalette.chartCoral,
};

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

/// Healthy. [AppPalette.success], measured 8.55:1 on [AppSurfaces.surfaceAlt].
const Color statusOk = AppPalette.success;

/// A warning. [AppPalette.accent] — butter is the only yellow in the palette and
/// a warning is the only thing in the app that should be yellow. 11.76:1.
///
/// **This is also the focus-ring and text-button hue**, so yellow now means
/// "attend to this" in two registers: an affordance and a condition. That is the
/// brief's own reuse pattern — it says `success` and `error` may also play
/// categorical roles — applied to the only severity left without a hue.
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
/// 9.02:1 on `primary`, 6.63 on `secondary`, 13.74 on `accent`, 9.99 on
/// `success`, 6.59 on `chartViolet`, 7.35 on `chartCoral` and 4.62 on `error` —
/// so dark ink is correct on every one, and the tightest is `error`.
///
/// Picked by luminance rather than hard-coded per call site, so a future palette
/// entry is handled without a second rule in a different file, which is how the
/// previous version's two independent ink rules drifted apart.
Color onPrimaryInk(Color fill) =>
    fill.computeLuminance() > 0.18 ? AppPalette.onHue : Colors.white;
