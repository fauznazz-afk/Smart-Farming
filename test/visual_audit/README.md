# Visual audit goldens

Golden images of the "Neon Brutalist Mobile" restyle, written by
`test/visual_audit_test.dart`.

Each PNG is one key screen rendered at **411 dp wide** inside the app's real
`AppBackground`, on the app's real tokens — so a human can see the new design
without a device.

## How to regenerate

```powershell
flutter test test/visual_audit_test.dart --update-goldens
```

The first run on a clean checkout also writes these files on its own (see the
header of `test/visual_audit_test.dart`), because a bare `flutter test` would
otherwise fail with no golden to compare against.

## What each one is

| file | shows |
|---|---|
| `glass_nav_bar_expanded.png` | the flat bottom tab bar, four destinations, active item in acid lime |
| `glass_nav_bar_collapsed.png` | the bar collapsed to the single lime circle |
| `live_power_card.png` | the hero card: flow labels, split bar, SOC gauge, the `4px 4px 0` stamp |
| `telemetry_card.png` | a device key/value list with the stale notice |
| `metric_grid.png` | a 3-up grid of metric tiles, including the 2px categorical bottom border |
| `energy_summary_card.png` | the two energy tiles and the range selector |
| `date_strip.png` | seven day chips, selected chip solid accent with dark ink |
| `telemetry_chart_card.png` | a real two-series line chart: legend, shared Y axis, statistics row |
| `cctv_standby_overlay.png` | the standby play button and its label over the video matte |
| `settings_row.png` | one settings `SectionCard`: icon badge, divider, tappable row |

## Before you trust anything in this folder

`inter_is_actually_loaded` in `test/visual_audit_test.dart` measures the width
of `Solar` at 10px. **If it fails, Inter did not load and every PNG here is
blocky rectangles** — the flutter_test font set falls back to Ahem, which draws
one square per glyph, and the harness loads the three bundled Inter faces
explicitly to prevent that.

Also note that text rasterisation is platform- and Flutter-version specific: a
golden generated on Windows will not byte-match one generated on Linux. That is
documented Flutter behaviour, not drift.
