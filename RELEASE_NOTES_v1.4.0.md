# EnerGrow 1.4.0 (build 10) Release Notes

## Overview
First release built and verified on **Linux**, plus the closing refactor session.
The headline change is that the build no longer needs the Android NDK or CMake:
the release APK is now produced from a **732 MB** SDK instead of 7.5 GB.

## Version
- **Version Name**: 1.4.0
- **Version Code**: 10
- **Release Date**: 2026-09-26
- **Git Tag**: v1.4.0

## Major Changes

### 🛠️ Build no longer needs the NDK or CMake

`path_provider_android` 2.3.0 rewrote its Kotlin side on top of the `jni`
package, which compiles C through CMake and therefore required a full NDK
toolchain to build a 130 KB shared library. Pinned back to 2.2.23, the last
release before that rewrite, which still satisfies `path_provider`'s own
`^2.2.5` constraint.

- Android plugins: **14 → 12**
- `libdartjni.so`: **removed from the APK**
- No native build at all: zero `.o` files, no `build.ninja`, no CMake
- Android SDK for a clean setup: **7.5 GB → 732 MB**

The chain that pulled `jni` in cannot be cut at the app level, because
`share_plus_platform_interface` depends on `path_provider` unconditionally in
every published version. The override holds `path_provider_android` at 2.2.23;
both versions target the same `path_provider_platform_interface ^2.1.0`, so the
plugin-facing API is unchanged.

> `flutter pub outdated` will keep reporting 2.2.23 as behind. That is the pin
> working as intended, not a problem. Drop the override once 2.3.x stops
> pulling in the NDK.

AGP still installs Flutter's default NDK during configuration, and this cannot
be avoided from the project side: `FlutterPlugin.kt` calls `forceNdkDownload`
unconditionally and fabricates a synthetic `externalNativeBuild` so AGP
believes an NDK is required. The download is a one-off per machine, and the
setup script fetches it with `curl` in seconds rather than letting AGP take
hours.

### ✅ Fixes found by testing on a real device

Eight bugs were found by building and using the app on hardware, not by reading
code. All eight are fixed, and all eight now have a verified on-screen result
rather than only a passing test.

- **Battery runtime was 75 hours instead of 40.6** — the projection divided by
  the AC *peak* load rather than the battery's own discharge, and then the sign
  convention of the Bluetooth BMS (`current` around `-2.08 A`) made both
  candidate power readings get rejected. Runtime is now within a percent of a
  hand calculation.
- **TDS alerts could never fire** — a refactor transcribed the sensor bound as a
  maximum of 100 ppm when the original was unbounded. Hydroponic nutrient
  solution is 800–2000 ppm and seawater is about 35000 ppm, so the limit made the
  alert dead. A regression test now pins each sensor's bounds.
- **The CCTV URL set in Settings was silently discarded** — it was written to
  `SharedPreferences` while the dashboard read it from secure storage.
- **Chart axis labels were unreadable** — intervals came from `range / 3` raw, so
  ticks landed on values like `02:10` and `111.45`. They now snap to round
  numbers, and multi-day ranges show a date instead of repeating `00:00`.
- **The chart range label ignored the selected day** — only the text was wrong;
  the data was always correct.
- **Weather never refreshed after adding an API key** — present since the feature
  was added.
- The real `applicationId` is now `tech.mbkm.energrow`.

### 🧪 Test coverage: 119 → 139

`thingsboard_api.dart` is ~500 lines and the heart of the integration, and it had
**no tests at all**. The `describeHistoryRange` bug shipped precisely because the
two functions that had to agree had nothing comparing them.

Added 20 tests covering the WebSocket URI, session state, legacy token
migration, the offline cache, and the telemetry key sets. While writing them I
found the key lists were written out **twice**, once in the REST fetchers and
again in the WebSocket subscription. A key added to only one copy would arrive
over polling but never update live, with nothing in the logs to explain it. The
literals now live in one place and both transports reference them.

### 🧹 Repository hygiene

- `applicationId` moved from the `flutter create` template to `tech.mbkm.energrow`
- Added `AGENTS.md` with the conventions and environment gotchas that are
  expensive to rediscover
- Added `.gitattributes` pinning LF line endings, after 126 files were showing
  as modified purely because they carried CRLF from a Windows checkout
- Gradle heap lowered from a 12 GB request to 1.5 GB, which the 7.1 GB test
  machine could never have satisfied
- Gradle wrapper switched from `-all.zip` to `-bin.zip`, saving ~1.2 GB
- `CHANGELOG.md` consolidated: it had accumulated three `[Unreleased]` headings
  and three conflicting `1.3.0` headings from an unclean merge. The three `1.3.0`
  blocks were all part of the tagged release; the block headed
  `[Unreleased] - 2026-09-25` was verified against the tags and belongs to 1.3.1.

## Validation

- ✅ `flutter analyze` — no issues
- ✅ `flutter test` — 139/139 pass
- ✅ `flutter build apk --release` — succeeds
- ✅ Signing certificate fingerprint matches §3 of the release process document
- ✅ Installs and runs on an Android 16 (API 36) device, Xiaomi 24090RA29G
- ✅ Cold launch **1038 ms**, against a <2 s target
- ✅ Live telemetry, WebSocket indicator, and the five dashboard tabs all working

## Installation

1. Download `EnerGrow-v1.4.0.apk` from the release assets
2. Allow installation from unknown sources if Android asks
3. Install and open the app
4. Sign in with your ThingsBoard **Customer User** account
5. OpenWeatherMap needs an API key under Settings → Weather (optional)

> Installing over 1.3.1 is seamless: the signing key is unchanged.
> Installing over a build older than the `applicationId` change requires an
> uninstall first, which clears the stored session and settings.

## Known Limitations

- **PZEM-017 (DC) readings can go stale** — silent read failure in the ESP32
  firmware, not fixable at the app layer. The app displays the values as
  received and marks them stale.
- **Single point of failure** — if the Orange Pi or the Cloudflare Tunnel is down,
  the app cannot fetch anything.
- **CCTV is expensive on battery** — WebView decoding runs on the device while
  the dashboard keeps polling every 10 seconds. Enable *Smooth Glass Mode* in
  Settings to reduce render cost.
- **Y-axis labels are rounded** — ticks snap to clean numbers, so a label can
  differ from the exact recorded value.
- **Weather needs an API key**, and OpenWeatherMap's free tier is rate limited.
- **`package_info_plus` and `share_plus` still apply the legacy Kotlin Gradle
  Plugin.** Flutter 3.47.5 warns that a future version will refuse to build with
  them. Both need a major-version upgrade; nothing is broken today.

## Verification

- **Signing certificate SHA-256**: `504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5`
- **Version Name**: 1.4.0
- **Version Code**: 10
- **Build Type**: release, signed with the project upload keystore
- **APK size**: 58 MB, `arm64-v8a` / `armeabi-v7a` / `x86_64`

## Files Included

- `EnerGrow-v1.4.0.apk` — signed release APK
- `CHANGELOG.md` — complete changelog history
