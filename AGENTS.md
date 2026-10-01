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

Version lives in `pubspec.yaml` (`1.7.0+14` as of 1 October 2026, tagged
`v1.7.0`). The surface system, the navigation and the chart set all changed in
that release, which is why it is a minor and not a patch.
`package_info_plus` reads it at runtime, so never hardcode a version string in
the UI.

## Architecture rule

**Read these two files before writing any code.** They answer different questions
and both are short.

- **AGENT_PLAYBOOK.md** — *how* to work here: the mandatory reading list, when to
  spawn a subagent versus when one `grep` is enough, the environment numbers that
  decide whether you can run two builds at once, the hard rules, the harness
  gotchas that have cost real time, the verification gates, and the commit
  protocol.
- **FEATURE.md** — *what* is already implemented, verified against the source
  rather than against the other markdown files. Its §18 lists the known gaps:
  four functional ones, three dead or unreachable symbols, five test gaps,
  and eight things nobody has yet seen on a device. Several things that look absent
  are already there and unused; several that look present are not reachable. Its
  header explains why it exists: three label regressions in one session passed
  `flutter analyze`, the release build and every existing test, and were only
  found by looking at the screen.

Three layers, consistently applied:

1. **Pure logic goes in `utils/`** — no widgets, no I/O. This is what makes it
   testable. `test/` only covers these and models.
2. **Widgets receive data explicitly** — they never reach into a screen's private
   state. `TelemetryCard(data:, metrics:, seedColor:)`, not a `MetricCard` that
   pulls from `DashboardScreenState`.
3. **No singletons for data.** Values arrive as named parameters. The only
   singleton left is the one real store, `AlarmHistoryService`
   (SharedPreferences backed). There used to be a second one — `WeatherService`,
   held for the dashboard's lifetime — but the whole OpenWeatherMap integration
   was removed in 1.6.0 (`FEATURE.md` §8). Do not reintroduce a service-holding
   singleton "just for caching".

`provider` is declared in `pubspec.yaml` but **never imported**. The app uses raw
`ChangeNotifier` plus `ListenableBuilder` / `AnimatedBuilder` and a custom
`Bound` widget (`screens/dashboard/utils/bound.dart`) for granular rebuilds.
Do not introduce `provider` without a reason to migrate the whole app.

`Bound` **had no test at all** until `test/bound_test.dart` was added. Its token
contract is unenforced by the compiler: any parent rebuild that passes a new
closure over new plain data without also changing the token is silently dropped,
and `_visualToken` is a hand-maintained list of everything that has to be in it.
Two entries in that list were added *after* a real bug, so the failure mode is
real and the symptom — the AC card under the PV header — is device-only. If you
add a value a `Bound` builder reads, add it to `_visualToken` in the same change,
and expect `test/bound_test.dart` to be the thing that tells you if you forget.

### One declaration per page's telemetry

What a page charts lives in `screens/dashboard/widgets/chart_groups.dart`, and
the history request keys, the legend, the statistics row and the axis all read
from it. This is the whole reason greenhouse pH and fish turbidity could not be
plotted, and getting there meant undoing three things together: a three-field
`HistoryKeys` record, a `const suffixes` list of three names indexed by position,
and a `historyDeviceForPrefix` that sent every non-battery page to the PZEM
meter — so a request for `ph` went to a device that does not publish it, and
would have failed silently rather than loudly.

**Do not add a key in one place and a label in another.** The old chart derived
its storage key from a prefix and a suffix index while the screen derived its
lookup from a prefix and a literal, and the only reason they agreed was that both
lists had exactly three entries in the same order. Adding a fourth to one would
have compiled, passed every test, and plotted nothing.

**Group by unit, not by convenience.** Two series share a Y axis only when their
units make the comparison real — which is why `temp_dht` and `temp_ds18b20` share
one and lux does not share with anything. A chart whose shape is an artefact of
the units is worse than no chart, because it looks like a reading.

**Depth belongs in the shadow, never in the fill.** This is measured, not
preferred. A `BoxShadow` is painted *outside* the decoration's rect, so it is
incapable of darkening a card's own interior — which is where every caption in
this app is drawn. A gradient across the fill can, and the numbers are why it was
rejected: at 4% the light-mode worst case is already 4.15:1, at 10% it is 3.69,
at 15% it is 3.34, and AA is 4.5. So when a surface needs to feel thicker, raise
the shadow alphas. They are free.

**A raised surface has three shadows, not two.** Two equal shadows read as a
*float*: one dark halo and one light halo with no surface between them. Real
extruded objects have a contact shadow — the tight dark line where the object
meets what it sits on — and only then the ambient one spreading away from it. The
dark half is two shadows at different scales for that reason, and the light half
is one broad bounce, because a light source makes a small hard highlight and a
wide soft one. Mirroring the dark pair exactly is what makes CSS neumorphism look
like a 1990s bevel.

