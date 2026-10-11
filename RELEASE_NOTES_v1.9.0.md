# EnerGrow 1.9.0 (build 18)

**Midnight Categorical** — one visual system instead of four, colour as a
vocabulary, three typefaces bundled.

## What changed

### One design, not four

The four appearance presets (`light`, `dark`, `dracula`, `skeuo`) are gone. The
app is dark by design, and the soft-UI layer they required is gone with them: a
card is a tonal step above the page, bounded by a 1px hairline, rather than the
same colour lit by a three-shadow pair.

- `design_tokens.dart`: 1219 → 420 lines. `AppTheme`, `AppElevation`, `AppSkeuo`
  deleted. `AppBorders` replaces the shadow system.
- `liquid_glass.dart`: 850 → 380 lines. The primitives keep their names and lose
  their `theme:` parameter.
- Card radius 16 → 24 (the brief's `rounded.xl`).

### Colour is categorical

`metricColor` accepted an `index` and deliberately ignored it; a test failed
loudly if it ever started using it. That rule is reversed. Each category of data
now owns a hue and every appearance of it reuses it:

| Category | Hue | Hex |
|---|---|---|
| PV / solar | `accent` | `#FCE570` |
| AC / load | `secondary` | `#8E99F3` |
| Battery | `primary` | `#F7A5A5` |
| Environment | `chartViolet` | `#C084FC` |
| Water | `chartCoral` | `#FF8577` |

The red/green/blue chart triad is retired — it was applied identically to all
nine electrical series, which under a categorical system is wrong. The energy
report's amber/blue pair and the CCTV status colours were two more competing
systems; all three now resolve to the same hues.

### Three typefaces

Space Grotesk (500, 700) for numerals, Plus Jakarta Sans (500, 700) for
uppercase tracked labels, JetBrains Mono (500) for tabular ratios. The brief
asks for weight 900; Space Grotesk's axis stops at 700, so all styles are 700 and
the reason is recorded at the scale.

### Settings → Appearance removed

The theme picker and accent swatches are gone. Colour is now a vocabulary — a hue
means a category of data — so letting the user repaint the app would destroy the
one thing the palette is for.

### Solar condition card

`SolarConditionCard` converts the greenhouse lux reading to W/m², so a number
the user has no feel for becomes a reading they do.

## Known limitations

- **The `primary`/`error` hue collision is unverified on device.** Battery is
  `primary` (`#F7A5A5`, hue 0°) and a breach is `error` (`#EF4444`, hue 0°) —
  the same hue family, 21 points of lightness apart. The mitigation is
  structural: a category hue is always a fill, `error` is always ink. This is
  the one failure mode `flutter analyze` cannot see and no test can reach.
- **The light-theme shadow reduction from `615644f` is retained** but the
  top-edge scanline was never re-measured on device.
- **The full `flutter test` does not finish on a 7 GB machine.** 645 tests pass
  across 51 files per-file; the tail of a long file reports `did not complete`,
  which is the documented OOM symptom, not a failure — every such test passes on
  its own.

## Verification

| Check | Result |
|---|---|
| `flutter analyze` | clean — 0 errors, 0 warnings |
| `flutter test` (per-file) | 645 passed, 51 files, 1 file OOMs at the tail and passes standalone |
| `flutter build apk --release` | succeeds |
| Signing certificate fingerprint | matches `504d13ee…` |
| `AlarmDebugReceiver` in release APK | absent |

## Installation

Download `EnerGrow-v1.9.0.apk` from this release and install it. The signing
key is unchanged, so it upgrades over any previous install without losing the
ThingsBoard session or local preferences.

```powershell
adb install -r EnerGrow-v1.9.0.apk
```

## Full changelog

See `CHANGELOG.md`, attached to this release.
