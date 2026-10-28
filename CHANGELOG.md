# [Unreleased]

### Changed

- **The app is on the WattVision design system, and it is dark-only.** The whole
  surface stack moved: a flat `#121212` page, `#1E1E1E` cards, `#252525` tiles, a
  `1px solid #2C2C2E` border on every card, one cyan data accent `#00E5FF`, alert
  red `#FF453A`, and one lift (`AppShadows.subtle`) instead of an elevation
  ladder. Card padding went 12 → 20, titles are Inter 24 semibold, and KPI figures
  are JetBrains Mono 32 bold. Every energy figure now shows its `Bs.` equivalent
  beside the kWh at the tariff the report already used.
- **The appearance setting is gone.** `AppTheme.apply` clamps every brightness to
  dark, so the Light/Dark/Auto picker and the accent picker had nothing left to
  do; the Settings section was deleted rather than left as three controls that do
  nothing. A stored preference is still read and ignored rather than discarded, so
  an existing install does not see a settings-reset on upgrade.
- **The `_light.png` visual-audit goldens were deleted.** With the clamp in place
  they were byte-identical duplicates of their `_dark` twins — pictures of a
  palette the app can no longer paint. The harness kept its ramp-suffix plumbing
  so a second ramp would be a one-line change to `kRamps`.
- **The page, the sweep behind it and the overscroll fallback were three
  different values.** The app had a black page, a mid-blue gradient and a third
  flat colour under an overscroll, with a visible seam wherever they met. They are
  one ramp now — and under WattVision all three are literally `#121212`, so the
  seam is unrepresentable rather than merely small. The chart colours were unified
  the same way for the same reason: the charts are drawn on cards, so a triad
  tuned to the page was the one that vanished — the green series measured
  **1.84:1** on the card it was actually drawn on, and its legend label with it.
- **The fonts were two families at once, and two of their weights were
  imaginary.** A style that asked for Semi-bold was painted Bold, and one that
  asked for Medium was painted Regular, because those two instances were not
  shipped — Flutter resolves a weight to the nearest *declared* cut and says
  nothing when it does. They ship now, and the type scale is one set of roles
  rather than forty literals at three sizes each.
- **The app moved without a transition.** Every screen was cut in rather than
  arriving, and the dashboard's pages and the navigation bubble each ran on
  their own clock, so one swipe read as two gestures. There is now one route
  transition and one clock, and the live figures count to their new value
  instead of jumping.

### Fixed

- **A typed API key was not saved.** The AI assistant's settings section wrote
  on `onSubmitted` only — the keyboard's done key — so pasting a key and tapping
  the back arrow, which is what people actually do, wrote nothing. Writes are
  now debounced while typing and flushed when the section closes, by any route.
- **The assistant screen did not re-read the key after Settings.** Opening
  Settings from the chat screen, adding a key and coming straight back landed on
  the same "No API key yet" screen, which reads as a failed save.
- **Two of the six provider defaults were models their provider had already shut
  down.** `gemini-2.0-flash` was retired by Google on 1 June 2026 and
  `llama-3.3-70b-versatile` by Groq on 16 August 2026, so both answered 404 out
  of the box. Every default has been re-read from the provider's own model list,
  and a 404 now says the model name is not recognised instead of printing a bare
  status.
- **Every OpenAI request would have failed with a 400.** The body sent
  `temperature` and `max_tokens`, both of which OpenAI's current reasoning
  models reject as unsupported parameters. Neither is sent; reply length is
  controlled by the prompt.
- **The assistant's button covered a reading.** A floating action button sits
  over the last card on every page. It is an app-bar action now, beside Alarm
  History, which overlaps nothing and is on all four tabs the same way.

---

# [1.15.0] - 2026-10-13

### Added