**Light mode is the harder mode for this style, and the two are not
interchangeable.** A mid-tone page is by definition a short distance from both
the white half and the dark half, so both have to work harder than on a
near-black page. Concretely: the light dark-half reached only a 4.6% luminance
drop at `0x4D`/`0x33` and had to go to `0x66`/`0x40`, while dark mode already
measured a 44% drop and was left alone. When you deepen one mode, measure the
other before assuming it followed.

**"Pressed" is two states, not one.** A raised block being pushed flattens into
the page; a well being pushed goes *deeper* into it. `AppElevation.pressed` and
`AppElevation.insetDeep` are the two, and they differ in which way the offsets
point, not only in size — inverting `insetDeep` produces a chip that pops *out*
of the bar when the finger pushes it in. There is a test for exactly that.

**Measure the screen, not the code.** A shadow can be in the token file, reach
`flutter analyze` and pass every test, and still be invisible on the device. The
check is a scanline of pixel brightness across a card edge, and the numbers to
compare are the card fill against the page and against the shadow's darkest
point.

**That scanline was finally taken on 1 October 2026, and it invalidated a
derivation.** Dracula's shadow alphas had been solved so that each shadow's
*composited* luminance step on `#282A36` equalled the step it makes on the dark
page, and `design_tokens_test.dart` asserted that equality to within 0.0007 and
passed. A scanline of the same card on the same build measured ΔL **8.2 against
the dark theme's 15.9** — 52% of it, with the suite green.

The reason is not a typo. It is that the mask blur removes a different fraction
of each page's shadow, so the same blur and the same alpha land on different
visible steps. **An arithmetic relationship and a pixel are different claims,
and only one of them is the thing the user sees.** This is the third time in
this repo that a guard encoding an arithmetic relationship has been the thing
that was wrong — after the stale surface list in `color_helpers_test.dart` and
after `_history` being reported dead.

Two things follow, and both are in the code:

- **The relation between alpha and *measured* ΔL is convex.** The blur eats most
  of a weak shadow's peak and little of a strong one's, so a uniform factor
  overshoots badly. Correcting a 1.9× shortfall by scaling alphas 1.9× overshot
  to 2.6×. It was fixed by interpolation between two measured points.
- **Correct only the half you measured.** Dracula's dark halves moved and its
  light halves did not, because only the dark half had been sampled. Scaling both
  by a number borrowed from one of them is the mistake the patch exists to
  correct, and doing it would have looked tidier.

`FEATURE.md` §18.5 has been updated: the top-edge scanline is the one open
question this leaves.

### Soft-UI surfaces, and why they are opaque

The surface system is opaque soft-UI: a card is the **same colour as the page**,
and all of its depth comes from a dual shadow pair with one light source, from
the top left, app-wide. `design_tokens.dart` is the only place a fill, a radius,
a shadow or a duration is written.

The opacity is the load-bearing part, and it is the opposite of what the app used
to do. Card fills were a gradient at alpha 0.44 to 0.66, composited over three
large radial-gradient orbs, so the rendered fill varied continuously with the
pixel. `test/color_helpers_test.dart` has always asserted contrast against
opaque constants, which is what made its claim true rather than approximately
true.

Three things that are easy to break:

**The light-mode page must stay a mid-tone.** It is `#E1E7E4`. It was
`#F1F4F2`, and that is close enough to white that the light half of every
shadow pair had nowhere to be lighter *to* — only the dark half showed, and
every card read as flat Material with a grey edge. Do not "brighten" it. This is
the single most consequential value in the token file.

**The hairline must stay neutral.** It was tinted with the theme accent, which
put a green outline on every card and silently undid the entire migration: a
coloured border is a drawn edge, and a drawn edge is the thing this style exists
to replace. It is a very light neutral now, kept because WCAG 1.4.11 wants 3:1
for a component boundary and no test measures it.

**`AppCard` must keep its transparent `Material` between the decorated box and
the content.** An opaque fill paints over the ink layer of the nearest Material
above it, so every `ListTile`, `SwitchListTile` and `InkWell` inside a card has
its splash and hover state covered. `settings_screen_test.dart` catches this as a
test failure; the navigation bar's own ink is the same defect and has no test.

There is one rule here that is about *content* rather than about surfaces, and it
is older than any of this: **the app never varies a hue automatically.**
`metricColor` and `strongMetricColor` take an `index` and **ignore it**, and
`test/color_helpers_test.dart` fails if they start using it. A 40-degree rotation
per index was implemented so the PV, AC and battery pages would be
distinguishable by colour, and it was reverted because a colour the user did not
choose is a colour they cannot predict.

