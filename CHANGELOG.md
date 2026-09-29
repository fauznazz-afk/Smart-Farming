## [Unreleased]

### Fixed

- **The shipped turbidity default was arming an alarm that could never clear.**
  The sensor on the test device reads 2396 NTU and later 3000 NTU for the same
  tank, against a default limit of 100 NTU chosen from real aquaculture
  guidance — so the sensor is not on the scale that guidance assumes, and
  nobody has established what it measures. The moment a user saved the Fish tank
  alerts section, that default became a live rule and produced "Turbidity too
  high: 3000.0 NTU (limit 100.0 NTU)" every minute, indefinitely. There is no
  replacement number: any value is a guess about an uncalibrated sensor, and a
  guess that fails high is worse than no limit, because it manufactures an
  alarm that can never resolve. The default is now null, the field starts empty,
  and "Blank limits are not monitored" is the whole story. The upper cap, removed
  in the previous commit, is what lets a user now set a limit above 3000 once the
  scale is known.

- **The energy report no longer contradicts the dashboard card about the same
  two numbers.** `comparisonLabel` in the report had no minimum-meaningful
  threshold while `EnergySummaryCard` had one at 0.1 kWh, so a period that
  produced 0.01 kWh followed by one that produced none read "-100% from the
  previous period" in the report and "Nothing to compare yet" on the dashboard,
  in the same session. The threshold was also duplicated as two literals in two
  files, and the copy that had never been fixed was the report's, so the two
  were one forgotten edit away from disagreeing again. It is now a single
  `kMeaningfulEnergyKwh` in `lib/utils/energy_comparison.dart`, imported by both.
  The wording is still deliberately different per surface: the card's two tiles
  sit side by side and wrap independently, the report's label has a full line.

  Correcting an earlier claim in this changelog: the misleading "-100%" does
  **not** reach the exported CSV. `totals_card.dart` calls `comparisonLabel` from
  a `Semantics(label:)` and a `Text`, both on screen. The CSV is built by
  `csv_builder.dart`, which does not call it.

- **October and December render in English.** `_monthNames` in
  `energy_report/utils/format_helpers.dart` listed 'Oktober' and 'Desember'
  among ten English names, in an app whose locale is en_US, so a monthly report
  for those months said "Oktober 2026". Unlike the previous defect this one did
  reach exported files: `csv_builder.dart` writes `formatMonthLabel` into the
  `Period` row. `formatMonthLabel` had no test at all, so there was nothing to
  stop the Indonesian spellings coming back; there are now twelve assertions.

- **Swiping a tab no longer walks past the end of the dashboard.** Eight swipes
  left on the Overview tab landed on page nine of a four-tab pager. The gate
  class that stops a chart drag from also changing page,
  `ChartGestureLockPhysics`, decided whether a gesture was *accepted* but never
  what happened when it was *released*: it did not delegate
  `createBallisticSimulation`, so the fling fell through to `ScrollPhysics`'s
  plain friction simulation instead of `PageScrollPhysics`'s spring. A pager
  without that spring is not a pager — it coasts to wherever friction ends and
  keeps taking velocity past the end of the content. Delegating the fling
  restores the snap. It also stopped overriding `allowUserScrolling`, which is
  read when `Scrollable` installs a drag recognizer rather than when a gesture
  starts, so a chart drag could switch dragging off and lifting the finger
  could not switch it back on; paging then stayed dead until an unrelated
  rebuild arrived, up to ten seconds on a dashboard that polls every ten.

  Pinned by `test/chart_gesture_lock_test.dart`, which had no equivalent: the
  class landed in 1.6.0 with no coverage at all. The eight-swipe case is the
  regression guard, because a single swipe passes even with the bug.

- **A limit shown in Settings is no longer indistinguishable from a limit that is
  actually being enforced.** The Fish tank alerts section showed
  `Max (NTU) 100` with its switch on while turbidity read 2396 NTU and the grid
  stayed silent. Nothing was broken and nothing threw: `SettingsController`
  keeps the shipped default in the field when the preference key is missing, and
  that prefill looked exactly like a stored value. The native side had been
  configured with 19 rules, and 19 is the count *without* a turbidity rule — 20
  with one — so the key had never been written. It had no chance to be: the key
  was introduced in 1.6.0, after the last time these settings were saved, so
  every other limit persisted and only the new one did not. A user reading that
  screen believed the tank was guarded at 100 NTU when no rule anywhere
  enforced it.

  Fixed in the mechanism rather than the parameter, because every future release
  that adds a limit hits the same path: `EnvRangeSetting` now tracks whether
  each side holds an unsaved default, `load()` clears that only when the key is
  actually found, and `save()` clears it once the write succeeds. A prefilled
  number renders in the faint italic with a `Not saved yet` caption, and each
  section says once how many limits are showing defaults and are not monitored
  yet. Pinned by `test/settings_prefill_test.dart`.

  The grid was right to stay silent — with no limit there is nothing to breach —
  and it is now backed by `test/fish_turbidity_grid_test.dart`, because the fish
  specs shared a widget with the greenhouse ones without ever being exercised
  against it.

### Added

- **Turbidity can now be set to any value the sensor reports.** It was capped at
  1000 NTU while the sensor reads 2396 and then 3000, so the field rejected
  anything higher with "Turbidity cannot be higher than 1000" and the alert could
  not be configured against reality at all. The cap is removed the way TDS
  already has none, for the reason the TDS comment in `alarm_rules.dart` gives:
  a cap low enough to look safe gets crossed by every real reading, which makes
  the alert unreachable rather than safe. A cap of 10000 would be the same bug at
  a different scale, so there is no new magic number. The lower bound stays at 0
  because a negative NTU reading cannot be real.

  The bound went unnoticed because the sensor bounds tests in
  `settings_validation_test.dart` only ever reached into `envRanges`. A new
  "fish sensor bounds" group pins the three fish ranges in display order, the pH
  and water temperature caps that are left in place because those are physically
  real limits, turbidity having no upper cap, values up to 100000 validating, and
  a negative value still being rejected.

- **`EnergySummaryCard` has a widget test for the first time.** A 339-line widget
  on the Overview tab that no test had ever looked at, in a repo where three
  label regressions once passed `flutter analyze`, a release build and the entire
  suite. Eighteen tests now pin the title, the period selector, the method note,
  both tiles, the forecast block, the empty state and the 0.1 kWh comparison
  threshold, with every asserted string carrying the widget line it was copied
  from so a rename fails here rather than reaching a device.

- **`ChartBounds.maxY` is covered for a non-positive peak, and the Settings
  category list is complete.** The y range stays strictly increasing for peaks of
  0, -1 and -1e6, which is what stops fl_chart drawing an inverted axis. The
  settings test was asserting eight of ten category titles, missing both "Fish
  tank alerts" and "Background checks".

### Documentation

- `AGENTS.md` and `AGENT_PLAYBOOK.md` now describe both build machines. The
  project moved from CachyOS/Arch to Windows, and the difference that actually
  breaks a build is `android/local.properties` still holding the other
  machine's paths: Flutter rewrites that file for itself, but a bare
  `gradlew.bat` reads it directly, which is how a stale Linux path surfaces as
  `flutter.sdk not set in local.properties` on a machine that plainly has
  Flutter installed. The `dl.google.com` throttle is now scoped to the Linux
  machine and explicitly marked as never re-measured on Windows — a normal
  Windows build downloads nothing because the Gradle distribution and the NDK
  are already in the Gradle user home, so its speed says nothing about
  throughput.
- `FEATURE.md` corrected three stale figures: the alarm parity fixture has 23
  scenarios, not 17, and the device now pushes 19 rules across 4 devices rather
  than 13. The Fish and Hydroponics pages moved out of §18.5, having been seen
  on the device for the first time on 29 September 2026, and the prefill
  mechanism is recorded as §18.7.
- `PRD_PLTS_Monitoring_App.md` §7.1 marked two items done that 1.6.0 finished
  and dropped `weather_card.dart`, which no longer exists.

## [1.6.0] - 2026-09-28

### Added

- **Hydroponics and Fish pages, driven by a fourth ThingsBoard device.** The
  standalone CCTV tab is gone; its greenhouse sensors and its camera now share a
  **Hydroponics** tab, and a new **Fish** tab shows water quality from device
  `1c433980-ba25-11f1-b893-9dd5b4b6bde1` next to a second camera
  (`?src=cam2`, same allowlisted go2rtc host, separate setting and separate
  secure-storage key). The Fish page reads pH, temperature, turbidity and water
  level.

  The fish device is a first-class `AlarmDevice`, so `buildAlarmRules` arms
  `stale_fish` and `offline_fish` for it exactly as it does for the other three.
  That gives background notifications for the new device — "no fresh data" at ten
  minutes, "stopped reporting" at sixty — with no thresholds configured, which is
  what a monitor-only device cannot do. Three scenarios were added to
  `alarm_parity_vectors.json` and it was regenerated, so the Dart and Kotlin
  evaluators are still pinned to identical wording for the new device's messages.

  Threshold rules arrived in the same release. Settings gains a **Fish tank
  alerts** section (pH 6–8.5, water temperature 20–30 °C, turbidity ≤ 100
  NTU, each limit individually blank-able, and a blank limit is not
  monitored), and `buildAlarmRules` arms matching fish rules in both the
  Dart and Kotlin evaluators. The parity fixture grew to 23 scenarios
  pinning the shared wording, and the Fish grid on the dashboard now grades
  against the same `AlarmThresholds` the alarms use — so the page and the
  notification can never disagree about what the limit is.

