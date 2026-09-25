# Changelog

All notable changes to this project are documented here.

## [Unreleased] - 2026-09-25

### Improved

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

- Prevented the bottom navigation animation from changing the Scaffold layout height or causing the dashboard to disappear while scrolling.
- Replaced abrupt navigation content switching with a crossfade and eased width animation.
- Fixed the date-range picker failing to open when the current day was selected by normalizing picker dates and validating the initial range.
- Optimized forecast calculations by removing redundant combined-history sorting and allocations.
- Forecast progress now refreshes after the daily target is changed in Settings.
- Kept the detailed energy report flow for historical charts, custom ranges, and CSV export.

## [1.3.0] - 2026-09-25

### Added

- Added last-known telemetry caching with `SharedPreferences` and an offline dashboard banner showing the cache age.
- Added telemetry retry handling with exponential backoff for network failures and HTTP 5xx responses.
- Added persistent alarm history for low SOC, stale telemetry, and environment threshold alerts, with a dedicated history screen and clear action.
- Added screen-reader semantics for telemetry metrics, charts, gauges, connection status, CCTV controls, and energy reports.

### Improved

- Merged successful telemetry snapshots from the battery, PZEM, and environment devices so offline mode can restore the complete dashboard state.
- Preserved existing alert SnackBars while recording newly triggered alerts in alarm history.

### Validation

- `flutter analyze --no-pub` passed with no issues.
- `flutter test --no-pub` passed.
- Debug APK built, installed, and launched successfully on Android device `24090RA29G`.

## [1.3.0+8] - 2026-09-25

### Changed
- Restructured settings page from a single flat scrolling page into a nested category-based navigation pattern (like phone settings)
- Settings main page now shows a list of 8 categories: Appearance, Monitoring, Energy alerts, Environment alerts, CCTV source, Performance, About, Account
- Tapping a category navigates to a detail page showing only that category's options
- Added AnimatedSwitcher (200ms) for smooth transitions between category list and detail pages
- Added PopScope to intercept system back button: when viewing a detail page, back returns to the category list instead of exiting to dashboard
- AppBar dynamically shows the category name as title when viewing a detail page, with a back arrow button
- Save button is only visible on the main category list page (hidden in detail pages)
- All existing logic preserved: SharedPreferences keys, save mechanism, validation, theme controller calls, logout flow

### Fixed
- System back button (Android gesture/swipe) now correctly returns to the settings category list instead of immediately exiting to the dashboard

## [1.3.0] - Unreleased

### Added

- Added configurable local alerts for ambient temperature, humidity, and water TDS. Blank thresholds are ignored, and alerts only evaluate fresh sensor telemetry.
- Added a dashboard status that distinguishes ThingsBoard fetch failures from stale telemetry and shows the last successful fetch time.
- Added validation for environmental threshold ranges in Settings.

### Improved

- Smoothed dashboard page transitions by reducing unnecessary rebuilds, isolating page repaints, and optimizing chart rendering.
- Improved the ThingsBoard connection banner with a three-second display period and smooth fade/collapse exit animation.
- Enhanced chart touch tooltips with one shared timestamp and combined `V`, `A`, and `W` values in a rounded frosted-transparent panel.
- Rounded the saved-session logo shown on the biometric authentication screen.
- Reduced dashboard rebuilds during telemetry updates by isolating live metrics, alerts, connection status, charts, and CCTV content with targeted listenables.
- Added chart point processing and memoized statistics to reduce rendering work for large telemetry histories.
- Improved energy report chart interaction and rendering with repaint isolation and a dedicated touch-state notifier.
- Improved ambient glass rendering with repaint isolation for smoother scrolling and page transitions.

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

### Known limitations

- Push notifications, biometric login, WebSocket telemetry subscriptions, and FNN/XAI prediction remain roadmap items.
- Historical chart availability depends on ThingsBoard telemetry keys and retention.
- The application requires access to the ThingsBoard server and does not provide full offline mode.

### Validation

- `flutter analyze` passed with no issues.
- `flutter test` passed.
- Release artifact: `app-release.apk`.
