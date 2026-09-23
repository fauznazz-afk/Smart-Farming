# Changelog

All notable changes to this project are documented here.

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