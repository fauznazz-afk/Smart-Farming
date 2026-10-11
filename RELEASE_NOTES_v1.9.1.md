# EnerGrow 1.9.1 (build 19)

The sky card moves to where its question is asked, shows lux instead of W/m², and
Settings gets tighter. Fixes a brightness bar that drew full at every reading
above 1.8% of a sun.

## What changed

### The sky card is on Overview now

It was on Hydroponics because that is where the lux sensor lives — which is a
statement about *ownership*, and it put the card on the wrong page. The PV card
on Overview asks why the array is producing what it produces; this card answers
what the sky is currently offering. Two halves of one question, a tab apart.

Hydroponics keeps the sensor's numbers in the environment grid, which is where
they already were.

### It shows lux, not W/m²

Before:

```
443    W/m²
MOSTLY CLEAR
━━━━━━━━━━──── 54% of a clear noon
```

After:

```
41200  lx
MOSTLY CLEAR
━━━━━━━━━━────
```

The conversion was sound arithmetic and it was still the wrong number to show. A
W/m² figure is a quantity the PV card is the authority on, and a user asking
what the sky is doing should not have to interpret a photometric-to-radiometric
conversion to find out.

The conversion is still used — it drives the brightness bar, because a fraction
of one sun is a bounded thing to fill a track with and does not need spelling
out. The words do the answering.

### Settings is more compact per block

| | Before | After |
|---|---|---|
| `SectionCard` padding | 16 | 12 |
| Card bottom | 12 | 8 |
| Divider gaps | 12+4 | 4+4 |
| Category rows | 16 | 12 |
| Drill-in top / bottom | 12 / 24 | 8 / 16 |

The bottom reserve was holding space for a shadow that no longer exists.

### Fixed: the brightness bar drew full at every reading above 1.8% of a sun

The track is a `Container` inside a `Column(crossAxisAlignment: start)`, so it
sized itself to its own child instead of stretching. The bar came out 208 dp on a
card 387 dp *inside*, so the fill and the track were the same width and every
reading looked like full sun.

**The old tests could not see it.** `never draws wider than its track` passed,
because the fill and the track *were* the same width, and the percentage was only
ever asserted as text. The new test reads the bar's rendered width against the
track's — the first thing in the suite to describe the shape rather than the
caption.

## Verification

| Check | Result |
|---|---|
| `flutter analyze` | clean |
| `solar_condition_card_test` | 12 passed |
| `settings_screen_test` | 11 passed |
| `solar_irradiance_test` | 21 passed |
| Signing certificate fingerprint | matches `504d13ee…` |
| `AlarmDebugReceiver` in release APK | absent |

## Installation

Download `EnerGrow-v1.9.1.apk`. The signing key is unchanged, so it upgrades over
1.9.0 without losing the ThingsBoard session or local preferences.

```powershell
adb install -r EnerGrow-v1.9.1.apk
```

## Full changelog

See `CHANGELOG.md`, attached to this release.
