# [Unreleased]

---

# [1.9.1] - 2026-10-11

The sky card moves to where its question is asked, shows lux instead of W/m², and
Settings gets tighter. Also fixes a brightness bar that drew full at every
reading above 1.8% of a sun.

### Changed

- **`SolarConditionCard` is on Overview, not Hydroponics.** It used to sit on
  Hydroponics because that is where the lux sensor lives — a statement about
  *ownership* that put the card on the wrong page. The PV card on Overview asks
  why the array is producing what it produces; this card answers what the sky is
  currently offering. Those are two halves of one question and were a tab apart.
  Hydroponics keeps the sensor's numbers in the environment grid, which is where
  they already were.

- **The card shows lux, not W/m².** It converted the reading to irradiance and
  showed `443 W/m²` under a `% of a clear noon` caption. The conversion is sound
  arithmetic and it was still the wrong number to show: a W/m² figure is a
  quantity the PV card is the authority on, and a user asking what the sky is
  doing should not have to interpret a photometric-to-radiometric conversion to
  find out.

  The card now shows what the sensor measured — lux — plus the condition that
  number lands in, in words. `luxToIrradiance` is still used, but only to drive
  the brightness bar: a fraction of one sun is a bounded thing to fill a track
  with and does not need spelling out.

  This is a patch, not a minor, because **no function was removed and the
  underlying reading is unchanged.** The same sensor, the same thresholds, the
  same condition vocabulary; one number on screen became a different number on
  screen.

- **Settings is more compact per block.** `SectionCard` padding 16 → 12, its
  bottom 12 → 8, and the divider's gap plus the gap under it become one `xs`
  each. The eight category rows drop from 16 to 12 to match. The drill-in
  ListView's top gap 12 → 8 and its bottom reserve 24 → 16, which was reserving
  space for a shadow that no longer exists.

### Fixed

- **The sky card's brightness bar drew full at every reading above 1.8% of a sun.**
  The track is a `Container` inside a `Column(crossAxisAlignment: start)`, so it
  sized itself to its own child — a `FractionallySizedBox` — instead of
  stretching to the card's width. The bar came out 208 dp on a card 387 dp
  *inside*, so the fill and the track were the same width and every reading
  looked like full sun.

  **The old tests could not see it.** `never draws wider than its track` passed,
  because the fill and the track *were* the same width; and the percentage was
  only ever asserted as text. The new test reads the bar's rendered width against
  the track's, which is the first thing in the suite to describe the shape rather
  than the caption.

  Fixed with `width: double.infinity` on the track.

  This is the same shape as the bug `109....` and `DateStripChip` were: an
  assertion about a caption is not an assertion about a shape, and `flutter
  analyze` plus a fully green suite is not evidence either way.

---

# [1.9.0] - 2026-10-10

**Midnight Categorical** — one visual system instead of four, colour as a
vocabulary, three typefaces bundled.

### Changed

- **The app now ships one visual system instead of four.** The four appearance
  presets (`light`, `dark`, `dracula`, `skeuo`) are gone and with them the
  soft-UI layer they required. A card is a tonal step above the page bounded by a
  1px hairline, rather than the same colour lit by a three-shadow pair.

  - `design_tokens.dart`: 1219 → 420 lines. `AppTheme`, `AppElevation` and
    `AppSkeuo` deleted. `AppBorders` replaces the shadow system.
  - `liquid_glass.dart`: 850 → 380 lines. The primitives keep their names and lose
    their `theme:` parameter.
  - `main.dart`: one `ThemeData`, no `darkTheme`, no `themeMode`.

- **Colour is categorical, reversing a rule the app used to enforce.**
  `metricColor` accepted an `index` and deliberately ignored it, and a test
  failed loudly if it ever started using it. That reasoning was sound for a
  single-accent app; it does not survive a design whose premise is that a
  category of data owns a hue and every appearance of that category reuses it.

  - `MetricCategory` enum (`pv`, `ac`, `battery`, `environment`, `water`).
  - The red/green/blue chart triad is retired.
  - The energy report's amber/blue pair and the CCTV status colours were two more
    competing systems; all three now resolve to the same hues.

- **Three typefaces bundled.** Space Grotesk (500, 700) for numerals, Plus
  Jakarta Sans (500, 700) for uppercase tracked labels, JetBrains Mono (500) for
  tabular ratios. The brief asks for weight 900; Space Grotesk's axis stops at
  700, so all styles are 700 and the reason is recorded at the scale.

### Removed

- **Settings → Appearance.** The theme picker and the accent swatches are gone.
  Colour is now a vocabulary — a hue means a category of data — so letting the
  user repaint the app would destroy the one thing the palette is for.

- **`lib/theme/app_theme_controller.dart`**, which carried an `AppTheme` option
  and an accent seed; both are gone with the presets.

- **Dead code the migration orphaned**, each verified with a grep before removal:
  `DateStrip.accentColor`, the never-read `ChartSectionHeader.onPickRange`
  (already dead before the migration, verified against the pre-migration file),
  `ExportButton.sharing`, and the unused `cardWidthFor` test helper.

### Added

- **`SolarConditionCard`** and `utils/solar_irradiance.dart`.

---

# [1.8.0] - 2026-10-07

Security review of the whole source, and a skeuomorphic interface layer.
