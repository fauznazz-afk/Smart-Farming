# [Unreleased]

### Added

- **A solar reading, derived from the lux sensor the greenhouse already had.**
  The environment grid reported `41200 lx`, which is a number nobody can act on.
  `lux / 93` turns it into `443 W/m²` — the luminous efficacy of sunlight — and a
  five-step scale names the sky from it, so the dashboard now answers "is it
  bright out" rather than making the user do the conversion.

  - `utils/solar_irradiance.dart` is the whole of it and imports nothing: a lux
    meter is photometric and a pyranometer is radiometric, so this is an empirical
    conversion valid for one light source, not a physical identity, and the file
    says so where someone editing it will read it.
  - Thresholds land on lux values a grower already knows — 55 000 is a greenhouse
    roof in full sun, 28 000 a bright overcast day, 1 800 a storm.
  - The card sits on Hydroponics, directly above the environment grid that still
    carries the raw lux beside it, and the bar is scaled by 1000 W/m² so it reads
    as a fraction of one sun.

### Fixed

- **The Overview calendar's date strip was not one row, and it was not centred.**
  Three independent causes, all found on the device rather than reasoned about.

  - A day name with no `maxLines` *breaks at a character* to fit, so `MON` drew as
    `MO` over `N`. The chip's height is its content's height — deliberately, so a
    3x system font cannot truncate the number — so one cell of seven grew a line
    taller than its neighbours. `date_strip_test.dart` was blind to it: it
    asserts `didExceedMaxLines`, which a wrapped line does not set.
  - The header had *three* left edges inside one widget. A `Padding(2)` plus a
    48dp button plus a 4dp gap put the legend text at 54dp while the chip row
    started at 0, and pulled the header's right edge to `maxWidth - 2` while the
    chips ran to `maxWidth`. Nothing was misaligned by enough to name; the eye
    reads the sum. The calendar button now trails, so both edges are the chip
    row's.
  - The strip's width probe measured the day name *upright* while the selected
    chip draws it *italic* — and italic is the wider of the two. The one chip with
    the least room to spare was the one carrying the widest string.
  - Measured after the fix: margins 16 and 16, seven chips 49dp wide and 68dp
    tall, identical.

- **The nav bar's rounded corners were being clipped off.**
  It gained a real radius, and `ClipRRect` still had none — because in Flutter
  3.47 `ClipRRect.borderRadius` *defaults* to `BorderRadius.zero` rather than
  being required. The clip is painted over the fill, so the active tab's lime
  squared off the corners on the device while `flutter analyze` stayed clean and
  every test passed. A decoration's radius and its clipper's radius being allowed
  to disagree is a shape that cannot exist; a test now pins them equal, and was
  verified by reverting the fix.

- **A test that was passing because of the bug it was written to prevent.**
  `absent_and_failed_states_test.dart` asserted the chip grew past its
  `minHeight`, which on the test font it did by *wrapping* — the defect above.
  Its own comment says the claim is "the text gets taller with the scale", so that
  is now what it measures, with two new tests for the one-line and
  uniform-height properties.

### Changed

- **The electrical charts plot voltage, current and power, and nothing else.**
  Energy, frequency, power factor, state of charge, cycle count and both
  capacities are no longer plotted on PV, AC or Battery. They are all still
  fetched on the live path and all still shown in their metric cards; what was
  removed is the plotting. A chart is a shape, and a running total or a
  dimensionless ratio has a shape that carries no information about the day. Each
  electrical group is now a three-series group, so it takes the fixed chart series
  order rather than a category hue.

  - **A no-op golden was removed.** `metric_grid` did not finish rendering on a
    7 GB machine and left a partial frame behind that looked like a defect in the
    widget. `metric_grid_test.dart` covers the widget properly; a golden of a
    half-drawn frame is worse than no golden.


