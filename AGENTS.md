# AGENTS.md — EnerGrow (PLTS Monitoring)

Working notes for coding agents on this repository. Read before touching code.

## Project

Flutter app (Android-first) that reads PLTS telemetry from a live ThingsBoard
instance. No backend of its own. Part of the FNN-XAI-IoT MBKM programme.

```
ESP32 sensor → ESP-NOW → ESP32 gateway → MQTT → ThingsBoard CE (Orange Pi 4 Pro)
                                                        ↓
                                        HTTPS via Cloudflare Tunnel
                                                        ↓
                                             Flutter App (Android)
```

Battery telemetry does **not** go through the ESP32. It is read from a Bluetooth
BMS and publishes to its own ThingsBoard device.

Version lives in `pubspec.yaml` (`1.3.1+9`). `package_info_plus` reads it at
runtime, so never hardcode a version string in the UI.

## Architecture rule

Three layers, consistently applied:

1. **Pure logic goes in `utils/`** — no widgets, no I/O. This is what makes it
   testable. `test/` only covers these and models.
2. **Widgets receive data explicitly** — they never reach into a screen's private
   state. `TelemetryCard(data:, metrics:, seedColor:)`, not a `MetricCard` that
   pulls from `DashboardScreenState`.
3. **No singletons for data.** Values arrive as named parameters. The only
   singletons are the two real stores: `AlarmHistoryService` (SharedPreferences
   backed) and the `WeatherService` the dashboard holds for its lifetime.

`provider` is declared in `pubspec.yaml` but **never imported**. The app uses raw
`ChangeNotifier` plus `ListenableBuilder` / `AnimatedBuilder` and a custom
`Bound` widget (`screens/dashboard/utils/bound.dart`) for granular rebuilds.
Do not introduce `provider` without a reason to migrate the whole app.

### Polling and rebuilds

`dashboard_screen.dart` polls every `_refreshSeconds` (default 10). To avoid
rebuilding the tree, changes are announced by bumping a `ValueNotifier` revision
counter (`_liveRevision`, `_energyRevision`, `_chartRevision`) and rebuilding
through `Bound`. If you add a polling-driven value, follow that pattern instead
of calling `setState`.

## Environment (CachyOS / Arch)

Toolchain lives in `$HOME`, only the JDK needs root:

| Component | Version | Path |
|---|---|---|
| Flutter | 3.47.5 stable | `~/dev/flutter` |
| Dart | 3.13.4 | ships with Flutter |
| OpenJDK | 21.0.12 | `/usr/lib/jvm/java-21-openjdk` (pacman) |
| Android SDK | 36.0.0 | `~/Android/Sdk` |
| adb | 37.0.1 | `~/Android/Sdk/platform-tools` |

`~/.config/fish/conf.d/energrow-toolchain.fish` exports `ANDROID_HOME`,
`ANDROID_SDK_ROOT` and `JAVA_HOME` for fish. **The user's shell is fish**, not
bash — write fish syntax, not bash.

`~/dev/setup-energrow.sh` re-creates the whole toolchain idempotently.
`./setup-energrow.sh --check` audits without changing anything.

## dl.google.com is throttled — use curl

**This is the single biggest time sink on this machine.**

AGP and the Gradle wrapper download from `dl.google.com` and
`services.gradle.org` at **65–114 KB/s**. `curl -L` to the same URLs reaches
**7–44 MB/s**. Measured, same network, same moment:

| Artifact | via AGP/Gradle | via `curl -fL` |
|---|---|---|
| gradle-9.3.1-bin.zip (131 MB) | 103 KB/s → 22 min | 6.5 MB/s → 20 s |
| android-ndk-r28c (690 MB) | 65 KB/s → 2.9 h | 44 MB/s → 17 s |
| platform-35 (61 MB) | 84 KB/s → 13 min | 7 MB/s → 9 s |
| platform-34 (60 MB) | 114 KB/s → 9 min | 29 MB/s → 2 s |

So before any first-time build, pre-stage the SDK components. Do **not** guess
archive names — read them from Google's repository index and verify the
checksum, exactly as `setup-energrow.sh` does:

```
https://dl.google.com/android/repository/repository2-3.xml
```

Getting this wrong is easy and already happened once:
`android-ndk-r28-linux.zip` is **28.0.13004108**, but 28.2.13676358 lives in
`android-ndk-r28c-linux.zip`. The trailing `c` is not optional. A wrong guess
produces a build that fails much later with a confusing message.