The chart series are the documented exception and they now have a second half.
A chart group with more than one series uses the fixed red/green/blue triad in
the same order, because three lightness steps of one hue are indistinguishable on
a phone. A group with a **single** series uses the user's accent, and that is not
a preference: there is nothing to distinguish it from, and painting it red would
give one colour two meanings in one app — "this is the voltage series" on one page
and "something is wrong" on another, in an app whose own rule is that a status
colour means a condition rather than an identity. The triad is **reused, never
extended**; adding a hue to accommodate a new chip is the same mistake as the
rotation, running the other way.

The same reasoning applies to `kAccentPalette`. It has four entries, two of which
are genuinely close in hue, and separating them by moving `Ocean cyan` was also
tried and reverted — that would silently change what an existing setting means.
**If colour needs to vary, it becomes a setting the user picks.** Do not invent a
default that reshapes the colour they already chose.

Two related rules, both learned by getting them wrong:

- **Never signal the same state three ways.** The environment cards had a tick, a
  warning triangle *and* a coloured border all at once, and it read as a
  checklist rather than a reading.
- **Say nothing when nothing is wrong.** A permanent green "semua normal" badge
  on the environment grid asserted a condition that is boring when true, and
  permanently occupied the space where a real warning needs to go.

Contrast claims are measured, not asserted. The `faintColor` and `status*` values
were documented as passing AA while the light-mode amber was actually at 4.02:1
on the glass card fill. `test/color_helpers_test.dart` now measures each one
against the real surfaces from `main.dart` and `liquid_glass.dart`, not against
white, and 8-bit quantisation is why the hue tolerances there are 0.5° rather
than exact.

**That test then failed in the opposite direction, and the failure is the lesson.**
Its surface list was six hand-written hex values, copied in when the glass fills
were replaced. The soft-UI work changed those fills a third time without touching
the test, and because the stale light values were *lighter* than the real ones it
measured against a more forgiving surface than the one rendering: `faintColor` sat
at 4.47:1, `statusBad` 4.48, `statusAlert` 4.47, three under AA, with the suite
green and a comment insisting every hex was a real fill. It survived two commits.

**So the surface list is read out of `AppSurfaces` rather than written down, and
it must stay that way.** A literal in a test whose job is to describe the app's
own tokens is a copy, and copies drift — twice here, silently, in opposite
directions. The same reasoning applies to any other "the test knows what the app
paints" list in this repo: if it can be derived, derive it.

**When you change a surface, change the colours measured against it in the same
commit.** The values here have almost no margin by design — 4.55 to 4.59 against
4.5 — so a surface tweak is a text-contrast change even when nothing about the
text changed. Adjust them by **scaling every channel by one factor**, which
preserves hue and saturation exactly, not by stepping HSL lightness: HSL moved
`faintColor` from 150.00° to 146.67° at a 0.6% darkening, and a caption colour that
shifts hue when you darken it reads warm beside a green theme.

**Green means a problem is absent, and the user did not choose it.** Status
colours are for warnings. A healthy reading takes the accent and ordinary text;
it does not take `statusOk`, and it does not get a green outline. Three green
elements beside an amber theme is the clearest possible statement that two
palettes are on screen at once, and the boring case is not information.

**One documented exception, and it is deliberate.** The device chart series are
fixed red, green and blue, and the chart is the one place where "voltage is red"
is worth more than theme consistency — three lightness steps of one hue are
indistinguishable on a phone, and dash patterns to compensate read as broken
lines. It is also the only place on the dashboard where a quantity is not the
user's data at all but a trend they are reading, which is a different job from
showing them a sensor value.

### Polling and rebuilds

`dashboard_screen.dart` polls every `_refreshSeconds` (default 10). To avoid
rebuilding the tree, changes are announced by bumping a `ValueNotifier` revision
counter (`_liveRevision`, `_energyRevision`, `_chartRevision`) and rebuilding
through `Bound`. If you add a polling-driven value, follow that pattern instead
of calling `setState`.

## Background alarms are native Kotlin, and must stay that way

The alarm check that runs while the app is closed lives in
`android/app/src/main/kotlin/tech/mbkm/energrow/alarm/`. It is plain Kotlin:
`AlarmManager` → `AlarmCheckReceiver` → `AlarmCheckRunner`, doing its HTTP with
`HttpURLConnection` and posting with `NotificationCompat`.

**Why not Dart.** This was measured, not assumed. The obvious Dart approach is
`android_alarm_manager_plus`, which starts a `FlutterEngine` per tick. That
engine stays resident, so the background cost is tens of megabytes of RAM plus a
second or more of startup, every fifteen minutes, forever. The Kotlin path costs
single-digit MB and a fraction of a second. Do not "simplify" this back into a
Dart background isolate.