- **Midnight Categorical: the app now ships one visual system instead of four.**
  The four appearance presets (`light`, `dark`, `dracula`, `skeuo`) are gone and
  with them the soft-UI layer they required. A card is no longer the same colour
  as the page lit by a three-shadow pair; it is a tonal step above it, bounded by
  a 1px hairline, and the page may be as dark as the design asks for because the
  mid-tone constraint that used to keep it light existed only to give the shadows
  somewhere to go.

  - `design_tokens.dart`: 1219 lines to 420. `AppTheme`, `AppElevation` and
    `AppSkeuo` are deleted. `AppBorders` replaces the shadow system. The card
    radius doubles from 16 to 24, the brief's `rounded.xl`.
  - `liquid_glass.dart`: 850 lines to 380. `AppCard`, `AppTile`, `AppBadge`,
    `AppBackground`, `AppDivider` and `DateStripChip` keep their names and lose
    their `theme:` parameter — keeping the names meant the roughly forty call
    sites needed no change, and dropping the parameter meant none is left holding
    a value that means nothing.
  - `main.dart`: one `ThemeData`, no `darkTheme`, no `themeMode`. The `builder:`
    that recovered an `AppTheme` back out of the scaffold colour is gone, because
    `MaterialApp` cannot express a third brightness and there is now one.
  - `nav_bar.dart`: flat bar with a hairline, active item in `primary` with no
    pill and no underline, labels `AppType.labelMicro`.

- **Colour is categorical, and that reverses a rule this app used to enforce.**
  `metricColor` and `strongMetricColor` accepted an `index` and deliberately
  ignored it, and a test failed loudly if they ever started using it — "a colour
  the user did not choose is a colour they cannot predict". That reasoning was
  sound for a single-accent app. It does not survive a design whose premise is
  that a category of data owns a hue and every appearance of that category
  reuses it.

  - `MetricCategory` enum (`pv`, `ac`, `battery`, `environment`, `water`) with
    `categoryColor()` and `categoryColorForKey()`. Five hues for five
    categories: PV is butter, AC is periwinkle, Battery is coral, environment is
    violet, water is coral-red.
  - The red/green/blue chart triad is retired. It was applied identically to all
    nine electrical series, which under a categorical system is actively wrong:
    on the PV page the red line was a different category's hue.
  - The energy report's amber/blue pair and the CCTV status colours were two more
    competing systems. All three now resolve to the same categorical hues.
  - `statusOk`/`statusWarn`/`statusAlert`/`statusBad` are constants.

- **Three typefaces bundled, and the weight ceiling is the typeface's.** Space
  Grotesk (500, 700) carries every numeral, Plus Jakarta Sans (500, 700) carries
  the uppercase tracked labels, JetBrains Mono (500) carries tabular ratios. The
  brief asks for weight 900 on headlines; Space Grotesk's axis stops at 700, so
  all styles are 700 and the reason is recorded at the scale.

### Removed

- **Settings → Appearance.** The theme picker and the accent swatches are gone.
  Colour is now a vocabulary — a hue means a category of data — so letting the
  user repaint the app would destroy the one thing the palette is for. Nine
  settings categories become eight.

- **`lib/theme/app_theme_controller.dart`.** It carried an `AppTheme` option and
  an accent seed; both are gone with the presets. `app_theme_of.dart` was
  already deleted in the migration.

- **Dead code the migration orphaned, each verified with a grep before removal:**
  `DateStrip.accentColor` (the chip reads `AppPalette.accent` unconditionally and
  `categoryColor(MetricCategory.pv)` is that same value), the never-read
  `ChartSectionHeader.onPickRange` (already dead before the migration — verified
  against the pre-migration file), `ExportButton.sharing` (replaced by
  `sharingNotifier`), and the unused `cardWidthFor` test helper.

### Fixed

- **`AppBorders.categoricalBorder` returned the wrong type.** Every caller feeds
  `BoxDecoration.border`, which wants a `BoxBorder`; the function returned a
  `BorderSide`, so six call sites were writing
  `Border.fromBorderSide(AppBorders.categoricalBorder(...))`. Both shapes are now
  named — `hairline`/`control`/`boundary` for a single edge, `*Border` for a
  decoration.

- **761 analyzer errors to 0.** Almost all were mechanical: a regex split six
  `show` clauses onto their own lines, an import was added to every line instead
  of once, and two `test(...)` callbacks needed `testWidgets`.

- **The light-theme shadow reduction from `615644f` is retained.**

### Added

- **`SolarConditionCard`** and `utils/solar_irradiance.dart`, converting the
  greenhouse lux reading to W/m² so a number the user has no feel for becomes a
  reading they do.

---

# [1.8.0] - 2026-10-07

Security review of the whole source, and a skeuomorphic interface layer.

### Added

- **Skeuo, a fourth theme carrying the design brief's own palette.** Amber
  `#F59E0B` and lime `#C4F042` on a `#0A0A0C` page, selectable in Settings →
  Appearance beside System, Light, Dark and Dracula.