- **The test suite grew from 223 to 273 — and two files that had never run now
  do.** `widget_test_environment_grid.dart` and `widget_test_live_power_card.dart`
  did not match the `*_test.dart` pattern `flutter test` collects, so every gate
  reported green without executing either. Renamed to `metric_grid_test.dart`
  and `live_power_card_test.dart`, they immediately failed five assertions: three
  looked for value and unit joined as one string ("25.0 °C") when the card
  renders them as two separate `Text` widgets, and two asserted the *previous*
  BMS's sign convention — negative power labelled "Charging" — which the
  replaced pack had already invalidated. All five now assert what the screen
  actually shows. New files pin what this release could have silently broken:
  `settings_save_regression_test` (the full write set and blank-means-null),
  `alarm_path_thresholds_to_rules_test` (thresholds → rules → native JSON for
  both alert groups), `battery_sign_convention_test` and
  `energy_report_service_test`; `metric_grid_test` also carries the
  `showGridColors` gate added in this release.

### Fixed

- **Touching a chart rebuilt the entire page view, twice per gesture.** The
  `PageView`'s `physics` was being driven by a `ValueListenableBuilder` wrapped
  around the whole `PageView`, so a chart's `onPointerDown` / `onPointerUp` — and
  the chart covers most of the PV, AC and Battery pages — rebuilt every cached
  page twice for nearly every scroll. The lock now lives in a
  `ChartGestureLockPhysics` that reads the flag when a drag *begins*, so nothing
  rebuilds. The base physics is delegated to rather than replaced, so page snapping
  survives; swapping in `NeverScrollableScrollPhysics` would have silently dropped
  it.

- **The offline cache was a read-modify-write race.** Each device's fetch wrote
  `cached_telemetry` on its own, so four devices fetching inside one `Future.wait`
  read the same snapshot and the last writer discarded the other three buckets.
  Measured at 32-77 ms per write on the test device, all of it on the poll's
  critical path. `fetchLatestTelemetry` no longer caches; `_fetchAll` merges the
  tick's readings and writes once, unawaited.

- **The WebSocket announced every frame as a change.** `_handleRealtimeTelemetry`
  passed `changed: true` unconditionally, so the revision counter rose two or three
  times a second — about thirty times more often than the ten-second poll the
  counter was designed around — and every bound widget in the tree rebuilt with
  it. It now compares the merged values the same way the poll path does.

- **`ConnectionHealthService` notified on every telemetry frame.** It had no value
  equality, and `lastSuccessfulUpdate` plus `latency` both change on every frame
  anyway. Equality now covers only the three fields the UI actually draws: status,
  transport and reconnect count.

- **`_alarmRules` was a getter**, so `buildAlarmRules` allocated roughly fifteen
  `AlarmRule` objects plus nine helper instances on every telemetry frame, before
  `_evaluateEnergyAlerts` could reject the update as unchanged. It is now rebuilt
  only when the thresholds change.

- **The bound-widget token omitted `_thresholds`**, so saving a new limit in
  Settings left the environment grid captioning its old range and the status strip
  judging against the old low-SOC threshold until the next telemetry change
  happened to rescue it.

- **A metric row announced itself to a screen reader as `Instance of 'MetricDef':
  45 %`.** `Semantics.label` interpolated the object, which has no `toString()`. It
  compiles and passes every lint.