**Why it was not working before.** `android_alarm_manager_plus` needs its
`AlarmService` and `AlarmBroadcastReceiver` declared in the app manifest, and
neither was. The alarm was registered and never delivered. If you ever see that
dependency in `pubspec.yaml` again, the manifest entries are missing and the
feature is dead, not merely untested. `progress.md` recorded this as "never
observed" for a long time because a check that does not fire produces no logs at
all.

**One rule list, two evaluators.** `lib/utils/alarm_rules.dart` owns every
alarm condition. `buildAlarmRules` turns the user's thresholds into rules;
`evaluateAlarmRules` runs them for the dashboard banner; `alarmRulesToJson`
ships the same list to the native side, which walks it in `AlarmEvaluator`. That
is deliberate: a threshold edited in Settings has to change the background
behaviour too, and the wording in a notification must not drift from the wording
in the app.

The unavoidable cost is that the message strings exist in both languages
(`formatAlarmMessage` in Dart, `AlarmMessageFormat.kt` in Kotlin), because Dart
is not running when a notification is built. They are pinned together by
`android/app/src/test/resources/alarm_parity_vectors.json`, which
`test/alarm_parity_test.dart` and `AlarmParityTest.kt` both replay. **If you
change either formatter, run
`dart run tool/generate_alarm_parity_fixture.dart` and expect the other
language's test to fail if you got it wrong.** Two duplicated message strings is
the price; an unverified duplication is not.

**The alarm is inexact on purpose, and there are two of them.** `setInexactRepeating`,
not an exact alarm. Exact alarms need `SCHEDULE_EXACT_ALARM` on Android 12+, which
means asking the user to grant a permission through a settings screen, and
`USE_EXACT_ALARM` is reserved for clock and calendar apps. A greenhouse does not
need either. `AlarmScheduler.schedule` also arms a `setAndAllowWhileIdle`
one-shot that the receiver re-arms after every run, because **a repeating alarm
is the first thing vendor power managers drop**: on the MIUI/HyperOS test device
the repeating alarm fired six times and then silently vanished from
`dumpsys alarm`, with `com.miui.powerkeeper` visible in the same output. The idle
alarm is exempt from Doze batching, so the two together survive more of what
real devices do. `dumpsys alarm` confirms both:
`repeatInterval=60000` for the cadence, `flags=0x8` (`ALLOW_WHILE_IDLE`) for the
backup. If alarms go quiet on a new device, look there first.

**Being inexact also means Doze may defer a check, sometimes by hours**, so the
check reads the age of the telemetry rather than assuming a tick happened.

**The check stands down while the app is in the foreground.** The dashboard
polls every ten seconds and evaluates the same rules, so a background tick on
top of that is duplicate work against the same ThingsBoard instance and risks the
two sides disagreeing about which alarms are active. `AlarmBridge.setForeground`
is called from `DashboardScreen` on init, on every lifecycle change, and in
`dispose`. At a one minute interval this matters: without it the request rate
doubles while the app is open.

**The interval is one minute, and that is a deliberate trade.** A greenhouse
alarm is only useful while the condition still is. It costs roughly 4300
ThingsBoard requests a day, three per tick, and each check finishes in about
0.45 s. `AlarmScheduler.INTERVAL_MINUTES` is the one place to change it; 5 is a
reasonable value if the ThingsBoard instance is a shared Orange Pi.

**The check has a wall-clock budget, and it is enforced, not assumed.**
`AlarmCheckRunner.BUDGET_MS` is 8 s, deliberately under the ~10 s a manifest
`BroadcastReceiver` gets. Every step is skipped rather than started once the
budget is spent, and `ThingsBoardClient` caps its own timeouts below what is
left. This is not defensive padding: the slow path is the *expected* one
whenever the access token has expired, and being killed between writing
credentials and saving the active set makes the next tick treat the same alarms
as new. That is the duplicate notification the whole active-set design exists to
prevent, reached by a different route.

**One lock guards every entry point.** `AlarmCheckReceiver`, the "check now"
bridge call and the debug trigger all call `AlarmCheckRunner.run()`, which takes
a process-wide `AtomicBoolean`. They used to have separate threads with no shared
guard, so two could read the same previously-active set and both decide an alarm
was new. `run(force: true)` is for the manual trigger: a user pressing "check
now" while looking at the app means it, so it bypasses the foreground
stand-down. Without `force` the button is a no-op, which is not discoverable.

**Do not try to test the background path with `adb shell am broadcast`.**
`AlarmCheckReceiver` is `exported="false"`, which is correct, so the shell is
refused. For a debug build there is `AlarmDebugReceiver`, declared **only** in
`src/debug/AndroidManifest.xml` and refusing to act unless the app is
debuggable, so it cannot exist in a release APK:

```
adb shell am broadcast -a tech.mbkm.energrow.action.DEBUG_CHECK_ALARMS \
  -n tech.mbkm.energrow/tech.mbkm.energrow.alarm.AlarmDebugReceiver
adb shell am broadcast -a tech.mbkm.energrow.action.DEBUG_RESET_ALARMS \
  -n tech.mbkm.energrow/tech.mbkm.energrow.alarm.AlarmDebugReceiver
```

`DEBUG_RESET_ALARMS` forgets which alarms were reported, so the next check
announces whatever is currently firing. Without it, verifying the notification
means waiting for a genuinely new condition, which can take hours. Note that a
debug APK cannot be installed over a release one, because the signing keys
differ; uninstall first, and expect to sign in again.

**Tokens are handed over, not shared.** The canonical ThingsBoard JWT lives in
`flutter_secure_storage`, which cannot be read without a Flutter engine. On
launch and on login, Dart hands a copy to `AlarmTokenStore`, which encrypts it
under a hardware-backed AndroidKeyStore key. A refresh performed in the
background updates only that copy; Dart's stays authoritative and overwrites it
on the next launch. If a refresh is rejected, the background tears itself down
rather than retrying a session the user has ended.

**A stopped device is a different alarm from a stale one.** `stale_*` is a
warning at the user's short window, `offline_*` is critical at a much longer one
(`AlarmThresholds.offlineMinutes`, default 60). Ten minutes of silence in an
MQTT pipeline is a hiccup; an hour is a sensor or gateway that has stopped, and
the two need different responses. They share the same staleness test, which is
why `AlarmComparison.offline` exists as a separate value rather than reusing
`stale`: each rule carries its own window.

**One notification per occurrence.** The set of active alarm IDs is shared
through `AlarmStateStore` and only a newly active ID is announced. The previous
implementation de-duplicated with a five-minute timer, which is longer than the
check interval, so it did not actually stop repeats.

**History is stored twice, on purpose.** The Dart store is `SharedPreferences`;
the native one is a private JSON file. They are merged on read. They are not
merged on disk because `shared_preferences` encodes a `List<String>` as a Base64
Java-serialized blob, and reproducing that byte for byte in Kotlin would tie this
module to a plugin's private encoding. `AlarmHistoryService.getAlarms` is the
façade.

**Verify on the device, because this cannot be unit tested.** Every outcome is
logged, including the boring ones; a background job that fails quietly is
indistinguishable from one that is not running. What a good run looks like:

```
adb -s <ip>:<port> logcat -s EnerGrowAlarmCheck:* EnerGrowAlarmBridge:* EnerGrowAlarmSchedule:*
adb -s <ip>:<port> shell dumpsys alarm | grep -A4 CHECK_ALARMS
```

```
check started
check finished: 1 active (1 new): environment_humidity_high   <- first sighting, notifies
check finished: 1 active (0 new): environment_humidity_high   <- still firing, silent
check finished: ok, no alarms                                  <- nothing breaching
```

`(N new)` is the number that decides whether a notification is posted, so it is
the line to read first when deciding whether an absence of notifications is a bug.

## Security posture, and what was audited

A full source-level audit ran over the alarm module, the ThingsBoard client, the
CCTV WebView, the manifest and the Dart services. Verdict: no Critical findings
and no confirmed credential-exfiltration path. What it confirmed as correct is
worth keeping, because each of these is easy to break by accident:

- **Tokens.** The canonical JWT lives in `flutter_secure_storage`; the background
  copy is AES-256-GCM under a hardware-backed AndroidKeyStore key, ciphertext
  only on disk, and deliberately kept *out* of the config JSON so that file never
  holds a credential. No method channel call returns a token, and the logs carry
  presence booleans, never values.
- **The host allowlist.** `requireAllowedThingsBoardHost` in `AlarmRule.kt` is an
  exact host list, not an `https://` prefix test. A prefix test accepts *any* TLS
  host, so the moment the base URL became configurable a mistyped host would
  have received a live bearer token. It also rejects userinfo, non-443 ports and
  paths, which is the `https://allowed.host@evil.example` trick. `AlarmParityTest`
  pins all five cases. `parseAllowedCctvUrl` does the same thing on the Dart side.
- **Nothing is exported that should not be.** `AlarmCheckReceiver` and
  `AlarmBootReceiver` are `exported="false"`; `AlarmDebugReceiver` exists only in
  the debug manifest *and* refuses unless the app is debuggable. Both production
  `PendingIntent`s are `FLAG_IMMUTABLE`, so there is no hijack surface. Verify
  the release APK has no debug component:
  `aapt2 dump xmltree app-release.apk --file AndroidManifest.xml | grep AlarmDebugReceiver`
- **No cleartext, no TLS bypass.** `usesCleartextTraffic` is never set and no
  custom `networkSecurityConfig` exists, so the platform default denies cleartext
  at `targetSdk` 36. No `TrustManager` or `HostnameVerifier` override exists
  anywhere, which is a common and quiet way to ship a broken TLS check.