Note the XML shape, which defeats naive line-based parsing: `<size>` comes
before `<url>` inside `<complete>`, and `<host-os>` sits *outside* `<complete>`.
The NDK ships one `<archive>` per host OS, so the linux entry has to be selected
explicitly.

## Gradle memory

`android/gradle.properties` originally requested `-Xmx8G -XX:MaxMetaspaceSize=4G`,
i.e. 12 GB on a machine with 7.1 GB total. That cannot be satisfied. It is now
`-Xmx1536M` plus a 1 GB Kotlin daemon. Leave headroom for the DE, a browser and
adb — the sum must stay under physical RAM or the daemon gets OOM-killed.

If a build is ever run on a larger machine, raise these. They are tracked in git
and shared with Windows builds.

## The NDK is downloaded but never used

Settled empirically on 26 September 2026. Read this before "fixing" it again.

**What was true before.** `path_provider_android` 2.3.0 rewrote its Kotlin side
on top of the `jni` package, which compiles C via CMake and needs the NDK. The
chain was:

```
share_plus → share_plus_platform_interface → path_provider → path_provider_android → jni → NDK + CMake
```

The app never uses `path_provider` itself, but `share_plus_platform_interface`
depends on it unconditionally in every published version, so the chain cannot be
cut at the app level. A `dependency_overrides` entry pins
`path_provider_android: 2.2.23` — the last release without `jni`, and still
satisfying path_provider's own `^2.2.5` constraint. Both versions target the
same `path_provider_platform_interface ^2.1.0`, so the plugin API is unchanged.
This drops the Android plugin count from 14 to 12 and removes
`libdartjni.so` from the APK.

**What that did not fix.** AGP installs an NDK during configuration no matter
what. Verified on a clean build with `ndk/` and `cmake/` deleted from the SDK:

