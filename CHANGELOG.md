## [Unreleased]

### Fixed

- Fixed `WeatherForecast.fromJson` parsing One Call API payloads with `WeatherData.fromJson`, which read `main.temp` / `wind.speed` / `coord` — keys that do not exist in that format. Added `WeatherData.fromOneCallJson` to correctly parse One Call entries (scalar `temp` in hourly, `temp.day` object in daily, snake_case `wind_speed`, no per-entry `name` or `coord`).
- Fixed `_estimateSolarIrradiance` to handle both current-weather (`clouds.all` nested) and One Call (`clouds` scalar) formats.
- Fixed splash screen logo not being rounded — wrapped `BrandLogo` in `ClipRRect` for consistency with the biometric unlock screen.

### Added

- Added `WeatherService.dispose()` to release GPS handle and cached coordinates. Dashboard now calls it in its own `dispose()`.
- Added `test/weather_service_test.dart` — 15 tests covering both current-weather and One Call API parsing, serialization round-trips, and computed properties.
- Added `test/thingsboard_realtime_service_test.dart` — 21 tests covering service lifecycle, device configuration, `TelemetryPoint`, and `DeviceTelemetry`.

### Changed

- Translated all UI text in `alarm_history_screen.dart` to Indonesian (title, dialog, buttons, filters, status badges, menu actions, empty state, month names).
- Documented battery power sign convention in `energy_forecast_service.dart` — `.abs()` is used because BMS vendors disagree on charge/discharge sign.
- Translated "Try again" to "Coba lagi" in dashboard banners.
- Improved stale device label from "stale:" to "data lama:".
- Made dashboard overview page more compact: reduced card spacing from 12–20px to 8px, reduced internal padding across all dashboard cards (LivePowerCard 18→14, DualStatusCards 14→10, EnergySummaryCard 14→10, WeatherCard 12→10), changed EnvironmentGrid layout from 2+2+1 to 3+2 for better space efficiency.

### Documentation

- Updated `AGENTS.md` with current test coverage (179 tests), coordinated upgrade blocker for `package_info_plus` / `share_plus`, and `WeatherService.dispose()` note.

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