- **Backup and transfer.** `allowBackup="false"` does **not** cover device-to-device
  transfer on Android 12+. `res/xml/data_extraction_rules.xml` and
  `backup_rules.xml` exclude everything from both paths.
- **Logging.** `org.json` embeds a fragment of the unconsumed response in its
  parse errors, and on the token refresh path that response is the JWT. Log the
  exception class, never the object.

Do not relax any of these without re-reading the reasoning above. Two of the
findings that mattered most were in code written the same week.

## Environment

**The project has been built on two machines, and the toolchain is not
identical between them.** Flutter, Dart and the RAM class are the same on both,
so nothing in this repo has to change when you switch — but the *paths* and the
*shell* do, and getting them wrong is the first thing that breaks a build.

### Windows — current machine

Shell is **PowerShell** (`pwsh`), not cmd and not bash. Write PowerShell syntax
in anything addressed to the user.

| Component | Version | Path |
|---|---|---|
| Flutter | 3.47.5 stable | `C:\src\flutter` (already on `PATH`) |
| Dart | 3.13.4 | ships with Flutter |
| OpenJDK | 21 | `C:\Program Files\Java\jdk-21` |
| JDK Flutter hands to `flutter build` | 25 (Android Studio JBR) | `C:\Program Files\Android\Android Studio\jbr` |
| Android SDK | 36.0.0 | `C:\Users\Fauzan\AppData\Local\Android\Sdk` (already on `PATH`) |
| adb | — | `...\Android\Sdk\platform-tools` (already on `PATH`) |
| Gradle user home | — | `C:\Users\Fauzan\.gradle` |
| RAM / cores | 7,3 GB / 8 | same class as the Linux box, so `concurrency: 1` still applies |

`flutter` and `adb` need **no** `PATH` change. `ANDROID_HOME`, `ANDROID_SDK_ROOT`
and `JAVA_HOME` are **not** set in the environment.

