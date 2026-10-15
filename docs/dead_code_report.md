# Dead code report — EnerGrow (PLTS Monitoring)

Audit date: 15 October 2026. Branch: `fauznazz-afk/deadcode`.

Scope: unused functions, classes, widgets and assets in `lib/`, `test/` and
`screens/`, with the evidence that produced each verdict. Removal was limited to
symbols proven dead by a repo-wide reference count; public/shared API was left in
place unless it had zero callers *and* no test pinned it.

## Method and evidence

1. **Analyzer (authoritative for private/unreferenced declarations).**
   `flutter analyze` reported `No issues found!`. `unused_element` and
   `unused_local_variable` are analyzer diagnostics that are on by default, so a
   clean run is direct evidence that **no private declaration in `lib/` is
   unreferenced**. There are also zero `// ignore:` comments in `lib/`.
2. **Reference count over `lib/` + `test/`.** Every top-level `class`, `mixin`,
   `enum`, `extension` and function name declared in `lib/` was extracted and
   matched with `\bName\b` against the concatenated text of every `lib/` and
   `test/` `.dart` file. A declaration with a count of 1 has no reader.
3. **Manual verification** of every hit with `grep`, reading the call site and
   the branch that would render it.
4. **Assets.** Every `assets:` entry in `pubspec.yaml` was grepped; every font
   family in `AppType` was traced to its `fontFamily:` usage.

Evidence commands (PowerShell, from the repo root):

```powershell
flutter analyze
flutter test test/<file>            # or .\tool\run_tests_per_file.ps1
```

## Findings

| # | Symbol | Location | Verdict | Action |
|---|---|---|---|---|
| 1 | `chartSeriesColor` | `lib/screens/dashboard/utils/color_helpers.dart` | **Dead** — 0 references in `lib/` and `test/` | **Removed** |
| 2 | `ConnectionTransportHealth.statusMessage` | `lib/services/connection_health_service.dart:62` | **Dead** — 0 references | Reported, left in place (public model API) |
| 3 | `ConnectionHealth.statusMessage` | `lib/services/connection_health_service.dart:151` | **Dead by unreachability** — referenced only in a branch that never renders | Reported, left in place |
| 4 | `_cctvKeepAlive` | `lib/screens/dashboard_screen.dart:308` | **Inert** — private `ValueNotifier(0)` never assigned | Reported, left in place |
| 5 | `EnergyForecastResult.peakUsageAt` / `.sampleStart` / `.sampleEnd` | `lib/services/energy_forecast_service.dart:24,26,27` | **No production reader** — only test assertions | Reported, left in place |
| 6 | `SkyCondition.isDaylight` | `lib/utils/solar_irradiance.dart:149` | **No production reader** — only `test/` | Reported, left in place |

### 1. `chartSeriesColor` — removed

`lib/screens/dashboard/utils/color_helpers.dart`. Reference count = 1 (the
declaration only); the only other match in the whole repo is a `CHANGELOG.md`
line recording an earlier deletion.

The logic it held ("one series → category hue, many → fixed order") now lives
inline in `lib/screens/dashboard/widgets/chart_card.dart:310-322`
(`_buildSeries`), which reads `kChartSeriesOrder[i % kChartSeriesOrder.length]`
directly. `categoryColorForKey`, which `chartSeriesColor` called, is still used
by `chart_groups.dart:43` and is kept. Nothing in `lib/` or `test/` referenced
the function, so removal is behaviour-preserving. `flutter analyze` stays clean
and the suite is unchanged after removal (see Verification).

### 2. `ConnectionTransportHealth.statusMessage` — dead, kept

A public getter on a public model class with zero readers anywhere. It is the
class-level analogue of finding 3 and is already named as unreachable in the doc
comment at `connection_health_service.dart:20-23`. Left in place: it is part of
the exported model surface and the task scopes removal to clearly dead *private*
code. Deleting it is a follow-up decision, not a mechanical one, because that
same comment describes its history.

### 3. `ConnectionHealth.statusMessage` — dead by unreachability

`connection_health_service.dart:151`. It *is* referenced — at
`lib/screens/dashboard/widgets/banners.dart:331` and `:404` — but both sites are
the `label` of a `ConnectionStatusBanner(Switcher)` whose reads resolve to the
`failed` or `stale` branch, and both of those branches **override** the label:

```dart
final stale = !failed && staleNames.isNotEmpty;
final label = failed
    ? 'ThingsBoard unreachable'
    : stale
    ? 'Connected - stale data: ${staleNames.join(', ')}'
    : health.statusMessage;   // <- only reached when neither failed nor stale
```

