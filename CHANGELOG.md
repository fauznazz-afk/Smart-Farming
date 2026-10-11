# [Unreleased]

---

# [1.10.0] - 2026-10-11

The Overview becomes one instrument panel, and the app grows a second typeface.

### Changed

- **The Overview is one panel, not four cards.** It used to be the live-power
  hero card, the sky card, the energy summary card and the status strip, each in
  its own rounded box with its own 8dp gap. That composition says "four
  different widgets", and what it means is "one readout, and these are its
  fields". It is now a single frame with hairline rules inside it and every
  reading on a labelled row.

  Nothing was lost. Both routes the removed cards carried are now entry points
  inside the panel — `BAT_SOC` opens the Battery view, the `ENERGY` heading opens
  the full report — and the sky reading is the `LUX` row rather than a whole
  fifth card.

- **JetBrains Mono is bundled, at two weights.** The panel's argument is that
  its rows read as instrumentation, and that is a *monospaced* claim: in a
  proportional face a column of `PV_OUT` / `SKY_LUX` / `BAT_SOC` is three
  different widths and looks ragged. Weight 500 for the keys you read around,
  700 for the values you read for — that contrast is the panel's whole
  hierarchy, doing the work colour does on the categorical pages.

  **Only the Overview uses it.** The other three tabs, the nav bar and Settings
  stay Inter, so this is a one-page change and not a restyle.

- **The hero is the house load, not PV output.** A healthy array reads 0 W at
  midnight and 0 W under a storm, so a big PV figure is a number that trains the
  reader to distrust it. The house draw is the one figure on the page that is
  bounded, non-negative and always present.

- **Slot-name vocabulary.** `PV_OUT`, `BAT_SOC`, `SKY_LUX`, `LUX`, `METER_AGE` —
  abbreviated, underscored, monospace. An abbreviation is a smaller promise than
  a word, and it reads as instrumentation rather than as a consumer dashboard.

- **A zero bar now draws nothing.** The meters use a `widthFactor`, because a
  `Row` of two `Expanded`s cannot express "zero of this" — both children get at
  least their flex share, so a 0% reading drew a visible stub.

- **Trailing zeros are trimmed.** `81.0 W` and `12.00 A` read as false precision
  in a tabular column; the sensor reported a whole number, so the display says
  so.

### Added

- **`terminal_panel.dart`** — `TerminalPanel`, `TerminalRow`, `TerminalHero`,
  `TerminalTag`, `TerminalMeter`, `TerminalRule`, `slotNumber`.
- **`overview_panel.dart`** — `OverviewPanel` and `OverviewReadings`.
- **Terminal type scale** — `AppType.slotKey`, `slotMicro`, `slotValue`,
  `slotValueSmall`, `slotUnit`, `heroFigure`, `heroUnit`.

### Fixed

- **Two routes would have died with the cards.** `SystemStatusStrip.onOpenBattery`
  and `EnergySummaryCard.onOpenReport` were the only callers of
  `_openBatteryFromStrip` and `_openEnergyReport`. Removing those cards without
  carrying their entry points forward would have left the Battery view and the
  full energy report unreachable from anywhere on the app.

- **The energy forecast survives its card.** `EnergyForecastService` and the
  daily production target are still configured in Settings; the two rows
  `TARGET` and `BAT_RUNTIME` carry the result. A negative runtime is *not*
  painted as a breach — "minus three hours" means the array cannot cover the
  load right now, and it is the most useful number the forecast produces.

- **The `BAT_SOC` meter's hit area is the whole row, not the 6dp bar.** A 6dp
  target is under the 48dp minimum every platform calls accessible, and this one
  is a shortcut to another page.

### Removed

- **`_heroCard`, `_energySummaryCard` and `_dualCards`** — private builders with
  no remaining caller, each of which was a page section the panel replaced.
  Their four widget files are still here and still tested; what went is the
  section, not the widgets.

---

# [1.9.2] - 2026-10-11

Three visual complaints from the device, and three silent bugs underneath them.
No behaviour, reading or alarm rule changes — this is entirely how three things
look.

### Changed

- **The nav bar is a stadium, not an 8 px rectangle.** It used to be
  `AppRadius.card`, and 8 px on a bar 76 dp tall is a corner radius of about 10%
  of the height — roughly two millimetres at a phone's density. It read as a
  chamfered rectangle. A tab bar is the one *floating* element in this app
  (`extendBody: true`, a gap under it, page visible on both sides), and a floating
  object with near-square corners does not read as floating; it reads as a strip
  that happens to be inset.

- **Two of the four nav glyphs were wrong.** `set_meal` is Material's
  fish-on-a-dinner-plate icon and reads as a menu; the Fish page reports
  temperature, pH and turbidity, so it is now `water`. `dashboard` is a
  nine-square grid, which at 24 dp in a 72 dp slot is a grey smudge, so it is now
  `space_dashboard`. `bolt` and `eco` were the right glyphs at the wrong weight —
  `Icons.bolt` is a hairline zigzag and `Icons.eco` a thin outline, both the
  Material 2 weight, while the rest of the bar draws at the rounded weight.

- **The sky card uses the width it has.** It was four left-aligned lines in a
  card 387 dp wide: header, figure, condition, bar. The one thing worth reading
  occupied about a fifth of the width with 300 dp of bare card beside it. The
  figure now sits on the trailing edge of the header row, baseline-aligned with
  the condition, with `Expanded` on the label column rather than a `Spacer` —
  `Heavily overcast` is nearly twice `Clear sky`, and a `Spacer` would let the
  figure slide depending on which one the card was showing.

- **The live-power row's dead space was structural.** Two equal `Flexible`
  children split the figure row in half each, so a five-digit figure was laid out
  against half the width it could have had while the other half stood empty
  holding the letter `W` — about 35 dp of nothing per slot, three times over.
  Now 4:1, and `_sharedFigureScale` models the split rather than dividing by two.

- **The three flow terms are tiles.** `surfaceAlt` fill, hairline, no shadow.
  Bare columns of text on the card's own fill is what made the row read as holes
  rather than as three stations.

### Fixed

Three bugs, all of them silent — nothing threw, `flutter analyze` was clean, and
the suite was green through every one of them.

- **The label planner and the label painter could measure with different styles.**
  `DefaultTextStyle.of(context)` was resolved independently at the
  `LayoutBuilder` and inside `_Term`. There is now one `TextStyle` instance,
  resolved once and threaded through the plan, the minimum-width search and the
  `Text`, so the disagreement is no longer expressible.

- **`plan.widths` is an *inner* width and was being used as an *outer* one.**
  Every tile came out 16 dp narrower than it was planned for, so each label needed
  one wrap more than the shared block reserved — and a flow label with no
  `maxLines` that needs one line more than it was allotted is cut silently, with
  no flag anywhere. This rendered `Discharging` as `Di…`.

- **The stacked fallback divided the width three ways for no reason.** Stacking
  exists because three columns could not hold the labels; giving each column its
  width back is the layout the fallback was asking for. At 381 dp and a 3.0 scale
  `Solar` was measured at five lines in a slot planned for three.

- **`the three figures share a line at every scale` measured the wrong thing.**
  It compared three figure tops unconditionally, which is only meaningful in the
  three-column layout — and 381 dp at a 3.0 scale now genuinely stacks. It
  asserts either one shared baseline or three separate rows in reading order, and
  still fails for two figures sharing a row and one not.

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