- AGP fetches NDK **28.2.13676358** (Flutter's default) and unzips it
- the build then produces **zero** `.o` files, **no** `build.ninja`, and **no**
  `libdartjni.so`
- no active plugin mentions `ndkVersion`, `externalNativeBuild`, `cmake` or
  `ndkBuild`

So roughly 2.3 GB is downloaded and left unused. The trigger is inside AGP, not
in this project's configuration: removing the `ndkVersion` line from
`android/app/build.gradle.kts` only changed *which* version was fetched
(30.0 → 28.2), it did not stop the fetch. An earlier hypothesis here — that AGP
only needs the NDK when there is native build work — is **wrong**, and was
corrected after measuring it.

`ndkVersion` is therefore still absent from `android/app/build.gradle.kts`, so
that if a future dependency genuinely needs the NDK it resolves to the version
plugins actually request. The unavoidable download is best handled by
pre-fetching it fast; `~/dev/setup-energrow.sh` does that with `curl`.

## Physical device over wireless debugging

Test device: Xiaomi 24090RA29G, codename `malachite`, Android 16 / API 36,
1220×2712 at density 520 (override 513).

```
adb mdns services
adb connect <ip>:<port>
flutter run -d <ip>:<port>
```

Gotchas, all hit in practice:

- **The screen must stay awake.** Android stops the wireless debugging listener
  when the screen locks, and the ports rotate. A refused connection almost always
  means a locked screen, not a network problem.
- **`adb pair` uses a different port than `adb connect`.** The pairing port comes
  from "Pair device with pairing code", together with a 6-digit code. The connect
  port is the one the main Wireless debugging screen shows.
- **A mismatched key fails as "failed to connect", not "refused".** The local
  `~/.android/adbkey` is created fresh on first use, so a phone that was paired
  from another machine needs "Revoke pairings" then re-pairing.
- Flutter only accepts `-d` as `IP:port`; the mDNS serial form is rejected even
  though it appears in `flutter devices`.
- adb 37 auto-registers mDNS-discovered devices, so one physical phone shows up as
  two entries. Harmless, but disconnect the mDNS one to keep `-d` unambiguous.

## Storage layout

The source tree is on an **NTFS** partition (`ntfs3`). Consequences that have
actually bitten:

- **Line endings.** The project was developed on Windows, which left 126 files
  with CRLF in the working tree while git stored LF, so every file showed as
  modified. `.gitattributes` (`* text=auto eol=lf`) plus `git config
  core.autocrlf input` in this repo fixed it permanently. Do not reintroduce
  CRLF churn.
- `local.properties` is git-ignored and machine-specific. It held Windows paths
  (`C:\src\flutter`). Flutter regenerates it, but a first-build failure is worth
  checking there first.
- NTFS is case-insensitive. Verified safe: the only same-named Dart files are
  `chart_card.dart` in two different directories. Keep it that way.
- Gradle writes thousands of small files to `build/` and `.dart_tool/`. This works
  but is slow. If builds become painful, moving the project to btrfs is the fix.

## Test suite

```
flutter analyze     # must stay clean
flutter test        # 119 tests
```

`dart_test.yaml` sets `concurrency: 1` **on purpose**. The machine has 7.1 GB RAM
and only 1.4–2.4 GB free during a test run; the Dart compiler and the test
isolate compete and the loser gets OOM-killed. The symptom is misleading —
"did not complete" for a whole file, or a bare "loading x.dart" failure, with no
stack trace, and the failing file moves between runs. **Do not raise the
concurrency** without checking free RAM first.

`test/settings_validation_test.dart` has a `sensor bounds` group that pins each
sensor's min/max. It exists because a refactor once transcribed `TDS maxAllowed`
as `100` when the original was unbounded, which made the alert impossible to
trigger (hydroponic nutrient solution is 800–2000 ppm; seawater is ~35000 ppm).
That group found a second regression immediately after the first was fixed. Keep
it.

Regression guards worth knowing about, all added because of a real bug:

- `cctv_test.dart` — `parseAllowedCctvUrl` host allowlist
- `chart_bounds_test.dart` — `niceStep` / `niceTimeStep` axis rounding
- `dashboard_helpers_test.dart` — `describeHistoryRange` must agree with
  `historyTimeWindow`
- `energy_forecast_service_test.dart` — battery discharge sign convention

## Widget tests

- Never call `tester.getSemantics()` without `ensureSemantics()`. It can hang the
  isolate, and the damage is attributed to every later test in the file.
- `find.byType(Semantics).first` usually matches a `Scaffold` or `MaterialApp`
  node, not the widget under test. Always narrow with `find.descendant`.
- `error.isForMainFrame` is `bool?`. `== true` is deliberate; do not "tidy" it.

## Dart language gotchas in this SDK

- **Named-field record typedefs do not work.** `typedef PeriodTotals = ({double
  pv, double ac});` fails to resolve its getters. Use a class when named fields
  are needed; positional records are still safe.
- When moving a literal during a refactor, check the old value with `git show
  <commit>:path` first. Two of the bugs in this repo were transcription errors
  while restructuring code.

## Signing and secrets

`android/key.properties` and `android/upload-keystore.jks` are git-ignored and
must stay that way. Never print their contents, not even to "verify" them — check
that the expected *keys* exist instead.

Before publishing a release, verify the signing certificate fingerprint matches
the one recorded in `PRD_GitHub_Release_Process.md` §3. If it differs, **stop**
and investigate the signing config rather than publishing.

`FlutterSecureStorage` holds the ThingsBoard JWT. A legacy SharedPreferences copy
of `tb_token` / `tb_refresh_token` still exists as a migration path and is purged
after each load.

## Known technical debt

- `package_info_plus` and `share_plus` still apply the legacy Kotlin Gradle
  Plugin. Flutter 3.47.5 now warns that future versions will **fail to build**
  with them. Upgrade before it becomes a hard break.
- `thingsboard_api.dart` (~500 lines) is the integration core and has **no tests
  at all**. `thingsboard_realtime_service.dart` and `weather_service.dart` are
  also untested.
- `WeatherForecast.fromJson` parses One Call payloads with `WeatherData.fromJson`,
  which reads `main.temp` / `wind.speed` / `coord` — keys that do not exist in
  that format. It only works because it is fed its own re-serialised cache.
- `WeatherService.searchCities` calls the geocoding endpoint over **cleartext
  HTTP**, unlike every other call in the app.
- `dart_test.yaml`, the JVM heap in `gradle.properties`, and the
  `gradle-wrapper` `-bin` distribution are Linux-motivated but tracked in git, so
  they affect Windows builds too.
- `progress.md` is a handoff document. §8 (manual device verification of the chart
  date label and the TDS field) was completed on 26 September 2026; the rest of
  the document is still current.

## Documentation hygiene

`CHANGELOG.md` currently has **three** `[Unreleased]` headers and three
conflicting `1.3.0` headings left over from merges. It needs consolidating into
one `[Unreleased]` block before the next release. `pubspec.yaml` is the single
source of truth for the version number.