The only call site of `ConnectionStatusBannerSwitcher` is
`dashboard_screen.dart:1897-1959`, and it is returned **only** when `failed` is
true (line 1909) or `stale.isNotEmpty` (line 1946); otherwise
`_statusStripBuilder` returns a different widget or `SizedBox.shrink()`. So
`health.statusMessage` is never the string that reaches the screen. Confirms
`FEATURE.md` §18.2. Left in place because removing it means editing the banner's
label expression, and the reader gain is zero.

### 4. `_cctvKeepAlive` — inert, kept

`lib/screens/dashboard_screen.dart:308`, a private `ValueNotifier<int>` created
as `ValueNotifier(0)`, disposed at `:406`, and passed as the `listenable` of two
`Bound` wrappers (`:2577`, `:2631`). It is **never assigned**, so it never
notifies; the CCTV panels rebuild only through their `Bound` token
(`'$_cctvUrl...'`). This matches `FEATURE.md` §18.2 ("tidak pernah ditulis").

Not removed: it is the only inert `Listenable` in scope for those two `Bound`s,
and it *is* referenced. Replacing it needs a considered substitute (an inert
listenable that is stable across rebuilds), so this is a wiring change rather
than a dead-code deletion.

### 5. `EnergyForecastResult` timestamp fields — no production reader, kept

`peakUsageAt`, `sampleStart`, `sampleEnd` are computed and stored but read only
by `test/energy_forecast_service_test.dart:23-26`. Every other field of the class
(`observedProductionKwh`, `dailyProductionEstimateKwh`, `productionTargetKwh`,
`targetProgress`, `peakUsageWatts`, `batteryDepletionHours`, `hasProduction`) is
consumed by `lib/widgets/energy_summary_card.dart` and `dashboard_screen.dart`.
Kept, because deletion would also delete live test coverage of `calculate()` with
no behaviour change.

**`FEATURE.md` §18.2 is stale here.** It also lists `batteryStateOfCharge`,
`hasPeakUsage` and `hasBatteryEstimate` on `EnergyForecastResult`; those three
symbols **do not exist in the source** and have no references. It also places
`_cctvKeepAlive` under CCTV; it actually lives in `dashboard_screen.dart`.

### 6. `SkyCondition.isDaylight` — kept

`lib/utils/solar_irradiance.dart:149`. Zero production readers; referenced only
by `test/solar_irradiance_test.dart:255-265`, which pins both its true and false
cases. Public API with active test coverage → not dead, not removed.

## Assets — all used

| Asset | Declared | Used at |
|---|---|---|
| `assets/energrow_logo.png` | `pubspec.yaml:95` | `lib/widgets/brand_logo.dart:44` |
| `assets/user_icon.png` | `pubspec.yaml:96` | `lib/screens/login_screen.dart:162`, `lib/screens/dashboard/widgets/greeting_header.dart:56` |
| `Inter-{Regular,Bold,Black}` | `pubspec.yaml:112-116` | `AppType.heading` / `.sans` (`design_tokens.dart`) |
| `JetBrainsMono-{Medium,Bold}` | `pubspec.yaml:139-141` | `AppType.mono` (`design_tokens.dart:459`) |

No unreferenced asset or font.

## Classes, widgets, enums, extensions — no dead declarations

The repo-wide class/type scan returned **one** candidate, `SkyConditionLabel`,
and it is a false positive: it is an `extension` whose members are consumed as
`condition.label` (`overview_panel.dart:323,343`; `solar_condition.dart:92,133`;
`dot_glyph.dart:49`). Extensions are referenced by their *members*, not their
name, so a name-only count under-reports them. No unreferenced widget, screen or
service class was found.

## Change made

Single deletion, proven dead before it was removed:

- `lib/screens/dashboard/utils/color_helpers.dart` — removed the
  `chartSeriesColor` function and its doc comment (11 lines). No other file
  changed.

## Verification (after removal)

```powershell
flutter analyze                          # No issues found! (ran in 12.9s)
.\tool\run_tests_per_file.ps1            # files: 64  tests passed: 827  files failing after retries: 0
```

## What was not done, deliberately

- Public API (`ConnectionTransportHealth.statusMessage`,
  `ConnectionHealth.statusMessage`) was left in place per the "avoid deleting
  shared APIs until verified" rule; both are verified dead but their removal
  reaches into the banner/model surface.
- `FEATURE.md` §18.2 was **not** edited even though three of its entries are
  stale; that file is a living document owned by the feature writers, and the
  correction belongs with whoever next touches it.
