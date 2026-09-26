## [Unreleased]

### Fixed

- **The device charts plot voltage, current and power together again.** Splitting them into a metric picker was wrong: seeing all three at once is the reason the chart exists. They are still one series each on a shared axis, so the readability problem is solved by scaling each against its own range and labelling the axis as a percentage — on the AC page power reaches 3500 W while current stays under 16 A, so a raw shared axis flattened two of the three traces onto the X axis. The tooltip and the readout under the chart print real volts, amperes and watts, and `SeriesScale` has tests for the inverse mapping, a flat series (a steady 220 V mains reading divides by zero otherwise) and a negative range (a discharging pack).
- **The chart series colours are fixed red, green and blue again, and the lines are solid.** Deriving three series from the theme accent as three lightness steps was tried, then distinguishing them with dash patterns, and both were rejected: three obvious colours need no legend decoding, and a dashed trace on a phone reads as broken rather than as styled.
- **The card outline now follows the theme accent.** It was a neutral white or black hairline, so a card in an amber theme held amber numbers inside a cold grey frame and the palette read as two systems. It is taken from `colorScheme.primary` rather than a new parameter, because the theme already carries the accent and threading a `seedColor` through every call site would only let the two disagree later.
- **Green no longer appears on a healthy dashboard.** The status strip coloured the value text, the battery icon and the tick green even when nothing was wrong, and every environment card in range got a green border and a green range caption. In an amber or cyan theme that put a second colour system all over the page. Now only a breach is coloured; a healthy reading keeps the card's accent-tinted outline and ordinary text, which is the same rule already applied to the environment grid's verdict.
- **`SegmentedButton` no longer fills the selected segment with a muddy tone.** Material uses the colour scheme's `secondaryContainer`, which `ColorScheme.fromSeed` desaturates until it reads as neutral — invisible with the default green, an olive block on a near-black card with "Solar amber". All three segmented buttons in the app now take their selected fill and text from the accent through a `SegmentedButtonThemeData`, since the seed is available where the `ThemeData` is built.
- **`Environment` is now `Lingkungan`**, and the energy comparison no longer prints "−100% dari periode lalu" when the previous period held 0.01 kWh. That figure is arithmetically right and reads as a catastrophe; below 0.1 kWh both periods are rounding noise against a value displayed to two decimals, so the card says what actually happened.
- **The alarm banner appears on the Overview page only.** A threshold breach is a fact about the greenhouse, not about the tab being looked at, and repeating it above the PV, AC, Battery and CCTV pages pushed four already-read lines above the content the user opened a tab to see. Connection state still shows on every page, because a page of numbers that cannot be trusted needs to say so wherever it appears, and the alarm count is in the status strip on every page.


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
- Added `lib/screens/dashboard/charts/series_scale.dart` and `test/series_scale_test.dart` — 8 tests for the per-series normalisation the three-unit chart depends on. Extracted from the widget so the arithmetic is reachable from `flutter test`; the failure it guards against is a chart that still draws and still animates with two of three traces flat on the axis, which reads as "nothing happening" rather than as a broken chart.

### Changed

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
- Health messages reach the UI translated, instead of the whole interface being half English.
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
- Translated all UI text in `alarm_history_screen.dart` to Indonesian (title, dialog, buttons, filters, status badges, menu actions, empty state, month names).
- Documented battery power sign convention in `energy_forecast_service.dart` — `.abs()` is used because BMS vendors disagree on charge/discharge sign.
- Translated "Try again" to "Coba lagi" in dashboard banners.
- Improved stale device label from "stale:" to "data lama:".
- Made dashboard overview page more compact: reduced card spacing from 12–20px to 8px, reduced internal padding across all dashboard cards (LivePowerCard 18→14, DualStatusCards 14→10, EnergySummaryCard 14→10, WeatherCard 12→10), changed EnvironmentGrid layout from 2+2+1 to 3+2 for better space efficiency.

### Removed

- Removed the `geocoding`, `csv` and `cupertino_icons` dependencies. None of them was imported anywhere, and `geocoding` was still pulling a full Android plugin into the build for no reason — it had even been upgraded once specifically for Android 14 compatibility, for a code path nothing used.
- Removed `WeatherService.searchCities`, `AlarmHistoryService.getAlarmsSince` / `acknowledgeAlarm` / `resolveAlarm` / `_find`, `alarmValueFromId`, `clearCctvUrl`, `fetchHistory` and the `DashboardShortcut` widget, plus the unused `EnergyForecastCard` file. All were verified to have no callers before removal.
- Removed the 22 telemetry key literals duplicated in `telemetry_helpers.dart`. They were written out a second time despite a comment on the originals stating that one source makes it impossible for them to come apart, which is exactly what would have happened.

### Documentation

- Documented the native alarm module in `AGENTS.md`: the one-rule-list contract, why `AlarmManager` is inexact and why there are two triggers, the foreground stand-down, the token handover, the debug trigger, and the parity fixture that keeps the two evaluators in agreement.
- Rewrote `README.md` around the background alarm capability, with the measured cost of a native check against a Flutter isolate, and corrected the stale "push notification belum tersedia" claims.
- Corrected `PRD_PLTS_Monitoring_App.md` §4.5, §6 and §7, which still claimed no alert reaches the user while the app is closed.
- Replaced `progress.md` §10.5, which had recorded the old Dart alarm as merely untested. It was broken, and the reason was a missing manifest declaration.
- Recorded the security review outcome in `AGENTS.md`, including the two findings that were real defects in brand-new code: the receiver time budget and the missing mutual exclusion between check entry points.
- Updated `AGENTS.md` with current test coverage (235 Dart tests, 11 Kotlin unit tests), coordinated upgrade blocker for `package_info_plus` / `share_plus`, and `WeatherService.dispose()` note.

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
