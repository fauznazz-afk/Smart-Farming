# Visual audit goldens

Golden images of the WattVision design, written by
`test/visual_audit_test.dart`.

Each PNG is one key screen rendered at **411 dp wide** inside the app's real
`AppBackground`, on the app's real tokens — so a human can see the design
without a device.

## How to regenerate

```powershell
flutter test test/visual_audit_test.dart --update-goldens
```

The first run on a clean checkout also writes these files on its own (see the
header of `test/visual_audit_test.dart`), because a bare `flutter test` would
otherwise fail with no golden to compare against.

## Why every file ends in `_dark`

WattVision is dark-only: `AppTheme.apply` clamps every brightness to
`Brightness.dark`, so a `_light` variant would be a byte-identical duplicate of
its dark twin. The `_light.png` files were deleted rather than regenerated. The
ramp suffix stays in the name so a second ramp is a one-line change to `kRamps`
rather than a rename of every golden.

## What each one is

| file | shows |
|---|---|
| `glass_nav_bar_expanded_dark.png` | the bottom tab bar, four destinations, active item in a cyan bubble with dark ink |
| `live_power_card_dark.png` | the hero card: flow labels, split bar, SOC gauge, the cyan meter glow |
| `telemetry_card_dark.png` | a device key/value list with the stale notice |
| `energy_summary_card_dark.png` | the two energy tiles, with the `Bs.` equivalent beside each kWh |
| `date_strip_dark.png` | seven day chips, selected chip solid accent with dark ink |
| `telemetry_chart_card_dark.png` | a real line chart: legend, shared Y axis, statistics row |
| `settings_row_dark.png` | one settings `SectionCard`: icon badge, divider, tappable row |
| `dashboard_screen_dark.png` | the whole dashboard at phone width |
| `settings_screen_dark.png` | the settings list |
| `energy_report_dark.png` | the report with its period selector and totals |
| `ai_chat_dark.png` | the assistant, with the unconfigured state |

## Before you trust anything in this folder

`inter_is_actually_loaded` in `test/visual_audit_test.dart` measures the width
of `Solar` at 10px. **If it fails, Inter did not load and every PNG here is
blocky rectangles** — the flutter_test font set falls back to Ahem, which draws
one square per glyph, and the harness loads the bundled Inter, JetBrains Mono
and MaterialIcons families explicitly to prevent that.

Also note that text rasterisation is platform- and Flutter-version specific: a
golden generated on Windows will not byte-match one generated on Linux. That is
documented Flutter behaviour, not drift.