- **`turbidity_keruh` is deliberately not requested.** The fish device publishes
  it as a boolean. `TelemetryPoint.fromJson` parses with
  `double.tryParse(value.toString()) ?? 0.0`, so requesting it would not throw —
  it would store `0.0`, and the card would show a confident `0` meaning the
  opposite of the truth, indistinguishable from a real zero reading. The numeric
  `turbidity_ntu` carries the same fact with a scale. `turbidity_voltage` (the
  sensor's own 3.3 V rail) is also not requested.

- **Nine source files had CRLF in the working tree where git stores LF**, which
  would have shown as a whole-file rewrite on commit. Normalised.

- **The battery sign convention is now the opposite of what it was, and it is
  pinned by a test.** The hero card labelled a discharging pack "Charging" at
  −22 W. The cause was not a rendering bug: the previous pack was measured on
  27 September 2026 reporting `−12.92 W` while its state of charge was *rising*,
  and the current pack reports `−28 W` while the state of charge is *falling*.
  `AGENTS.md` had recorded the risk in advance — the convention was measured on
  one device, and replacing the BMS would invert every battery display without a
  single red indicator. The mapping now lives in `lib/utils/battery_sign.dart`
  with the measurement in the reason string, so the next swap fails a test that
  says what to re-measure instead of quietly inverting the app.

- **The status strip was reading the battery sign a second time, differently.**
  It derived "Charging" from `current < 0` while the hero card read `power`, so
  the two contradicted each other on the same screen from the same pack, and the
  bare comparison had no deadband to sit in when the BMS idled at 0.00 A. It also
  picked a full-charging-battery icon from the SOC rather than from the direction,
  so the icon drew a charging pack while it was discharging. Both now go through
  `batteryChargeState` on the same key.

- **Saving Settings failed silently whenever any limit field was blank.**
  `save()` threw on `range.minKey!` for turbidity — its minimum is deliberately
  unbounded, so `minKey` is null — the exception escaped `_save()` before the
  SnackBar could be shown, and the screen neither popped nor reported anything:
  from the user's side the Save button simply did nothing. The same crash also
  swallowed the `true` that drives the dashboard to re-ship alarm rules, so an
  edited threshold did not reach the background evaluator until the next app
  restart. Both save and load loops are null-guarded, `_save()` catches and
  surfaces unexpected errors instead of dying quietly, and
  `settings_save_regression_test.dart` reproduces the symptom — reverting the
  guard fails it four times over. Verified on the device: Save pops to the
  dashboard and `run-as` shows the new fish and environment limits in
  `shared_prefs`.

- **Switching between the PV, AC and Battery sub-tabs showed the outgoing
  page's numbers.** All three sit at the same tree position, so `Bound` reused
  the cached child across the switch and kept rendering the old view until the
  next ten-second revision bump happened to change the token. `_visualToken`
  now includes `_powerSubNotifier.value`. Verified on the device: one second
  after an AC → PV switch the screen showed DC metrics only.

- **The CSV export button never showed "Preparing CSV…".** `sharingNotifier`
  was written but never listened to, so the button could not rebuild; it now
  listens, which also makes the double-tap guard visible instead of merely
  effective.

- **Tapping an alarm notification opened nothing.** The native side already
  stashed `EXTRA_ALARM_ID` and `AlarmBridge.launchAlarmId()` could read it, but
  no Dart code ever consumed it; `DashboardScreen` now drains it on init and
  routes to the alarm history. Not yet reproduced on the device — a genuine
  notification is needed to exercise it.

- **The environment alerts toggle now removes the grid's warning colours too.**
  It previously disabled only the background rules, so Settings could say
  alerts were off while the Hydroponics grid kept painting out-of-range
  readings red. `MetricGrid` now takes `showGridColors` from the same
  threshold the alarms read, and the "out of range" tag follows it; the
  "Stale data" tag deliberately does not, because a dead sensor is a fact
  about the data, not a configured limit.

- **The Fish dashboard page never showed the limits an alarm could be firing
  on.** It passed no thresholds to `MetricGrid`, so a pH of 14 rendered as an
  ordinary reading while the evaluator judged it against a limit the page never
  printed. It now grades and captions against the same `AlarmThresholds` as the
  alarms; a blank limit still shows no range.

- **A fish device that never saved its limits still armed the defaults.**
  `alarm_settings.dart` fell back to `defaultFish*` whenever a key was absent,
  turning "never configured" into "configured at the defaults" — a device the
  user had never set up would start alarming at numbers nobody chose. Absent
  now means null, matching the environment group, so the first Save is what
  arms the defaults.

### Changed

- **The Power tab is selected by a `ValueNotifier`, not screen `setState`.** A
  screen-level `setState` for the PV/AC/Battery selector cost 14-20 ms to the next
  frame against an 8.33 ms budget at 120 Hz, because it repainted the ambient
  background, the blurred app bar and every cached page to change one selector.
  Median is now 6 ms, measured on the device.

- **Entering the Power tab prefetches all three sub-views.** Switching used to
  leave the incoming card showing the previous fetch's numbers for as long as the
  request took, which read as the card being stuck. Three requests once on entry
  means every later switch lands on data that is already there; each switch still
  refreshes in the background.

- **The chart header says "Updating" while a request is in flight**, and nothing at
  all otherwise. The silence was the problem: a deliberate stale-while-revalidate
  is correct, but with no indication at all it is indistinguishable from a frozen
  card.

- **The OpenWeatherMap integration is gone, along with the location permission
  it needed.** The Overview card is removed, along with `WeatherService`, its
  fifteen tests, the `geolocator` dependency, the Settings section that asked for
  an API key nothing consumed, and `ACCESS_FINE_LOCATION` /
  `ACCESS_COARSE_LOCATION` from the manifest. Light (`lux`) already lives on the
  Hydroponics page and PV output already lives in Energy analytics, so the card
  showed numbers the user could see twice. What is lost is outdoor temperature,
  wind, cloud and any forward-looking forecast; `power_dc` and `lux` are
  measurements, not predictions. The one credential this app stored outside secure
  storage was that API key.

- **Bottom navigation is four tabs, not six.** PV, AC and Battery became one
  "Power" tab with a segmented selector, because they are three views of a single
  electrical system. Material 2 documents 80 dp as the minimum width of a
  bottom-navigation destination in portrait and this phone is 380 dp, so six tabs
  needed 480 dp; "Hydroponics" measured 62 dp in a 60 dp slot and was visibly
  truncated. Material 3 names the limit and the symptom together: "the elements
  may collide and there likely won't be enough space for translated text." Both
  versions forbid the alternatives — "Don't shrink text to fit on a single line",
  "Don't truncate text", "Don't reduce the type size to fit more characters into a
  destination label" — and both independently forbid the per-tab colour that this
  project had already reverted. Four tabs need 320 dp and leave a slot spare.

- **`EnvironmentGrid` is now `MetricGrid`, and takes its readings as a
  parameter.** It was one widget hardcoded to five greenhouse sensors, laid out by
  hand as a 3 + 2 shape with `_envSpecs[0]` through `_envSpecs[4]` written out
  individually, so a sixth sensor meant rewriting the layout and a forgotten index
  renders nothing at all. The fish page uses it with two columns, and `decimals`
  is per spec rather than a fixed 1 — which mattered immediately: pH is
  logarithmic and wants two places, and an NTU turbidity sensor printing
  "2395.5" implies precision it does not have.

- **The two hardcoded switches mapping a telemetry key to its configured limit now
  live on `AlarmThresholds` as `minFor` / `maxFor`.** They were duplicated inside
  the grid, once to colour a card and once to caption it, and both ended in
  `_ => (null, null)` — safe for the three keys that had a case, and silent for
  anything added later.

- **A `RenderFlex` overflowed by 12 pixels in Settings → Background checks.** Two
  `OutlinedButton.icon`s sat in a `Row` with neither child flexible, and the
  second one only appears when the app is *not* exempt from battery optimisation,
  so it overflowed for exactly the user who had something to fix. Now a `Wrap`.

- **"Battery optimisation" ran into its own value.** The label column was a fixed
  150 px and that label is a couple of pixels wider, so the row read
  "Battery optimisationActive". A fixed gap now sits between them, which also
  stops the next label to exceed the column from colliding the same way.

- **`ThingsBoardApi.deviceKeysById` is the canonical device list.** The REST
  shortcuts, the WebSocket subscriptions, the offline cache split and the key-set
  tests were four hand-written lists that had to be extended in step. A device
  added to the constants but missed in `splitCachedTelemetry` polled live and
  correctly, then came up empty from the offline fallback — no error, no log. The
  tests now derive from the map, and a new test asserts every key of every device
  reaches its own cache bucket, so a fifth device cannot silently drop out of
  coverage either.

- **The environment grid moved from Overview to the Hydroponics tab.** The
  readings and their limits are unchanged, so no alarm behaviour changed; Overview
  is now only what the power system is doing.

- **Settings → CCTV source has two URL fields**, labelled "Hydroponics camera URL"
  and "Fish camera URL". Both go through the same host allowlist and both are
  validated on save.

- **The dead-code inventory in `FEATURE.md` §18.2 was worked down.** Roughly
  two dozen symbols with no callers were deleted rather than left to rot —
  `SeriesStats.average`, `batteryCapacityKwh`, `ExportButton.onShare`,
  `AlarmBridge.isScheduled`, `AlarmTokenStore.updateAccessToken`,
  `AlarmBridgeStatus.configSavedAt`, the never-written connection-status timer
  fields, `solarProductionFactor`, and the unreachable `ConnectionHealth`
  status `error` among them. Two entries on that list turned out to be
  call-site problems rather than dead code: `clearCctvUrl` now runs on logout
  and `launchAlarmId` now has its consumer.

### Known issues still open

- **The dashboard still feels sluggish on the test device.** See `progress.md` for
  every measurement taken, every tool that turned out not to work, and the three
  candidates that remain. This is unresolved and is the first thing to pick up.

- **The Offline fallback only ever ran on a cold start.** Not touched this
  session, but the race above is the same failure family: the page polls live,
  shows correct numbers, and the offline path comes up empty with nothing logged.

## [1.5.0] - 2026-09-27

### Changed

- **The app is now entirely in English.** The interface had been a mix: alarm
  messages, the energy card, the status strip and the environment grid were
  Indonesian while the settings screens, the detail pages and the metric labels
  were English, so the same screen could read two languages. Terms are chosen once
  and used throughout — "limit" for a configured bound, "stale" for telemetry that
  has stopped being fresh, "out of range" for a breached threshold, "AC grid" for
  the mains supply, "Live" for the realtime connection. The alarm message strings
  changed too, in both `formatAlarmMessage` and `AlarmMessageFormat.kt`, and
  `alarm_parity_vectors.json` was regenerated so the Dart and Kotlin evaluators are
  still pinned to identical output.

### Fixed

- **The alarm banner now collapses instead of vanishing.** It was rendered by a
  plain conditional, so an alarm clearing made the entire Overview jump up by the
  banner's full card height in a single frame with no transition, which reads as a
  glitch rather than as a condition ending. Every banner now goes through a
  switcher that fades it, lifts it slightly and shrinks its height continuously.
  The collapse needs a `SizeTransition` and not just a fade: the switcher stacks
  the outgoing banner under the incoming one, and a stack takes the largest of its
  children, so a banner that only faded would hold its full height for the whole
  exit and then snap to zero on the last frame. The exit is longer than the
  entrance — an alarm appearing deserves to be noticed quickly, one clearing is
  information but does not need to interrupt. A change to *which* alarms are active
  cross-fades the text as well as resizing.
- **The chart's min and max are no longer truncated.** "↓ 6.98 ↑ 21.43 V" on one
  line overflowed a third of the card width and ellipsised to "109....", losing the
  one figure a reader cannot afford to lose. Each figure gets its own line.
- **The chart Y axis carries real values again.** Normalising each series to 0–100 %
  of its own range was tried so all three would fill the plot height. It was
  reverted at the user's request: a reader who sees "0%, 50%, 100%" has to look up
  three separate scales in the legend to learn anything, and on the PV and battery
  pages the three quantities are within an order of magnitude anyway, so the raw
  axis was already readable. Only the AC page has power two orders above current,
  and a flat trace there is honest rather than broken.
- **The chart no longer renders an empty plot.** Passing an empty `dashArray` to
  fl_chart does not mean "solid", it means "draw nothing": the pattern is walked by
  `pattern[index % pattern.length]`, so a zero-length list produces no output at
  all. The card came up with correct axes, a correct legend and correct statistics
  and no lines, which is the worst shape of bug to spot on a device. Leaving the
  field unset is what draws a solid line.
- **Overlapping chart traces are both visible.** Current and power are
  proportional, so their lines usually coincide exactly and the one drawn last hid
  the other completely. The lines are slightly transparent, so a trace underneath
  shows through.
- **The "Live" indicator takes the accent rather than green**, for the same reason
  as the rest: a green badge for a condition that is normally fine is a second
  colour system next to the theme.
- **The device charts plot voltage, current and power together again.** Splitting them behind a metric picker was wrong: seeing all three at once is the reason the chart exists. They are drawn raw against one shared, dynamic Y axis. The series colours are fixed red, green and blue and the lines are solid; deriving three series from the theme accent as lightness steps, and then telling them apart with dash patterns, were both tried and both rejected, because three obvious colours need no legend decoding and a dashed trace on a phone reads as broken.
- **The card outline now follows the theme accent.** It was a neutral white or black hairline, so a card in an amber theme held amber numbers inside a cold grey frame and the palette read as two systems. It is taken from `colorScheme.primary` rather than a new parameter, because the theme already carries the accent and threading a `seedColor` through every call site would only let the two disagree later.
- **Green no longer appears on a healthy dashboard.** The status strip coloured the value text, the battery icon and the tick green even when nothing was wrong, and every environment card in range got a green border and a green range caption. In an amber or cyan theme that put a second colour system all over the page. Now only a breach is coloured; a healthy reading keeps the card's accent-tinted outline and ordinary text, which is the same rule already applied to the environment grid's verdict.
- **`SegmentedButton` no longer fills the selected segment with a muddy tone.** Material uses the colour scheme's `secondaryContainer`, which `ColorScheme.fromSeed` desaturates until it reads as neutral — invisible with the default green, an olive block on a near-black card with "Solar amber". All three segmented buttons in the app now take their selected fill and text from the accent through a `SegmentedButtonThemeData`, since the seed is available where the `ThemeData` is built.
- **The energy comparison no longer prints "−100% from the previous period"** when the previous period held 0.01 kWh. That figure is arithmetically right and reads as a catastrophe; below 0.1 kWh both periods are rounding noise against a value displayed to two decimals, so the card says what actually happened instead.
- **The alarm banner appears on the Overview page only.** A threshold breach is a fact about the greenhouse, not about the tab being looked at, and repeating it above the PV, AC, Battery and CCTV pages pushed four already-read lines above the content the user opened a tab to see. Connection state still shows on every page, because a page of numbers that cannot be trusted needs to say so wherever it appears, and the alarm count is in the status strip on every page.
- **The date range picker is now localised in English.** Its chrome comes from a `Locale` argument rather than from the strings passed to it, so it was the last Indonesian surface in the app: day headers and month names inside an otherwise English dialog.
- **The exported CSV is named `energy_report_*.csv`** rather than `laporan_energi_*.csv`. The filename reaches the user through the share sheet, so it is part of the interface.
- The energy comparison caption is short enough not to wrap. The two tiles sit side by side and wrap independently, so a caption that wraps on one of them leaves the pair with mismatched heights.
- **The hero card now shows where the power is going** instead of three shortcut capsules. The capsules showed PV output, AC load and battery charge, and all three were already on that same card: the PV figure is the number directly above in the hero, the battery charge is the gauge beside it, and as navigation they duplicated the bottom bar, which already has PV, AC and Battery tabs. Their progress bars were the weakest part of all — PV was divided by a hard-coded 300 W and the load by 2000 W, so a bar could read full while the number beside it was wrong. The strip reads solar, house and battery, draws the house's share of the array's output as a proportion, and states in one line whether the array is covering the load.
- **The battery figure comes from the BMS's own `power` key**, not multiplied out from voltage and current. The device reports all three. Deriving it gave two separate wrong answers: the product collapses to zero whenever current reads 0.00 A, which this BMS does report while idle, and the two figures drift apart whenever the pack is not at its nominal voltage.
- **The battery state is a three-way split, not a boolean.** The pack genuinely moves between charging, standby and discharging, and at zero current the sign of the reading is pure noise, so the strip would flip between "Charging" and "Discharging" several times a minute while asserting a direction the data does not establish. Below 1 W it says "Standby" and claims nothing.
- **The hero card prints the battery figure with the sign the device reports.** Negating it so the card read "Charging 12 W" was tried and reverted: the Battery page, one tab away, says "Power -12.92 W", and making the hero prettier at the cost of two screens disagreeing about the same measurement makes the app less trustworthy. The label carries the direction and the number matches the other page exactly.
- **"PV Output" no longer appears three times on one card.** It was the card header, the caption directly under the big number, and the first capsule's label. The header now names the card ("Live power") and the duplicate caption is gone; the capsule label is the one that had to stay, because three identical tiles in a row are indistinguishable without it.
- **The split bar under the power flow actually draws.** `SizedBox(height: 5)` alone leaves `maxWidth` at infinity, so the `Row` beneath it was unbounded and its `Expanded` segments resolved to nothing — the bar rendered as empty space with no exception to notice.



- **Fixed a background check that could be killed mid-write.** The worst case ran about 48 seconds against the ~10 seconds a manifest `BroadcastReceiver` is allowed, and the slow path was the *expected* one whenever the access token had expired. Being killed between writing credentials and saving the active set made the next tick treat the same alarms as new, which is the duplicate notification the design exists to prevent. A wall-clock budget is now enforced, per-request timeouts are capped below it, and the token refresh is skipped rather than started when the budget is already spent.
- **Fixed three independent check runners with no mutual exclusion.** The scheduled receiver, the "check now" button and the debug trigger each ran on their own thread, so two could read the same active set and both decide an alarm was new. One process-wide guard now covers all three.
- **Fixed "check now" silently doing nothing.** The manual trigger inherited the foreground stand-down, so pressing the button while looking at the app skipped the check. It now bypasses the stand-down, which is what a user pressing it means.
- **Fixed `allowBackup="false"` not covering device-to-device transfer.** Since Android 12 that attribute disables cloud backup but not D2D, so a phone-to-phone migration would have carried the plaintext preferences to the new device, including the OpenWeatherMap key. `dataExtractionRules.xml` and `backup_rules.xml` now exclude everything from both paths.
- **Fixed the ThingsBoard host being validated only by an `https://` prefix.** A prefix test accepts *any* TLS host, so the first time the base URL became configurable — a normal request for an app like this — a mistyped or malicious host would have received a live bearer token. It is now an exact host allowlist, rejecting userinfo, non-443 ports and paths, which mirrors what `parseAllowedCctvUrl` already did correctly.
- **Fixed the OpenWeatherMap key going into logcat by accident.** An `org.json` parse error on the token refresh path embeds a fragment of the unconsumed response, which for that request is the JWT. Only the exception class is logged now.
- **Removed two unused permissions.** `WAKE_LOCK` was never acquired and `ACCESS_BACKGROUND_LOCATION` is never requested at runtime; the second is one a store review treats as sensitive.
- **Fixed background alarms never firing at all.** `android_alarm_manager_plus` requires its `AlarmService` and `AlarmBroadcastReceiver` to be declared in the app manifest, and neither was. The 15-minute alarm was therefore registered but never delivered, which is why `progress.md` recorded "never a real alarm appeared" as untested rather than broken. The dependency is removed entirely and replaced by native Kotlin; see the Added entry below.
- **Fixed three light-mode colours that claimed to pass WCAG AA and did not.** Measured against the surfaces they are actually drawn on rather than against white, the amber warning colour was 4.02:1 and the secondary-text grey 4.29:1, both below the 4.5:1 that AA requires for text at 9–11dp; green was only 4.67:1. They are now 5.21:1, 5.11:1 and 5.19:1. The earlier claim of compliance had been measured against the wrong surface, and `test/color_helpers_test.dart` now checks every colour against the real values from `main.dart` and `liquid_glass.dart`.
- **Fixed a duplicate notification on every cold start.** The active-alarm set was read from the native module *asynchronously, after* the dashboard had already decided an alarm was new, so opening the app re-announced alarms the background had already reported. The set is now read before the first evaluation, and notifications are held back until it arrives. Covered by `test/alarm_rules_test.dart` via `newlyActiveSignals`.
- **Fixed the background alarm being dropped by vendor power management.** The repeating alarm fired six times and then silently disappeared from `dumpsys alarm` on MIUI/HyperOS, with `com.miui.powerkeeper` in the same output, so alarms simply stopped arriving with nothing to indicate why. A second `setAndAllowWhileIdle` trigger, re-armed after every run, now backs it up.
- **Fixed a failed poll being reported as stale telemetry.** A device that produced no reading raised a `stale_*` alarm, so a network outage or a dead token turned into three misleading alarms instead of silence. An unread device now produces nothing, while a device that has stopped reporting still alarms — that is the distinction the alert was meant to draw.
- **Fixed background alarm credentials never reaching the native side.** The access token was sent inside the config payload while the native code read it as a top-level argument, so every check logged "no credentials stored" and did nothing. The credentials are now sent separately, which also keeps them out of the config file written to disk as plain JSON.
- Fixed `WeatherForecast.fromJson` parsing One Call API payloads with `WeatherData.fromJson`, which read `main.temp` / `wind.speed` / `coord` — keys that do not exist in that format. Added `WeatherData.fromOneCallJson` to correctly parse One Call entries (scalar `temp` in hourly, `temp.day` object in daily, snake_case `wind_speed`, no per-entry `name` or `coord`).
- Fixed `_estimateSolarIrradiance` to handle both current-weather (`clouds.all` nested) and One Call (`clouds` scalar) formats.
- Fixed splash screen logo not being rounded — wrapped `BrandLogo` in `ClipRRect` for consistency with the biometric unlock screen.

### Added

- **Added native background alarm checking** in `android/app/src/main/kotlin/tech/mbkm/energrow/alarm/`. An `AlarmManager` repeating alarm wakes a `BroadcastReceiver` that does the ThingsBoard reads with `HttpURLConnection` and posts notifications with `NotificationCompat`, so no Flutter engine is started. A background tick costs single-digit MB of RAM instead of the tens of MB a background Flutter isolate holds resident. Devices are polled in parallel and not retried, which fits the roughly ten seconds a manifest receiver is allowed; a full check measures around 0.45 s on the test device, against a worst case of over three minutes for the old sequential, retried Dart poll.
- **Added a second alarm trigger, `setAndAllowWhileIdle`, re-armed after every run.** A repeating alarm is the first thing vendor power managers remove: on the test device the repeating alarm fired six times and then silently disappeared from `dumpsys alarm`, with `com.miui.powerkeeper` in the same output, leaving alarms that were simply never delivered. The Doze-exempt trigger repairs that.
- **The check now runs every minute**, down from fifteen, and stands down while the app is in the foreground. A greenhouse alarm is only useful while the condition still is, and a check is now cheap enough to afford it. The stand-down avoids polling ThingsBoard twice over while the dashboard is already evaluating the same rules every ten seconds.
- Added `AlarmDebugReceiver`, declared only in `src/debug/AndroidManifest.xml` and refusing to act unless the app is debuggable, so one background check can be triggered on demand. Verifying the notification otherwise means waiting for a genuinely new condition, which can take hours.
- Added `lib/utils/alarm_rules.dart` as the single source of truth for what counts as an alarm. `buildAlarmRules` turns the user's thresholds into a rule list, `evaluateAlarmRules` runs it, and `alarmRulesToJson` ships the same list to the native module. The dashboard banner and the background notification now evaluate one rule list, so a threshold edited in Settings changes both and the wording cannot drift between the two.
- Added environment limits to the background check. Previously the periodic check only looked at low SOC and stale telemetry, so temperature, humidity and TDS alarms never produced a notification no matter how they were configured.
- Added `android/app/src/test/resources/alarm_parity_vectors.json`, replayed by `test/alarm_parity_test.dart` and by `AlarmParityTest.kt`, which pins the Dart and Kotlin evaluators to the same messages. The two implementations exist because Dart is not running during a background check; the shared fixture is what keeps them honest. Regenerate with `dart run tool/generate_alarm_parity_fixture.dart`.
- Added `test/alarm_rules_test.dart` — 20 tests covering rule construction, evaluation, freshness gating, announce-once semantics and JSON round-tripping, including the guard that TDS keeps no upper bound.
- **Added a "device has stopped responding" alarm** for every device, critical and separate from the stale warning. Ten minutes of silence in an MQTT pipeline is a hiccup; an hour is a sensor or gateway that has stopped, and the two need different responses. The threshold is configurable in Settings and defaults to 60 minutes, deliberately far above the stale window so a brief gap never escalates on its own.
- **Added working environment limits out of the box.** Temperature 15–35 °C, humidity 40–85 %, TDS ≥ 800 ppm, and environment alerts now default to on. Previously the feature existed but shipped empty, so the grid showed five numbers with nothing to read them against. The values suit a tropical greenhouse and live in `AlarmThresholds` as named constants, with the Settings screen and the engine both reading them.
- **Added a Background checks section to Settings** showing whether the check is armed, whether credentials are stored, when it last ran and what it found, plus a "check now" button and a shortcut to the battery optimisation screen. This exists because the failure mode is invisible by construction: a dropped alarm looks exactly like nothing to report, and this project spent several sessions guessing between the two.
- Added `AlarmBridgeStatus` and the bridge `status` / `checkNow` / `isScheduled` / `isIgnoringBatteryOptimizations` calls, so a background check can be inspected instead of guessed at.
- Added a second notification channel for critical alarms, letting the user silence warnings while keeping a low-battery alert.
- Added `WeatherService.dispose()` to release GPS handle and cached coordinates. Dashboard now calls it in its own `dispose()`.
- Added `test/weather_service_test.dart` — 15 tests covering both current-weather and One Call API parsing, serialization round-trips, and computed properties.
- Added `test/thingsboard_realtime_service_test.dart` — 21 tests covering service lifecycle, device configuration, `TelemetryPoint`, and `DeviceTelemetry`.
- Added `test/color_helpers_test.dart` — 8 tests pinning that `metricColor` and `strongMetricColor` never rotate hue away from the accent the user picked, and that every text colour in the file clears AA on the real surfaces.
- **Environment cards now show whether each reading is inside its limit**, with the configured range printed under the value and a single verdict for the whole grid. Five numbers with nothing to read them against is what the feature looked like before; a reading of 38 °C was visually identical to a healthy one until an alert banner appeared elsewhere on the screen. A stale sensor now says so instead of claiming everything is fine.
- **One status strip replaces three stacked banners.** Offline mode used to show a green "polling active" line directly above an orange "offline" line — two opposite claims about the same connection, stacked before any content. Precedence is now failure > offline > alert > stale, and the strip no longer auto-hides after three seconds, because a 3-second flash was the only connection indicator there was.
- **The dashboard's date strip now states the selected day** rather than the span of the seven chips. Tapping a chip left the label describing a range that no longer matched the selection, while the detail pages showed the correct single day, so two screens disagreed about the same state.
- **Telemetry values no longer all show two decimals.** A count and a percentage do not have hundredths, so the battery page read "Cycles 12.00" and "State of Charge 45.00 %". `MetricDef` takes a `decimals` and SOC, cycles and power now use one. DC and AC metrics are also labelled by side, so "Voltage" on the PV page is no longer ambiguous.
- **A fresh-data indicator is now always visible** on the hero card, quiet when current and amber when stale. There was no persistent sign of liveness anywhere in the Overview, so a dashboard that had quietly stopped updating looked exactly like a live one.
- **Metric colours follow the chosen accent, with no automatic variation.** A per-index hue rotation of 40° was added so the PV, AC and battery pages would be told apart by colour, and it was reverted at the user's request: a colour the user did not choose is a colour they cannot predict, and the app looked arbitrary rather than themed. The pages are distinguished by title and icon instead. If per-page colour is ever wanted it belongs in Settings as an explicit choice, not as a default.
- **The in-app alarm notice is now only the banner above the greeting.** The same messages were also shown in a `SnackBar`, so every alarm was stated twice — once where the user was already looking and once over the bottom of the screen, covering the energy card and the navigation bar. Worse, the `SnackBar` re-fired on any change to the message set rather than on any new alarm, so a reading drifting in and out of range popped a bar every few seconds while the persistent banner simply stayed.
- **Environment cards no longer carry tick and warning glyphs.** Out of range was signalled three ways on one card at once — a tick, a warning triangle and a coloured border — which turned a sensor reading into a checklist item. The border and the range caption remain, and the grid's permanent green "semua normal" state is gone; the header now speaks only when something is wrong.
- **Secondary text now passes WCAG AA.** The `Colors.white54` / `Colors.black45` pair measured about 3.4:1 on the light surface for text as small as 9dp, in 22 places. A contrast-checked pair replaced it, and small status colours moved off the Material defaults, which measure 2.3:1 at that size.
- **A white border on a white card is now a faint black one**, matching what the date chip already did in the same file.
- The four accent colours are unchanged. `Ocean cyan` and `Forest teal` do sit 19° apart and render similarly, and moving `Ocean cyan` to separate them was tried and reverted: a user who had already picked it would have silently been given a different colour, which is worse than two swatches looking alike.
- The glass toggle is now named for what it does. "Smooth Glass Mode" turned the blur *off* when switched on, the opposite of what the name promised.
- An empty or loading chart no longer reserves a full plot's height, and chart axis labels moved from 8dp to 10dp.
- The full battery capacity was already being fetched and displayed nowhere, so "Remaining Capacity 50.0 Ah" appeared with nothing to compare it to. It now sits next to the pack size.
- Health messages and transport state reach the UI in the interface language rather than as raw model strings.
- The environment range keys are named from `SettingsKeys` by the settings controller rather than re-derived from a sensor id, so the two can no longer drift apart uncaught.

- **Alarms are reported once per occurrence, not on every check.** The active alarm set is shared between the dashboard and the native module, so an ongoing low-battery condition produces one notification rather than one per interval. The previous implementation de-duplicated with a five-minute timer, which is *longer* than the check interval and so never actually prevented a repeat.
- Background alarm tokens are stored encrypted under a hardware-backed AndroidKeyStore key instead of being readable only by `flutter_secure_storage`, which cannot be reached without a Flutter engine. Dart keeps the canonical copies and re-pushes on launch; a refresh performed in the background updates only the native copy.
- The background check renews its own access token on a 401 and stops itself if the refresh token is rejected, so an expired session no longer looks like three unreachable devices.
- A device that produced no reading no longer counts as stale. A failed poll is missing data, not a condition, and treating it as stale turned a network outage into three misleading alarms.
- Removed the `android_alarm_manager_plus` dependency and its manifest receiver, and dropped the Android plugin count from 12 to 11.
- Moved `AlarmType`, `AlarmSeverity` and `AlarmRecord` from `alarm_history_service.dart` to `lib/models/alarm_record.dart`, so the rule engine depends on a model rather than on a service that does I/O.
- Promoted `alarm_helpers.dart` from `screens/dashboard/utils/` to `utils/`, now that the native module and the dashboard both read it.
- Added `lib/services/alarm_settings.dart` so the alert defaults are written in one place. They were previously repeated in the settings controller, the dashboard and the background service, which is how the same setting came to default to different values in different readers.
- Alarm history merges the records the background check wrote with the ones the dashboard wrote, and acknowledging or resolving now applies to both. The two stores stay separate because `shared_preferences` encodes a `List<String>` as a Base64 Java-serialized blob that the native side would have to reproduce byte for byte.
- All user-facing text in `alarm_history_screen.dart` is now English (title, dialog, buttons, filters, status badges, menu actions, empty state, month names).
- Documented battery power sign convention in `energy_forecast_service.dart` — `.abs()` is used because BMS vendors disagree on charge/discharge sign.
- Made dashboard overview page more compact: reduced card spacing from 12–20px to 8px, reduced internal padding across all dashboard cards (LivePowerCard 18→14, DualStatusCards 14→10, EnergySummaryCard 14→10, WeatherCard 12→10), changed EnvironmentGrid layout from 2+2+1 to 3+2 for better space efficiency.

### Removed

- Removed the `geocoding`, `csv` and `cupertino_icons` dependencies. None of them was imported anywhere, and `geocoding` was still pulling a full Android plugin into the build for no reason — it had even been upgraded once specifically for Android 14 compatibility, for a code path nothing used.
- Removed `WeatherService.searchCities`, `AlarmHistoryService.getAlarmsSince` / `acknowledgeAlarm` / `resolveAlarm` / `_find`, `alarmValueFromId`, `clearCctvUrl`, `fetchHistory` and the `DashboardShortcut` widget, plus the unused `EnergyForecastCard` file. All were verified to have no callers before removal.
- Removed the 22 telemetry key literals duplicated in `telemetry_helpers.dart`. They were written out a second time despite a comment on the originals stating that one source makes it impossible for them to come apart, which is exactly what would have happened.

### Documentation

- Added `AGENT_PLAYBOOK.md`, a working manual for agents on this repo: the
  mandatory reading list with the five questions it should answer, when a subagent
  is worth spawning and when one `grep` is enough, the six rules about subagents
  that prevent file collisions, the environment numbers that decide whether two
  builds can run at once, the hard rules, ten harness and domain gotchas that have
  cost real time, the verification gates including what can only be checked on a
  device, and the commit protocol. It is written from what actually happened this
  session, including the harness failures: file content mutating on write,
  backticks inside a shell-interpreted `python3 -c` silently deleting a filename,
  line-index edits landing on the wrong line, and a long `write` call truncating
  mid-document.
- Added `FEATURE.md`, an inventory of what is actually implemented, verified
  against the source rather than against the other markdown files. Each entry says
  where the feature lives and what proves it works, and §18 lists the gaps: nine
  functional ones, twenty-odd dead or unreachable symbols, seven behaviours that
  are counter-intuitive rather than wrong, five test gaps, and six things that no
  one has yet seen on a device. The reason it exists is in its own header: three
  label regressions in one session passed `flutter analyze`, the release build and
  every existing test, and were only found by looking at the screen.

- Documented the native alarm module in `AGENTS.md`: the one-rule-list contract, why `AlarmManager` is inexact and why there are two triggers, the foreground stand-down, the token handover, the debug trigger, and the parity fixture that keeps the two evaluators in agreement.
- Rewrote `README.md` around the background alarm capability, with the measured cost of a native check against a Flutter isolate, and corrected the stale "push notification belum tersedia" claims.
- Corrected `PRD_PLTS_Monitoring_App.md` §4.5, §6 and §7, which still claimed no alert reaches the user while the app is closed.
- Replaced `progress.md` §10.5, which had recorded the old Dart alarm as merely untested. It was broken, and the reason was a missing manifest declaration.
- Recorded the security review outcome in `AGENTS.md`, including the two findings that were real defects in brand-new code: the receiver time budget and the missing mutual exclusion between check entry points.
- Updated `AGENTS.md` with current test coverage (227 Dart tests, 11 Kotlin unit tests), coordinated upgrade blocker for `package_info_plus` / `share_plus`, and `WeatherService.dispose()` note.

# Changelog

All notable changes to this project are documented here.

## [1.4.0] - 2026-09-26

### Added

- Added `dart_test.yaml` serialising the test suite, which keeps the Dart compiler and the test isolate from competing for memory on low-RAM machines
- Added `SettingsKeys` (`lib/models/settings_keys.dart`) as the single source of truth for `SharedPreferences` keys shared by the Settings screen, Dashboard, and background alarm service
- Added `SettingsController` (`lib/screens/settings/settings_controller.dart`) owning all settings state, validation, and persistence
- Added `CctvStatus` (`lib/screens/cctv/utils/cctv_status.dart`) deriving the stream state from the player flags
- Added `PeriodTotals` plus `bucketsForPeriod`, `previousPeriodTotals`, `totalsOf`, and `totalSampleCount` (`lib/screens/energy_report/utils/period_buckets.dart`)
- Added `niceStep` and `niceTimeStep` (`lib/screens/dashboard/charts/chart_data.dart`) for human-friendly axis intervals
- Added `formatAxisDate` and `formatAxisTick` for axis ticks that span more than one day
- Added unit tests for the extracted settings validation (`test/settings_validation_test.dart`)
- Added unit tests for the CCTV status model and the `parseAllowedCctvUrl` host allowlist (`test/cctv_test.dart`)
- Added unit tests for the energy report period and chart helpers (`test/energy_report_helpers_test.dart`)
- Added unit tests for the chart axis interval logic (`test/chart_bounds_test.dart`)
- Added widget tests for the settings browser (`test/settings_screen_test.dart`) covering category listing, section drill-down, back navigation, and CCTV URL rejection
- Added unit tests for the extracted dashboard helpers (`test/dashboard_helpers_test.dart`) covering history window resolution, sampling intervals, energy integration, cached telemetry partitioning, and telemetry comparison
- Added `glassDividerColor` helper so divider tinting stays consistent across glass cards
Added `AGENTS.md`, a working-notes file for coding agents covering the build
environment, the `dl.google.com` throttling workaround, and the project conventions
that are easy to get wrong.
Added `.gitattributes` forcing LF line endings, plus `core.autocrlf = input` on this
repository, so the 126 files that were showing as modified purely because they had
CRLF in the working tree no longer do.
Added `SettingsKeys` usage notes and the `dependency_overrides` block that keeps
`path_provider_android` on 2.2.23.

### Changed

- Changed the Android `applicationId` and `namespace` from `com.example.plts_monitoring` to `tech.mbkm.energrow`, and moved `MainActivity` to the matching package path
- Changed chart axis intervals to snap to round values, so a 24-hour view now labels ticks on the hour instead of at arbitrary offsets such as 02:10
Pinned `path_provider_android` to 2.2.23 via `dependency_overrides`. Version 2.3.0
rewrote its Kotlin side on top of the `jni` package, which forced a CMake and NDK
toolchain to build a 130 KB shared library. This drops the Android plugin count from
14 to 12 and removes `libdartjni.so` from the APK. `share_plus_platform_interface`
depends on `path_provider` unconditionally in every published version, so the chain
cannot be cut at the app level. Both versions target the same
`path_provider_platform_interface ^2.1.0`, so the plugin API is unchanged.
Removed `ndkVersion = "30.0.16248370"` from `android/app/build.gradle.kts`. Nothing in
the app compiles native code, and the pin only made AGP fetch a second, divergent NDK
copy. Note this does not stop the download: AGP still installs Flutter's default NDK
during configuration. Verified with no `ndk/` and no `cmake/` in the SDK: it fetches
28.2.13676358, then produces zero `.o` files and no `build.ninja`.
Lowered the Gradle JVM heap in `android/gradle.properties` from `-Xmx8G`
`-XX:MaxMetaspaceSize=4G` to `-Xmx1536M`, plus a 1 GB Kotlin daemon. The old values
reserved 12 GB on a machine with 7.1 GB of RAM, so the daemon could never be
satisfied and was at risk of being OOM-killed.
Changed the Gradle wrapper distribution from `gradle-9.3.1-all.zip` to `-bin.zip`,
saving roughly 1.2 GB of download since only the binaries are needed to build.
Ignored `/.kotlin` in `android/.gitignore`; the Kotlin Gradle plugin writes session
state and incremental caches there during every build.

### Fixed

- Fixed telemetry chart axis labels being clipped or overlapping at the plot edges, by nudging the first and last bottom-axis labels back inside the chart
- Fixed multi-day chart ranges labelling every tick with a clock time, which made a week view show `00:00` repeatedly; ticks now show a date instead
- Fixed a test in `cctv_test.dart` that called `tester.getSemantics` without enabling semantics, which could hang the isolate and mark every later test in the file as "did not complete"
- Fixed that same test matching a `Semantics` node owned by `Scaffold` instead of the one under test
- Fixed the CCTV stream URL set in Settings never taking effect: it was written to `SharedPreferences` while the Dashboard reads it from secure storage, so the edit was silently discarded. Settings now persists it through `saveCctvUrl()` and loads it through `loadCctvUrl()`
- Fixed a duplicate `defaultCctvUrl` constant in Settings that shadowed `defaultAllowedCctvUrl` from `cctv_url.dart`
- Fixed the embedded and full screen CCTV layouts maintaining two copies of the video/standby/loading/error stack, which could drift apart
- Fixed the expanded and collapsed glass nav bars keeping duplicate icon/label literals by sharing one `kNavDestinations` list

### Removed

- Removed the unused `active` parameter from `CctvScreen`

### Documentation

- Updated the README Known Issues: the CCTV stream is now live, so the pending `go2rtc` note was replaced with the actual caveats (WebView battery cost while polling continues, rounded Y axis labels)
- Documented that changing `applicationId` requires uninstalling the previous build, and that the stored session does not carry over
- Recorded the features verified on a physical Android 16 device
Consolidated this changelog. It had accumulated three `[Unreleased]` headings and three
conflicting `1.3.0` headings from an unclean merge. The three `1.3.0` blocks were all
part of the tagged `v1.3.0` release and are now merged into one section; the block
headed `[Unreleased] - 2026-09-25` was verified against git tags and belongs to 1.3.1,
since the realtime telemetry, connection health, energy forecast, and background alarm
commits all landed before the `v1.3.1` tag.
Recorded in `AGENTS.md` that the NDK download cannot be avoided from the project side:
`FlutterPlugin.kt` calls `forceNdkDownload` unconditionally for every app project, and
that function fabricates a synthetic `externalNativeBuild` so AGP believes an NDK is
required. There is no opt-out flag.

### Refactoring

- Refactored CCTV screen from 480 lines to 319 lines (-34%), sharing one `CctvViewport` between the embedded and full screen layouts
- Refactored Energy Report screen from 233 lines to 174 lines (-25%), moving period bucketing and comparison totals into pure helpers
- Extracted `_SelectedBucketReadout` and `_BucketStepper` from the energy report chart card, which had duplicated the touched-index clamping in two listeners
- Replaced the opaque `(double, double)?` totals record with a named `PeriodTotals` class
- Simplified `calculateMaxY`, which used a four-branch nested ternary fold
- Refactored Settings screen from 754 lines to 157 lines (-79%), splitting it into a controller, shared field widgets, and one file per settings group
- Extracted dashboard presentation widgets into `lib/screens/dashboard/widgets/`: `GlassNavBar`, `LivePowerCard`, `DualStatusCards`, `EnvironmentGrid`, `GreetingHeader`, `DateStrip`, `TelemetryCard`, `TelemetryChartCard`, `ChartSectionHeader`, and the banner set (`ConnectionStatusBanner`, `OfflineBanner`, `EnergyAlertBanner`, `TelemetryErrorView`)
- Extracted dashboard logic into pure helpers under `lib/screens/dashboard/utils/`: `history_range.dart`, `energy_helpers.dart`, `telemetry_helpers.dart`
- Refactored Dashboard screen from 3,046 lines to 1,389 lines (-54%), leaving the screen as a state container plus page composition
- Replaced the static section builders that reached into `_SettingsScreenState` with widgets that take `SettingsController` explicitly
- Replaced the `Map<String, _RangeControllers>` of environment limits with a typed `EnvRangeSetting` list that carries its own label, unit, bounds, and preference keys
- Moved threshold parsing in `_loadPreferences` into a single `_readDouble` helper
- Extract `_storeHistory` and `_notifyLive` in the dashboard to remove repeated notify branches

## [1.3.1] - 2026-09-26
### Added

- Added Weather monitoring feature with OpenWeatherMap API integration
  - New `WeatherService` class for fetching current weather and forecasts
  - New `WeatherData` and `WeatherForecast` data models
  - Weather card widget on Dashboard showing temperature, humidity, wind, cloud cover
  - Weather settings section in Settings screen with API key and city configuration
  - Test connection button to verify API key and location
  - GPS location support for automatic weather fetching
- Added modular architecture for Energy Report screen with extracted widgets (PeriodSelector, TotalsCard, ChartCard, DataNote, EmptyAndErrorViews, ExportButton) and utilities (format_helpers, csv_builder, chart_helpers, chart_helpers)
- Added modular architecture for Dashboard screen with extracted chart utilities (MetricDef, SeriesStats, ChartSeries, ChartBounds, processSpots) and helpers (alarm_helpers, bound, color_helpers, date_helpers)
- Added modular architecture for Settings screen with extracted _RangeControllers, _Section, static builder functions, and shared helpers
- Added Energi Analytics title for Energy Report screen (replaced "Laporan energi")
- Added comprehensive CHANGELOG documentation for all refactoring changes

### Changed

- Updated Android `compileSdk` to 36 to support latest plugin requirements (android_alarm_manager_plus, flutter_local_notifications, geolocator, etc.)
- Updated `geocoding` dependency from ^2.1.1 to ^5.0.0 for Android 14+ compatibility
- Added GPS permissions (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION) to AndroidManifest.xml
- Refactored Energy Report screen from 809 lines to 251 lines (-69%) with modular widget/utility structure
- Refactored Dashboard screen from 3,072 lines to 2,550 lines (-17%) with ~500 lines extracted to reusable utilities
- Refactored Settings screen from 816 lines to 470 lines (-42%) with consolidated validation, persistence, and builder patterns
- Renamed Energy Report screen title from "Laporan energi" to "Energi Analytics"
- Moved `await loadCctvUrl()` outside `setState` in `_loadPreferences` to fix async context issue
- Restructured all three screens to use modular widget/utility architecture with clear separation of concerns

### Improved

- Reduced total codebase by ~1,000 lines through modular extraction while preserving all functionality
- Improved maintainability with clear separation of concerns (widgets, utils, charts, helpers)
- Enhanced testability with pure functions in utility files
- Enhanced reusability of chart helpers, date formatters, color helpers, and alarm helpers across screens
- Zero breaking changes - all functionality preserved
- Better error handling in WeatherService with descriptive messages for API errors (401, 404, etc.)
- Weather service now properly throws exceptions for GPS permission issues instead of silently failing
- **Weather card compact redesign**: Single card with all metrics (temperature, humidity, wind, cloud cover) in one row; removed solar irradiance section; reduced padding and spacing; uses theme colors (primary, secondary, tertiary, outline) that adapt to accent color from Settings
- **Fixed humidity text overflow**: Reduced font sizes (value: 14→12, label: 12→9), added ellipsis handling, smaller icons (20→18), optimized padding

- Added a smooth bottom navigation collapse while scrolling down on dashboard pages.
- Added live ThingsBoard telemetry over WebSocket with automatic reconnect and REST polling fallback.
- Added custom telemetry chart ranges for up to 90 days with adaptive aggregation intervals.
- Added a live/polling connection indicator to chart headers.
- Added connection health tracking for REST, WebSocket, and polling transports, including reconnect count and last successful update.
- Added energy analytics for production forecasting, target comparison, peak usage, and estimated battery runway.
- Added a Settings field for configuring the daily production target in kWh.
- Combined dashboard energy summary and forecast into one Energy Analytics card.
- Added alarm deduplication, acknowledgement/resolution workflow, reopening, and severity/status filters.
- Hardened session refresh invalidation, token validation, WebSocket authentication guards, and API error handling.
- Added visible date-range calendar controls directly to PV, AC, and Battery chart headers.
- Anchored the collapsed navigation control to the left so the panel visually shrinks from right to left without shifting the dashboard content.
- Updated bottom navigation labels to English: `Overview`, `PV`, `AC`, `Battery`, and `CCTV`.
- Added scroll-direction and distance thresholds to prevent accidental navigation transitions during small gestures.

### Fixed

- Fixed Dart analyze errors in `weather_service.dart` (parentheses for type casting) and `weather_card.dart` (unnecessary underscores)
- Fixed async context error in Dashboard `_loadPreferences` by moving `await loadCctvUrl()` outside `setState` callback
- Resolved merge conflicts in settings_screen.dart and energy_report_screen.dart keeping refactored versions
- Fixed import paths in all extracted utility/widget files for correct module resolution
- Fixed weather data not updating on dashboard after saving API key in settings
- Fixed weather card refresh button and settings button in no-data state

- Prevented the bottom navigation animation from changing the Scaffold layout height or causing the dashboard to disappear while scrolling.
- Replaced abrupt navigation content switching with a crossfade and eased width animation.
- Fixed the date-range picker failing to open when the current day was selected by normalizing picker dates and validating the initial range.
- Optimized forecast calculations by removing redundant combined-history sorting and allocations.
- Forecast progress now refreshes after the daily target is changed in Settings.
- Forecast calculations now use today's PV production and show the actual energy accumulated today.
- Added local alarm notifications when alarms are detected during active monitoring.
- Added periodic Android background alarm checks with local notifications after reboot.
- Kept the detailed energy report flow for historical charts, custom ranges, and CSV export.
- Avoided blocking app startup on alarm notification setup by initializing alarm services asynchronously after `runApp` and guarding failures so they no longer prevent the dashboard from launching.

## [1.3.0] - 2026-09-25
### Added

- Added last-known telemetry caching with `SharedPreferences` and an offline dashboard banner showing the cache age.
- Added telemetry retry handling with exponential backoff for network failures and HTTP 5xx responses.
- Added persistent alarm history for low SOC, stale telemetry, and environment threshold alerts, with a dedicated history screen and clear action.
- Added screen-reader semantics for telemetry metrics, charts, gauges, connection status, CCTV controls, and energy reports.

- Added configurable local alerts for ambient temperature, humidity, and water TDS. Blank thresholds are ignored, and alerts only evaluate fresh sensor telemetry.
- Added a dashboard status that distinguishes ThingsBoard fetch failures from stale telemetry and shows the last successful fetch time.
- Added validation for environmental threshold ranges in Settings.

### Changed
- Restructured settings page from a single flat scrolling page into a nested category-based navigation pattern (like phone settings)
- Settings main page now shows a list of 8 categories: Appearance, Monitoring, Energy alerts, Environment alerts, CCTV source, Performance, About, Account
- Tapping a category navigates to a detail page showing only that category's options
- Added AnimatedSwitcher (200ms) for smooth transitions between category list and detail pages
- Added PopScope to intercept system back button: when viewing a detail page, back returns to the category list instead of exiting to dashboard
- AppBar dynamically shows the category name as title when viewing a detail page, with a back arrow button
- Save button is only visible on the main category list page (hidden in detail pages)
- All existing logic preserved: SharedPreferences keys, save mechanism, validation, theme controller calls, logout flow

### Improved

- Merged successful telemetry snapshots from the battery, PZEM, and environment devices so offline mode can restore the complete dashboard state.
- Preserved existing alert SnackBars while recording newly triggered alerts in alarm history.

- Smoothed dashboard page transitions by reducing unnecessary rebuilds, isolating page repaints, and optimizing chart rendering.
- Improved the ThingsBoard connection banner with a three-second display period and smooth fade/collapse exit animation.
- Enhanced chart touch tooltips with one shared timestamp and combined `V`, `A`, and `W` values in a rounded frosted-transparent panel.
- Rounded the saved-session logo shown on the biometric authentication screen.
- Reduced dashboard rebuilds during telemetry updates by isolating live metrics, alerts, connection status, charts, and CCTV content with targeted listenables.
- Added chart point processing and memoized statistics to reduce rendering work for large telemetry histories.
- Improved energy report chart interaction and rendering with repaint isolation and a dedicated touch-state notifier.
- Improved ambient glass rendering with repaint isolation for smoother scrolling and page transitions.

### Fixed
- System back button (Android gesture/swipe) now correctly returns to the settings category list instead of immediately exiting to the dashboard

### Validation

- `flutter analyze --no-pub` passed with no issues.
- `flutter test --no-pub` passed.
- Debug APK built, installed, and launched successfully on Android device `24090RA29G`.

## [1.2.3] - 2026-09-24

### Fixed

- Applied the configured stale telemetry threshold consistently to device cards and the Overview summary.
- Added landscape fullscreen playback controls for CCTV.
- Synchronized the Settings version label with the application release version.

## [1.2.2] - 2026-09-24

### Added

- Added estimated daily and seven-day PV production and AC consumption summaries, compared with the previous equivalent period.
- Added configurable in-app alerts for low battery SOC and stale telemetry.

### Improved

- Redesigned the CCTV page with a standby state, camera status, and clearer playback controls.
- Changed CCTV playback to start only after the user presses **Play kamera**; added stop, retry, and reload controls.
- Avoided rebuilding the dashboard when periodic telemetry polling returns unchanged values.

## [1.2.1] - 2026-09-24

### Improved

- Reduced chart history loading from three requests to one request per device.
- Smoothed the dashboard app bar blur and reduced excess scroll space.
- Refined the date selector and grouped Settings into clear sections with System, Light, and Dark appearance options.

## [1.2.0] - 2026-09-23

### Added

- Added `lib/widgets/liquid_glass.dart` — reusable Liquid Glass UI system with five widget classes: `AmbientBackground` (radial orb backdrop), `LiquidGlassCard` (frosted glass card surface), `GlassCapsule` (compact metric pill with progress bar), `GlassCircularGauge` (custom painter arc ring with glow tip), and `GlassDateChip` (animated date strip chip).
- Added **Smooth Glass Mode** toggle in Settings (Performance section): when enabled (default), renders glass surfaces with GPU-friendly acrylic gradients instead of `BackdropFilter` blur, sustaining 60 fps on mid-range Android devices; when disabled, uses real-time `BackdropFilter(sigmaX/Y: 18)` with `RepaintBoundary` isolation.
- Added **Interactive Calendar Date Strip** on the Overview tab: a 7-day horizontal scroll strip that lets users select any past date to view that day's historical telemetry data on the PV, AC, and Battery chart pages.
- Added **Personalized Greeting Header** on the Overview tab: shows time-based greeting (Selamat Pagi / Siang / Malam), user's first name fetched from ThingsBoard `/api/auth/user`, avatar circle with initial, and full Indonesian date.
- Added `fetchDisplayName()` to `ThingsBoardApi`: fetches and caches the logged-in user's display name (`firstName` or email prefix) in `SharedPreferences`.
- Added `clearUserCache()` to `ThingsBoardApi`: clears the cached display name on logout.
- Added `performanceMode` property to `AppThemeController` with persistent storage under key `performance_mode`.
- Added password visibility toggle on Login screen (`visibility` / `visibility_off` icon button).

### Improved

- Transformed the entire dashboard into a **Pure Liquid Glass UI**: all telemetry cards, chart cards, and the overview layout now use `LiquidGlassCard` with ambient orb backgrounds via `AmbientBackground` on every page.
- Redesigned Overview tab: Hero glass card showing live PV power (48px bold) paired with Battery SOC circular gauge, three `GlassCapsule` sub-metrics (PV Output, AC Load, Battery), dual side-by-side cards (Battery ring detail + AC Grid status with stable/unstable badge), and a 5-cell Environment grid.
- Redesigned bottom navigation bar: active tab now renders as a filled accent circle with white icon and glow shadow; inactive tabs show outline icon with label.
- Redesigned Login screen: ambient orb background, form wrapped in `LiquidGlassCard`, "Selamat Datang" greeting, `FilledButton` pill login button, and styled error container with icon.
- Made historical chart date-aware: selecting a past date fetches `00:00–23:59:59` of that day instead of rolling 24 hours from now.
- Upgraded AppBar to fully transparent with `extendBodyBehindAppBar: true` so the ambient background fills the entire screen edge-to-edge.
- Fixed `appVersion` constant in Settings from `1.0.0+1` to `1.1.1+3`.

### Validation

- `flutter analyze` passed with no issues.
- `flutter test test/widget_test.dart` passed (2/2).

## [1.1.1] - 2026-09-23

### Added

- Added Dark Mode & Light Mode toggle in Settings (`Appearance` section) with instant preview and persistent preference storage via `SharedPreferences`.
- Added Material 3 Light Theme with adaptive scaffold backgrounds, high-contrast cards, and matched form styling.
- Added adaptive semantic palette variants for Live Energy Sources (PV, AC, Battery, and Environment) for both Light and Dark modes.
- Added adaptive styling for historical 24-hour charts (card background, gridlines, axis numbers, and line series colors) to ensure high readability in both themes.
- Added adaptive Android status bar and navigation bar brightness styling that seamlessly follows the active theme mode.
- Added unit and widget tests for `AppThemeController` theme mode toggling and persistence.

## [1.1.0] - 2026-09-22

### Added

- Rebranded the application to **EnerGrow** in the login screen, splash screen, dashboard title, Android application label, and launcher icon.
- Added an embedded CCTV monitoring page using the go2rtc WebSocket video stream at `https://cctv.mbkm20262027.tech/stream.html?src=cam1`.
- Added CCTV reload handling when the stream cannot be loaded.
- Added a Settings page with configurable telemetry auto-refresh, refresh interval, and CCTV stream URL.
- Added persistent app color palettes in Settings: EnerGrow green, Solar amber, Ocean cyan, and Forest teal.
- Added an About section showing the current application version.
- Added PV Energy telemetry as a live metric in addition to the existing AC Energy metric.

### Improved

- Added chart grid lines, readable X/Y axes, time labels, and per-series Latest, Avg, Min, and Max summaries.
- Kept existing chart data visible while telemetry refreshes to avoid spinner-induced blank charts.
- Improved PV chart color separation between Voltage, Current, and Power.
- Reworked the bottom navigation into a compact, pure frosted-glass navigation panel with a smaller neutral selection pill.
- Added extra bottom content spacing so chart statistics remain visible above the floating navigation panel.
- Standardized visible headings and navigation labels with Title Case, including `PV Monitoring`, `AC Monitoring`, `Battery Monitoring`, `CCTV Monitoring`, and `Live Energy Sources`.
- Matched Android system navigation and status bars to the dark EnerGrow interface.
- Made the login form scroll safely on short phone screens.

### Fixed

- Fixed chart Y-axis labels overlapping vertically.
- Fixed chart X-axis time labels overlapping at the edges.
- Fixed the CCTV source URL being displayed below the video.
- Replaced the PV Current lightning icon with an appropriate current-flow icon.
- Removed deprecated Settings dropdown API usage.

### Validation

- `flutter analyze` passed with no issues.
- `flutter test test/widget_test.dart` passed.
- `flutter build apk --debug` passed.
- Debug APK installed successfully on the USB Android device `24090RA29G`.

## [1.0.0] - 2026-09-22

### Added

- ThingsBoard login with JWT persistence in `SharedPreferences`.
- Session validation on app startup and automatic redirect after token expiry.
- Dark Material 3 interface for field monitoring.
- Overview navigation with dedicated `PV`, `AC`, and `Battery` sessions.
- Live telemetry cards for battery, PV/DC, AC, and environment metrics.
- Automatic telemetry refresh every 10 seconds.
- Pull-to-refresh for manual updates.
- Stale-data age indicators such as `Updated 3 min ago`.
- Separate 24-hour charts for voltage, current, and power on PV, AC, and Battery pages.
- Logout action from the dashboard menu.
- Release APK build for Android devices.

### Validation

- `flutter analyze` passed with no issues.
- `flutter test` passed.
- Release artifact: `app-release.apk`.

### Known limitations

- Push notifications, biometric login, WebSocket telemetry subscriptions, and FNN/XAI prediction remain roadmap items.
- Historical chart availability depends on ThingsBoard telemetry keys and retention.
- The application requires access to the ThingsBoard server and does not provide full offline mode.