- **AI assistant.** An app-bar button on the dashboard opens a chat screen that
  answers questions about the current readings ("how much is the battery
  doing?"), or tap one of the four suggested questions.
- **Your own API key, in Settings > AI assistant.** Pick a provider (OpenAI,
  Anthropic, Google Gemini, DeepSeek, Groq, OpenRouter, or any OpenAI-compatible
  endpoint), paste your key, and confirm the model name. **The app ships no key
  and falls back to none** — with no key the assistant stays off across restarts.
  The key is written to `flutter_secure_storage` beside the ThingsBoard token,
  never to `SharedPreferences`, and never placed in a request body or a log
  line.
- **The model sees one thing: a telemetry snapshot.** The live readings and the
  day's kWh totals are formatted into a block the system prompt embeds, and the
  same block is shown on screen before the first question. Nothing else from the
  app is sent, and the prompt states that text inside the block is data to
  report, never instructions to follow.
- Questions are sanitised before sending: control characters stripped, whitespace
  collapsed, length bounded. The transcript lives in memory only and is gone when
  the screen closes.

> **Shipped with five defects, all fixed on 13 October 2026** — a key that did
> not save, two provider defaults pointing at models their provider had already
> retired, an OpenAI body that would have 400'd, and a button over a reading.
> They are listed under [Unreleased] because that is where a reader looks for
> them. The release as published did not have a working assistant on Gemini, so
> treat 1.15.0 as a broken first attempt rather than a release to build on.

Figures on the right edge, a sky that reads as a picture, a home-screen widget,
and a way to find out a new build exists.

### Fixed

- **Every figure sat 208 dp from the card's right edge.** `Flexible` defaults to
  `FlexFit.loose`, so the `FittedBox` around each value shrink-wrapped to its own
  glyphs and `RenderFlex` packed the row from the start, leaving the leftover at
  the end. `AC_LOAD  26 W` measured with the reading 12 dp from its own label and
  208 dp of empty card to its right. `tight` on both boxes.
- **A limit caption printed 6.8 dp from its slot name**, reading as part of the
  label rather than as a note about the figure. It moved to the far edge.
- **The caption wrapped to four lines at a 2.0 system font** - `15-50`, five
  characters, laid out 120 dp tall.
- **Switching light or dark left every panel in the previous palette for up to
  ten seconds.** `_visualToken` had no palette entry, so each `Bound` saw an
  unchanged token and kept its cached child. The symptom was the app in one
  colour and one panel in the other.

### Added

- **The sky as a dot matrix** on `SKY_STATE`, drawn from the same lux as the
  word beside it. 44 dp at the row's right edge.
- **A home-screen widget**: PV output, house load, state of charge and lux, with
  the age of the reading. It reads the cache the app already writes and does not
  poll, so with the app closed it is as old as the last time the app was open -
  which is why it says so.
- **An update check.** Once a day, the latest GitHub release is compared with the
  installed version and a banner appears when there is one. It opens the release
  page in the browser; it does not download or install anything. Settings →
  About → Check for updates bypasses the daily gate.

### Known limits

- The home-screen widget is dark in both themes. A `RemoteViews` layout cannot
  read `Theme.of`, and making it follow would mean a layout swap driven from a
  method channel on every theme change.
- The update check needs GitHub to be reachable. Offline, rate-limited or an
  unexpected response shape all produce no banner and no error.

---

# [1.13.0] - 2026-10-12

The black strip under the nav bar, a Peak that was not a peak, a TARGET that was
a forecast, and three panels that now sit on the Power page's scale.

### Fixed

- **The black strip under the nav bar in the light theme.** I had concluded four
  times that it was a SystemUI window and was not ours to fix. It was ours.
  `dumpsys window` does report `NavigationBar0` down there, and
  `navigationBarColor`, `windowLightNavigationBar`, `windowBackground` and the OS
  dark-mode setting all failed to move it — none of them could have. The
  Scaffold's body slot stops at the nav bar and `AppBackground` paints only the
  body, so the strip below it was painted by nothing at all: invisible in the dark
  palette because the page is nearly black, and a black band under a white bar in
  the light one. Settings was always right — it leaves `backgroundColor` unset and
  takes `scaffoldBackgroundColor`. The dashboard now sets the same one line.
  What settled it was sampling the screenshot with `windowBackground` deliberately
  set to magenta, which did not appear in the strip.
- **`Peak` was never a peak.** `_todayPeak` clamped the current reading and was
  called with `pvPower` from the PV hero, so the hero's secondary figure repeated
  the hero. It is now `OverviewReadings.pvPeak`, computed in the dashboard from
  the PV history the chart carousel already fetches — not from a running max in a
  widget, which would silently reset on every cold start.
- **`TARGET` was a forecast of a forecast.** `forecast.targetProgress` divides a
  24-hour *extrapolation* of the day's production by the daily target, so it read
  176% at midday on a good day. The row sits next to a production figure, so the
  reader takes it as progress made. The Overview now divides observed production
  by the same target; the estimate is still what `EnergySummaryCard` shows,
  labelled as one.
- **The CCTV standby overlay is a play button and nothing else.** One accent circle
  with `play_arrow_rounded`, where it used to be a camera glyph plus two sentences
  plus a duplicate button. The label moved to `Semantics`, because an unlabelled
  68 dp circle is a button with no name.

### Changed

- **The Overview, Environment and Fish panels are on the Power page's scale.**
  `slotValue` 15 -> 24, `slotKey` and `slotUnit` 11, `slotMicro` 10,
  `slotValueSmall` 12 — `TelemetryCard`'s figure, label and unit, verbatim. The
  middle step (18/12/12) was a guess at "a bit bigger"; 24 is the number that was
  actually on the other page.
  - **The mono family is the one thing that stays.** Power's card inherits
    `DefaultTextStyle` and lands on Inter; these five tokens are mono and
    `design_tokens_test.dart` pins that. Matching the scale is what the eye reads
    as "same app"; matching the typeface would erase the one thing that says a
    panel is instrumentation rather than a list of readings — and it would take
    the meters, the hero figure and `TerminalTag` out of the comparison anyway,
    because `TelemetryCard` has none of those, so swapping to it would be a
    deletion dressed as a restyle.
  - These five tokens are the only type in the three panels, so one edit moves
    all of them together.
- **`TerminalRow` takes an optional `valueStyle`.** The value sits in a
  `FittedBox(scaleDown)`, so without it the drawn size was whatever was left over
  after the slot name and the limit caption. On the period summary that produced
  one size for the short triples and a smaller, different size for each long one —
  the same widget, the same column, a font size that tracked string length.
- **The date strip's gap is a ladder** (6 / 4 / 2 / 0) and the chip's horizontal
  padding is 6 rather than 8. A fixed 6 dp gap meant the seventh day scrolled off
  the right edge on a 381 dp phone, which the user reported as a cut-off calendar.
  The gap gives way before the type does; shrinking the day name is not available,
  because `liquid_glass.dart` documents that a `FittedBox` there was tried and
  reverted for silently inverting the user's font scale.
- **The chart export is landscape.** The card fills the height on the right and the
  caption takes the gutter on the left, scaled with the card so it reads as the
  app's own heading rather than two words lost in a corner. The canvas is a fixed
  1920 x 1080 rather than a pixel ratio over the card's logical width, which was
  about 950 px on a phone — seven series across that are one pixel each, which is
  what the user reported as "the data is not visible".

### Known, not fixed

- **A 50 px black strip under the light theme, drawn by SystemUI.** Recorded in
  1.12.0 and now known to be wrong — see the fix above. The note is left in place
  because the four measurements it lists are still true and are the reason the
  conclusion took four attempts to reverse.

---

# [1.12.0] - 2026-10-12

The light theme, which was deferred twice, and a nav bar that stops floating.

### Added

- **A light theme, selectable in Settings - Appearance.** Light / Dark / Auto,
  persisted in `SharedPreferences` and applied on the next launch. The token
  layer became a facade over two immutable palettes (`AppSurfacesPalette.dark` /
  `.light`, `AppPaletteTheme.dark` / `.light`) behind the existing static
  getters, so all 148 `AppSurfaces` and 120 `AppPalette` call sites are
  unchanged and only ~21 `const` sites had to break. Light values come from the
  contrast solver (one scale factor per channel, so hue is preserved) except
  `error`, which is M3's `#B3261E` - the solver's own answer was a maroon that
  no longer reads as the app's red.
  - `AppPalette.onHue` **inverts between the palettes**: the fill is a light red
    in dark mode (black ink) and a dark red in light mode (white ink). It is not
    `Colors.white`, and a hard-coded white is 2.8:1 on the dark palette's bubble.
  - `color_helpers.dart`'s `statusOk` / `statusWarn` / `statusAlert` /
    `statusBad` moved from module-level literals onto the palette - they could
    not swap before, and `Sektor.dart` was drawing them directly.
  - `appPrimaryText` and `faintColor` were top-level `final`s, which captured the
    dark palette's values when the library loaded and never followed a swap. Both
    are getters now. This is the same trap twice: a top-level `final` in a
    tokenised codebase is a snapshot.
  - Guarded by `test/theme_palette_contrast_test.dart` (18 tests), which
    measures AA for both palettes against the real fills rather than against
    white.

### Fixed

- **The light theme reverted to dark on every launch.** `_loadMode` stored the
  mode and called `setState`, but never called `AppTheme.applyMode`. Both of
  `MaterialApp`'s theme slots are built from `AppTheme.brightness`, so the app
  came up dark while Settings said Light, and the first tap on the segmented
  control was what fixed it.
- **The nav bar was docked at the bottom instead of floating.** No 24 dp side
  margin, no 10 dp gap, no stadium radius, a top hairline instead of a full
  border, and `BorderRadius.zero` rather than `AppRadius.pill` - a docked bar's
  bottom corners are the screen's corners, so a radius there paints
  page-coloured notches in them.
  - `extendBody` went to `false` with it. `extendBody: true` exists so an
    overlay bar can sit over the content; nothing covers a docked bar's strip, so
    the last row of the Overview panel showed through under it.
  - `kGlassNavBarBottomGap` is 0, and `glassNavBarReservedHeightFor` no longer
    has a non-zero floor to be flat below.

### Changed

- **The nav bar's collapse-on-scroll is gone**, along with `_navCollapsed`,
  its `_downScrollDistance` accumulator, the `_CollapsedNavItem` crossfade and
  the `glass_nav_bar_collapsed` golden. All four destinations are visible at all
  times; a bar that hides its own destinations on scroll is a bar you cannot tap
  your way back out of.
- **The accent bubble travels.** One `AnimatedPositioned` disc slides to the
  selected slot instead of a per-slot crossfade - a crossfade draws two bubbles
  fading through each other while you swipe, and neither copy is where your
  finger is. The selected glyph is `AppPalette.onHue` on the disc, not a red
  glyph on the page.
  - Destinations are laid out at a fixed 48 dp pitch, centred, rather than
    `Expanded` across the bar: a quarter of a 360 dp screen put the icons 90 dp
    apart for a 22 dp glyph, and the disc looked stranded between two empty
    halves. `min(48, width / 4)` on a narrow screen.
  - The disc and the glyph's colour share one clock - `AppMotion.container` and
    `easeInOutCubic`. The glyph used to turn 170 ms before the disc arrived, so
    it was white on a white page for most of a 192 dp slide.
  - `AnimatedPositioned`, not `AnimatedAlign`: `Align` places a child by
    `(W - childW) * ((x + 1) / 2)`, putting the *leading edge* on that
    fraction rather than the centre - 16.5 dp off on the first slot.
  - Pinned by `nav_bar_clearance_test.dart`, which walks all four indices and
    measures the disc against its icon.
- **`MaterialApp.color` is `AppSurfaces.page`.** Docking the bar removed the
  accident that covered the edge-to-edge gesture inset, so the window now paints
  its own background there instead of relying on a `Scaffold` that does not
  reach. Measured: the app's own page colour reaches y=2650 of a 2712 px screen.
- **`android:navigationBarColor` is transparent in both themes.** It was a
  hard-coded `#101412` - the page colour from when the app was dark-only - which
  cannot be right now that light/dark is an in-app setting the OS day/night
  resource qualifier cannot see.

### Known, not fixed

- **A 50 px black strip under the light theme, drawn by SystemUI.** `dumpsys
  window displays` reports `mNavigationBar=Window{... NavigationBar0}` owned by
  `com.android.systemui`, `fmt=TRANSLUCENT`, `flags=[SUPPRESS_SCRIM]`, spanning
  the bottom 156 px. Sampling the screenshot puts the app's page colour at
  y=2650 and pure black at y=2690, so the app is not what leaves it black.
  Four candidates were built and measured, and none of them moved it:
  `navigationBarColor = transparent`, `windowLightNavigationBar = true`,
  `windowBackground = #FF00FF`, and `cmd uimode night no` - which is the
  informative one, because MIUI draws that strip opaque regardless of the OS
  theme either. The one remaining app-side lever is
  `windowOptOutEdgeToEdgeEnforcement`, which restores `navigationBarColor` by
  making the window stop extending behind the bar; it also un-does the full-bleed
  app bar, and it still could not follow an in-app theme toggle. Not taken.

### Removed

- `chartSeriesColor`, `statusBadFill` and `prefixTitle` - deleted outright, both
  confirmed unreachable by search first. `statusBadFill` in particular had no
  caller left once the sector grid stopped drawing a filled chip.
- `_cctvKeepAlive` survives. It is referenced four times and appears to be dead,
  but four references that all live in the same class are not four callers -
  re-verify with a real call graph before removing it, and this entry is here so
  the next person does not trust the count.

### Known, not removed

- `EnergySummaryCard` (488 lines) and `SystemStatusStrip` (239 lines) have no
  production caller - every hit for either name in `lib/` is inside a comment
  explaining why it stopped being used - but both files and their tests remain.
  Deleting them is a separate change with its own review, not a footnote to a
  nav bar diff.

### Security

- Audit over the alarm module, the ThingsBoard client, the CCTV WebView, the
  manifest and the Dart services: no Critical, High or Medium findings, and no
  path that exfiltrates a credential. Two fixes anyway: `_matchesBaseUrl` in
  `thingsboard_api.dart` compared host only, so a scheme or port mismatch passed;
  and `AlarmBridgePlugin.kt` logged the exception object rather than its class,
  which on the token-refresh path could have embedded a JWT fragment.

---

# [1.11.0] - 2026-10-12

Every accent becomes the red one. The canvas goes pitch black. The meters become
segmented bars. All four are the same reference.

### Changed

- **One accent, and it is red.** `main.dart`'s `ColorScheme` was still setting
  `primary` to acid lime, so every `FilledButton`, `SegmentedButton`, `Switch`,
  `ProgressIndicator`, selection handle and focus ring in the app inherited it —
  converting call sites alone would have looked half-finished forever.
  `categoryColor` collapses to `AppPalette.error` for all five categories.
- **The page canvas is `#000000`.** It was `#1A1A1A`, a value that came from
  light mode where the page had to stay a mid-tone for a shadow to fall on. The
  panels take their depth from the hairline and the segmented bar, so that reason
  is gone. `AppSurfaces.track` was the same grey and only worked because the page
  was; it is now `page` by value, which is also the right reading — an un-lit
  segment is a hole, not a lighter grey.
- **Meters are 20 square blocks with 2 dp gaps**, not a continuous rounded fill,
  matching the reference's segmented bars. One widget (`TerminalMeter`) draws
  every meter in the app, so Overview, Environment and Fish changed together.
- **The nav bar is a capsule**, not a slab: 64 -> 54 dp tall, 40 -> 36 dp slots.
  The four icons are drawn at the same size — they were declared at 24 dp and
  rendered at **8.6 / 11.8 / 18.9 / 23.6** because a `FittedBox` wrapped the icon
  and the label, and the label set the scale. Pinned by
  `nav_bar_icon_size_test.dart`, which has to walk up through every
  `RenderFittedBox` and multiply — `RenderBox.size` cannot see a paint transform.
- **The sky is three daylight states and a night**: `clear` / `partlyCloudy` /
  `overcast` / `night`. `night` is a different kind of reading, not another rung
  — at `<= 0` lux there is no measurement of the sky at all, and a lux sensor
  reports a small negative value in the dark the same way the BMS reports
  `-0.01 A` while idle.
- **The Overview hero is PV output**, not the house load. It was the load, on the
  argument that a healthy array reads 0 W at midnight and 0 W under a storm, so a
  large figure that collapses every night trains the reader to distrust it. That
  call was reversed; the cost is recorded on `overview_panel.dart`.

### Added

- **A summary of the selected day** — solar generated, load used, net (unclamped;
  negative is a real answer), and min/avg/max for every environment and fish
  reading. It appears only when the selection is not today, because for today the
  Overview already carries `ENERGY (24H)` one screen above. The env and fish
  history was genuinely missing before: the Overview is page index 0,
  `_prefixForPage(0)` is null, and no request was ever fired.
- **`TerminalPanel.semanticLabel`.** It had been hardcoded to `'Overview'`, so
  every panel on screen announced itself as the Overview.

### Fixed

- `BAT_SOC`'s left caption was the literal string `'BAT_SOC 0%'`, hardcoded,
  while the caption to its right read the real value. Invisible on a continuous
  bar; a flat contradiction once the bar was segmented — `0%` printed over eight
  lit blocks. `overview_panel_test.dart` is new.
- `_weeklyEnergySummary` was read by the Overview builder but was not in
  `_visualToken`, and is only written by `_setWeeklyEnergySummary`, which bumps
  `_energyRevision` — a notifier that subtree is not bound to. Tapping 24H / 7D
  changed nothing until the next telemetry poll.
- `thingsboard_api.dart`'s `_send` checked `request.url.host` only; a URL of the
  right host on the wrong scheme or port would have carried the JWT in the clear.
  Scheme and port are compared against the parsed `baseUrl` too.
- `AlarmBridgePlugin.kt` logged the exception object on two catches, and
  `org.json` embeds a fragment of the unconsumed response in its parse errors.
  Now `error.javaClass.simpleName`.

### Security

A full source-level re-audit: no Critical/High/Medium, and every claim the
previous audit made still holds — the token handover, the host allowlist, the
manifest's exported receivers, the absent TLS bypass, the boolean-only logging,
the WebView guards, the SharedPreferences purge, the alarm budget and lock.

### Notes

The glowing red is a **shadow, not a fill colour**, and that is a measurement
rather than a taste. A search over every red that still clears 4.5:1 on
`surfaceMuted` returns nothing more saturated than the value that was already
there: the luminance floor that contrast implies pins it at about `#FF6B6B`. So
`AppShadows.glow` is applied to the hero figure and per meter block, and
`AppPalette.error` is unchanged. Black ink on that fill is 7.57:1 and white is
2.78:1 — white fails AA by 1.6x, which is why every red fill reaches for
`AppPalette.onHue`.

716 tests across 55 files, 0 failing.

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