`gradlew.bat` nevertheless runs without `JAVA_HOME`, because the wrapper falls
back to `java` on `PATH` — Oracle's `javapath` shim, Java 21. That fallback
works, but it is a shim and not the JDK, so set it explicitly when you want the
toolchain to be deterministic:

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"
```

Note the asymmetry, because it is the kind of thing that costs an afternoon:
`flutter build` passes Android Studio's JBR (Java 25) down to Gradle, while a
direct `gradlew.bat` call uses `JAVA_HOME` (Java 21). Both were verified to
compile and build this project. If Gradle ever behaves differently between the
two invocations, that is the first thing to check.

**`android/local.properties` is machine-specific and git-ignored.** A checkout
that moved between machines still holds the *other* machine's paths, and this is
the most common cause of a first-build failure here:

```
sdk.dir=C\:\\Users\\Fauzan\\AppData\\Local\\Android\\Sdk
flutter.sdk=C\:\\src\\flutter
```

Flutter rewrites this file itself, so a wrong value usually self-heals on the
next `flutter` command. It does **not** self-heal for a bare `gradlew.bat`,
which reads the file directly — that is how a stale Linux path surfaces as
`flutter.sdk not set in local.properties` on a machine that plainly has Flutter
installed. Check this file first whenever a build dies before the Dart or Kotlin
stage.

Deliberately not installed, and not needed for an Android build: **Visual
Studio** ("Desktop development with C++"), so `flutter build windows` cannot
work, and **Chrome**, so `flutter run -d chrome` cannot work. Both appear red in
`flutter doctor` and both are irrelevant to this app, which is Android-only —
the alarm module is native Kotlin, and `AlarmBridge` latches to no-op everywhere
else.

### Linux — CachyOS / Arch, previous machine

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

## `dl.google.com` is throttled — use `curl`

**This was the single biggest time sink on the Linux machine.** It is a property
of *that machine's network*, not of the project, and it has **never been
re-measured on Windows** — see the caveat at the end of this section.

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

**Caveat for Windows.** The Windows machine was never benchmarked for this, and
the first release build there completed in 386 s with `gradle-9.3.1-bin` and the
NDK *already present* in `C:\Users\Fauzan\.gradle` and the SDK. So a normal build
downloads nothing and says nothing about throughput — it is not evidence that
the throttle is gone. If a first-time Windows build ever stalls on a download,
assume the same throttle applies and pre-stage with `curl.exe`; only measure
before claiming otherwise.

## Gradle memory

`android/gradle.properties` originally requested `-Xmx8G -XX:MaxMetaspaceSize=4G`,
i.e. 12 GB on a machine with 7.1 GB total. That cannot be satisfied. It is now
`-Xmx1536M` plus a 1 GB Kotlin daemon. Leave headroom for the DE, a browser and
adb — the sum must stay under physical RAM or the daemon gets OOM-killed.

The Windows machine is the same class — 7,3 GB and 8 logical cores — so these
values are correct there too and must not be raised. `dart_test.yaml`'s
`concurrency: 1` is correct on both for the same reason.

Evidence that the ceiling is real, not theoretical: the Linux checkout arrived
with three `Daemon compilation failed` logs under `android/.kotlin/errors/`.
That is the Kotlin daemon losing its fight for memory, and it fails exactly the
way the OOM warning predicts — a message about compilation, never about memory.

If a build is ever run on a larger machine, raise these. They are tracked in git
and shared between the Linux and Windows builds.

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

On the Windows machine the NDK is likewise already installed and equally
unused — `ndk\28.2.13676358` and `ndk\30.0.16248370` plus `cmake\3.22.1` and
`cmake\4.1.2` are all present in the SDK, and the release build produced no
`libdartjni.so`. Same conclusion, arrived at twice, on two machines.

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
  from another machine needs "Revoke pairings" then re-pairing. This bites
  specifically on a machine switch: the key lives at
  `C:\Users\<user>\.android\adbkey` on Windows, so the phone paired with Linux
  has never seen the Windows key and will fail until it is re-paired.
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
- `local.properties` is git-ignored and machine-specific. It has now held paths
  from **both** machines — `C:\src\flutter` first, then `/home/fzn/dev/flutter`
  after the project moved to Linux, then Windows again. Flutter regenerates it,
  but a first-build failure is worth checking there first, and a bare
  `gradlew.bat` needs it to already be right.
- NTFS is case-insensitive. Verified safe: the only same-named Dart files are
  `chart_card.dart` in two different directories. Keep it that way.
- Gradle writes thousands of small files to `build/` and `.dart_tool/`. This works
  but is slow. If builds become painful, moving the project to btrfs is the fix.

## Test suite

```
flutter analyze                                          # must stay clean
flutter test                                             # 455 tests, jalankan per-file
cd android && ./gradlew :app:testDebugUnitTest           # 11 tests, alarm parity + host allowlist
```

All three were re-run green on Windows on 29 September 2026. On Windows the
third command is `.\gradlew.bat` instead of `./gradlew`:

```powershell
flutter analyze
flutter test
cd android; .\gradlew.bat :app:testDebugUnitTest --console=plain
```

It resolves `JAVA_HOME` from `java` on `PATH` when the variable is unset, so on
Windows it runs without any environment setup at all. On Linux both
`JAVA_HOME` and `ANDROID_HOME` are required and must be exported first.

The Gradle unit tests exist to replay `alarm_parity_vectors.json` through the
Kotlin evaluator, because that half of the alarm logic has no other coverage and
cannot be reached from `flutter test`. `org.json` is a stub in a local unit test
classpath and throws, which is why `build.gradle.kts` puts a real `org.json` in
front of it for the test source set only.

`dart_test.yaml` sets `concurrency: 1` **on purpose**. Both machines have ~7 GB
of RAM and only 1.4–2.4 GB free during a test run; the Dart compiler and the test
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

## The battery sign convention, measured on the device

**The current BMS reports negative current and negative power while the pack is
discharging.** Confirmed on the test device on 27 September 2026 after a BMS
swap: `Power -22 W` while the state of charge was *falling*. The **previous**
BMS reported the opposite — `Current -0.97 A`, `Power -12.92 W` while the charge
was *rising* at 69 % — and the swap inverted every battery display in the app
without a single red indicator, exactly as this section warned it would. The
mapping lives in `batteryChargeState` (`lib/utils/battery_sign.dart`), pinned by
`battery_sign_convention_test.dart`, so the next swap fails a test that says what
to re-measure instead of quietly inverting the app.

Three things follow, and all three have already been got wrong once:

- **Read `power` from the device. Do not multiply `voltage * current`.** The BMS
  publishes `voltage`, `current` and `power` as separate keys. Deriving power
  from the other two collapses to exactly zero whenever `current` reads `0.00 A`,
  which this BMS does report while it is idle, and drifts from the reported
  figure whenever the pack is not sitting at its nominal voltage.
- **Do not flip the sign at the call site.** The hero card receives
  `latestValues['power']` raw, sign and all, so its figure matches the Battery
  page one tab away. Negating it to make the hero read "Charging 12 W" was tried
  and reverted: two screens reporting different numbers for one measurement is
  worse than an odd-looking minus, because the reader has to work out that a
  minus became a plus. The label carries the direction, not the number.
- **Zero current is not a direction.** The pack genuinely sits in standby for
  stretches, and the sign of a zero reading is pure noise, so any UI that picks
  one of two labels will flip several times a minute. There are three states —
  charging, standby, discharging — and standby is the one that gets skipped.

**Do not "fix" the sign at the call site, and do not edit
`batteryChargeState` from a screenshot.** Only the state-of-charge trend settles
which sign means which direction. If the BMS is ever replaced, watch the SOC for a
minute while the sign is fixed, note which way it moves, and update
`battery_sign_convention_test.dart` with the measurement in the reason string.

## Regression guards worth knowing about, all added because of a real bug:

- `cctv_test.dart` — `parseAllowedCctvUrl` host allowlist
- `chart_bounds_test.dart` — `niceStep` / `niceTimeStep` axis rounding
- `dashboard_helpers_test.dart` — `describeHistoryRange` must agree with
  `historyTimeWindow`
- `energy_forecast_service_test.dart` — battery discharge sign convention
- `battery_sign_convention_test.dart` — which sign means which direction, with
  the SOC-trend measurement in the reason string (the BMS swap of 27 Sep 2026
  inverted the old convention)
- `alarm_rules_test.dart` — a device that produced no reading is not stale, and
  TDS keeps no upper bound
- `alarm_parity_test.dart` + `AlarmParityTest.kt` — the Dart and Kotlin alarm
  evaluators must produce identical messages. When writing a scenario, put the
  *reason* in `description`; that string is what a failure prints, and it is the
  only thing that will tell you which assumption broke.

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
  with them. Upgrading to `package_info_plus` 10.x requires `win32 ^6.0.1`,
  but `flutter_secure_storage_windows` 3.x still requires `win32 ^5.0.0`.
  Upgrading `flutter_secure_storage` to 11.x would require also upgrading
  `flutter_secure_storage_platform_interface` (pinned in dev_dependencies
  for testing). This is a **coordinated upgrade** — do not attempt it piecemeal.
- `thingsboard_api.dart` (~560 lines) is the integration core and has 24 tests
  covering token/session handling, WebSocket URI construction, telemetry key
  sets, and offline caching. `thingsboard_realtime_service.dart` has 21 tests
  covering service lifecycle, device configuration, and telemetry models.
- **Everything about weather in this file used to be here and is now gone.** The
  `WeatherService`, its 15 tests, the One Call parsing fix, the HTTPS geocoding
  fix, and the `dispose()`/GPS-handle work were all deleted together with the
  OpenWeatherMap integration in 1.6.0 — see `FEATURE.md` §8 for what was lost
  and why. Kept as a note because the reasoning is worth having: the integration
  was removed for duplicating numbers that other tabs already showed, and because
  `weather_api_key` was the only credential in plain `SharedPreferences` instead
  of secure storage. The lesson generalises — a new integration that only
  re-presents existing telemetry is a candidate for the same treatment, and a new
  credential belongs in `flutter_secure_storage` from the first commit.
- `dart_test.yaml`, the JVM heap in `gradle.properties`, and the
  `gradle-wrapper` `-bin` distribution were chosen for the 7 GB Linux machine but
  are tracked in git, so they apply to Windows builds too. The Windows machine is
  the same RAM class, so the values are still correct there.
- The alarm module is Android-only and nothing degrades gracefully yet. On iOS,
  desktop and web, `AlarmBridge` sees `MissingPluginException`, latches
  `isUnavailable`, and every call becomes a no-op. That is safe but means
  background alarms are an Android feature with no equivalent elsewhere, and the
  `status` read used for diagnostics returns null there. Worth surfacing in the
  UI before shipping on a second platform.
- A rule naming a device that is not in the config is rejected by
  `parseAlarmConfig`, and a config with rules but no devices is rejected. Both
  exist because the alternative is a monitor that is silently blind to a
  condition, which is the failure mode this whole feature keeps running into.
- `progress.md` is a handoff document. §8 (manual device verification of the chart
  date label and the TDS field) was completed on 26 September 2026. §5B.1, §10.5
  and everything after describe the `android_alarm_manager_plus` setup that has
  been replaced; read them for the reasoning, not for the wiring.
- A code-review agent claimed `dashboard_screen._history` was dead code and a
  memory leak. It was wrong — `TelemetryChartCard` reads it — and acting on that
  claim without a grep would have deleted a live field. **Verify a "dead code"
  claim with a search before removing anything.** A confident, well-argued report
  is still a report.

## Documentation hygiene

`CHANGELOG.md` was consolidated during the 1.4.0 release: it had three
`[Unreleased]` headers and three conflicting `1.3.0` headings from an unclean
merge. Keep exactly one `[Unreleased]`, and map it to a version at release time
rather than letting it grow. `pubspec.yaml` is the single source of truth for
the version number.

`PRD_PLTS_Monitoring_App.md` and `PRD_GitHub_Release_Process.md` both still
quote 1.3.0 and 1.2.3 respectively. They are living documents, not release
records, so bring their version headers up to date when cutting a release.
