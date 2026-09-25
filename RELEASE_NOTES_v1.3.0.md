# EnerGrow 1.3.0 (build 8)

This release adds offline telemetry support, automatic retry handling, persistent alarm history, and accessibility improvements.

## Highlights

- Added last-known telemetry caching in `SharedPreferences`.
- Added an offline dashboard banner showing the age of cached data when ThingsBoard is unavailable.
- Added exponential backoff retries for network failures and HTTP 5xx telemetry responses.
- Added persistent alarm history for low SOC, stale telemetry, and environment threshold alerts.
- Added the Alarm History screen with severity indicators, timestamps, details, and clear-history confirmation.
- Added screen-reader semantics to telemetry cards, gauges, charts, connection status, CCTV controls, and energy reports.

## Installation

1. Download `EnerGrow-v1.3.0.apk` from this GitHub release.
2. Install it on an Android device. If requested, allow installation from the app used to open the APK.
3. Existing installations can be updated when the signing certificate matches the previous release.

## Verification

- `flutter analyze --no-pub` passed with no issues.
- `flutter test --no-pub` passed.
- `flutter build apk --release` passed.
- APK signing certificate was checked against the project signing fingerprint.
- The release APK was not installed over the existing debug-signed package on Android device `24090RA29G` because Android rejected the signature mismatch. The existing installation was preserved to avoid deleting local tokens and preferences.

## Known limitations

- Offline mode displays the last successful telemetry snapshot; it does not provide live updates without a network connection.
- Alarm history is stored locally on the device and is not synchronized between devices.
