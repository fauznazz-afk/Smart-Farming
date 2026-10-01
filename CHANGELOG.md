## [1.7.1] - 2026-10-01

### Removed

- **The biometric unlock gate.** At cold start, a stored ThingsBoard session was
  held behind a fingerprint or face prompt. It is gone: `_SplashRouter` now
  routes straight to the dashboard when a session exists, and straight to
  `LoginScreen` when it does not. There is no lock screen, no fingerprint
  button, and no second factor.

  Removed with it: the `local_auth` dependency, the `USE_BIOMETRIC` Android
  permission, and the `NSFaceIDUsageDescription` key in `ios/Runner/Info.plist`
  — which shipped a user-facing Face ID string for a feature that no longer
  existed, and was found only because the removal was audited rather than
  assumed complete.

  **`MainActivity` is now a plain `FlutterActivity`.** It extended
  `FlutterFragmentActivity` for exactly one reason: `local_auth` needs a
  Fragment to host its `BiometricPrompt`. That reason is gone, so the superclass
  went with it. This is stated explicitly because "why is this not a
  `FlutterFragmentActivity`?" is the question a future reader will ask, and
  grepping the repository will now find nothing.

  Note what this gives up: the lock screen was the only thing standing between
  someone holding an unlocked phone and this app's telemetry. The JWT in
  `flutter_secure_storage` is unaffected, and so is the rest of the security
  posture described in `AGENTS.md`, which never depended on the biometric gate.

### Fixed

- **Dracula's cards read flat, and the derivation that produced them was wrong by
  1.9x.** This is the one item of 1.7.0 that had never been seen on a device,
  and it turns out the reason it had not been seen was that it would not have
  survived looking at.

  The alphas were solved so that every shadow's *composited* absolute luminance
  step on `#282A36` equalled the step the same shadow makes on the dark page.
  That is a claim about `Color.lerp`, and `test/design_tokens_test.dart`
  asserted it to within 0.0007 and passed. It says nothing about what reaches
  the screen, because the mask blur removes a different fraction of each page's
  shadow.

  Measured on the Xiaomi, same build, same card, right-hand edge, 8-bit
  luminance scanline:

  | | page | contact | measured ΔL | as a fraction of the page |
  |---|---|---|---|---|
  | dark `#1A211F` | 31.4 | 15.5 | **15.9** | 51% |
  | dracula, as shipped in 1.7.0 | 42.4 | 34.2 | **8.2** | 19% |

  Dracula was delivering 52% of the dark theme's drop. Fifty-two percent, with
  every test green.

  **The correction is two measured data points, not a new solve.** The relation
  between alpha and measured ΔL is convex — the blur eats most of a weak
  shadow's peak and little of a strong one's — so the same fractional alpha
  increase buys far more ΔL when it starts from a low base:

  | contact alpha | measured ΔL |
  |---|---|
  | `0x50` | 8.2 |
  | `0x8C` | **20.0** ← shipped |
  | `0x98` | 21.3 |

  A uniform 1.9x overshot to `0x98` and read heavier than the dark theme. `0x8C`
  lands at 47% of Dracula's page against dark's 51% of its own — near parity,
  slightly softer, which is the intent.

- **Only the dark halves moved.** Every `0x??000000` across `raised`, `inset`,
  `insetDeep` and `pressed` was corrected by the measured factor; every
  `0x??FFFFFF` is still the value the original solve produced. The dark half is
  the one that was measured and the one that was failing, so it is the only one
  there is evidence to move. Scaling the light halves by a number borrowed from
  the other half would repeat the exact mistake this release corrects.

  The visible consequence is that Dracula's light-to-dark relationship has
  **inverted**: on the dark theme the light half defines the edge, at a ratio of
  3.80; on Dracula the corrected dark half now does most of the work, and the
  pair measures 2.41. The ratio guard in `design_tokens_test.dart` moves from a
  10% band to a 40% band, which is a real loss of precision bought on purpose
  and recorded as such in the test.

- **The hairline was the brightest thing on the card edge on both dark themes,
  and on Dracula it outshone the bounce shadow.** 1.7.0's Dracula cards read as
  outlined rather than embossed, and this is why: the one-pixel hairline was
  landing at +17.0 luminance against a page of 42.4 while the bounce that is
  supposed to define the edge only managed +16.0.

  Measured on the Xiaomi, one card, one build, 8-bit scanline:

  | | page | bounce | hairline | as a fraction of the page |
  |---|---|---|---|---|
  | light `#E1E7E4` | 229.5 | — | 244.5 (+15.0) | +6.5% |
  | dark `#1A211F` | 31.4 | 51.6 (+20.2) | 48.7 (+17.3) | +55% |
  | dracula `#282A36` | 42.4 | 58.4 (+16.0) | 59.4 (+17.0) | +40% |

  The cause is not obvious from the token file. White has 255 of headroom above
  every page in the app, but a page at 229.5 can only be lifted 25.5 units by
  going to pure white while a page at 31.4 has 223.6 available. One alpha
  therefore spans a factor of nine in perceived weight across the three presets.
  **An alpha is not a perceptual quantity**; the gap between the page and white
  is, and the three pages do not share it.

  Dark themes move from `0x14` to `0x0A`. Measured after: the hairline lands at
  +9.0 on dark and +8.0 on Dracula, against bounce peaks of +20.2 and +16.0, so
  the shadow is unambiguously the brightest thing on the light edge — which is
  what a dark surface is supposed to look like. Light is left at `0x99` because
  it is already doing that job.

  The previous doc comment claimed the hairline was "a whisper, not an outline".
  It was not a whisper on a dark page, and nobody had put a ruler on it. This is
  the same defect the accent-tinted hairline caused in 1.7.0, one step further
  down the alpha scale.

- **Three widgets on the Overview page invented zeros for telemetry that had
  never arrived.** `acPower`, `batteryPower`, `soc`, `voltage` and `frequency`
  were non-nullable and filled in at the call site with `?? 0.0`. So a BMS that
  had never reported rendered as a red **0%** beside `min 20%` with a
  `battery_alert` glyph, and an absent meter as a red **Unstable 0 V - 0 Hz**.
  Both verdicts fail on zero, so an absence became a fault.

  The furthest-reaching part was in words rather than in a number. With a real
  solar figure and a fabricated house draw of zero, `LivePowerCard`'s closing
  sentence resolved to **"The array covers the house load"** — a confident claim
  about the user's own house, derived from data that never arrived, and with no
  minus sign to make a reader suspicious.

  `SystemStatusStrip` now widens `_Verdict.ok` to `bool?`, because "no reading"
  is deliberately neither good nor bad: not the status colour, since nothing has
  gone wrong, and not the accent, since the accent there means "this verdict is
  good" and we do not know that. `LivePowerCard` prints `--`, names the pack
  `Battery` rather than inventing a direction — a zero reading is `standby`, an
  absent one is a claim about our knowledge — and leads the closing sentence with
  "House draw unavailable until the meter reports" in `faint`, because an absent
  meter is not a shortfall.

- **Two overflows in `LivePowerCard` that only appeared above a 1.0 font scale.**
  The three flow terms share about 89 dp each at the documented 381 dp viewport,
  and a battery figure of `-1250` needs roughly that much for a sign, four
  digits, icon, gaps and unit at 24 sp. The figure was a non-flex `Row` child, so
  it got unbounded width and could never shrink. Same for the header's title and
  age label either side of a `Spacer` that absorbs zero in exactly the case that
  matters — and the age label is the only liveness indicator on the card.

  Both are now `Flexible` plus `FittedBox.scaleDown`, not `ellipsis`. A number
  scaled down is still readable; a cut-off number cannot be told from a rounded
  one.

- **A failed chart request was reported as "No data for this range".**
  `_fetchHistoryFor` caught every exception and substituted an empty map, so a
  dropped connection and a quiet day reached the card as the same value. That
  sentence is not neutral: it tells the user the greenhouse produced nothing,
  which sends them out to look at the plants, for what is overwhelmingly a
  network problem. It now says "Could not load this range", and the failure is
  cleared on the next attempt so a recovered chart does not keep warning.

- **Four controls had no feedback at all.** `Scaffold`'s single `Material` paints
  its ink features *below* its own child subtree, and the dashboard body is an
  opaque `ColoredBox`, so the two banner retry buttons and the date-strip calendar
  button had their splash painted underneath it — invisible, not faint. That
  matters more than usual here because the app's whole vocabulary is "no ripple,
  geometric press instead", so those were the only controls with no feedback of
  either kind. Same fix as `AppCard`: a transparent `Material` between the
  decorated box and the content. The retry buttons also gained a tooltip and a
  `Semantics` label, which neither had.

  The calendar button was also a 26–28 dp target against a 48 dp floor, on the only
  date control that exists on three of the four tabs.

- **Pull-to-refresh refetched nothing when a poll was in flight, and still
  dismissed its own spinner.** Both guards were left alone — they stop the
  10-second poll stacking requests on a slow link — and each request now also
  publishes a `Completer` that the gesture awaits, so it always ends in a fetch
  that happened after the finger lifted. Completed in a `finally`, because a
  completer that never completes hangs the spinner forever.

- **Tapping today's date chip did nothing while a custom range was active.** The
  early return compared only `_selectedDate`, so a committed today-to-today range
  left the strip with no chip lit and no way back to a single day except the
  picker.

- **Metric grid readings were cut off at a large font scale** — `2396` at 22 sp
  fits a three-column card at 1.0 and is wider than the slot at 2.0, and that
  turbidity reading is real. This is the third truncation this repo has shipped
  (`109....`, `max 300...`, and now `239...`); all three passed `flutter analyze`,
  a release build and every existing test, because none of them can see a pixel.
  The figure now scales down instead.

- **`DateStripChip` quietly overrode the user's font scale.** The day name was in
  `SizedBox(height: 13)` with a `FittedBox` inside, so at 2x it was laid out at
  20 sp and scaled straight back to 13 dp — rendering at its 1.0 size whatever the
  user asked for. The fixed box is gone and `height: 68` became
  `minHeight: 68`, so the chip grows instead of shrinking its text. The second half
  of that was found by the test: with the text free to grow but the height still
  fixed, it overflowed by 40 px.

- **`cardTheme.elevation` was `0`, directly under a comment saying it supplies the
  shadow.** The four energy-report cards rendered as page-coloured rectangles with
  a hairline and no depth, in a different surface language from every `AppCard` on
  the dashboard. The comment stated the intent and the value contradicted it,
  which is the most durable kind of bug: it reads as done.

- **`AppCard.semanticLabel` did not suppress its children**, so a screen reader
  read the caller's summary and then walked every `Text` beneath it. For a chart
  card that meant the summary, the legend, the live values and three statistics
  rows — all of which the summary had just said in one sentence. Cards without a
  label are untouched: they have no summary, so their contents are the only
  description there is.

- **The login form's username field had no `textInputAction`.** Flutter resolves
  a single-line field's null action to `done`, which unfocuses unless an
  `onEditingComplete` or `onSubmitted` is given; neither was. The keyboard offered
  "Done", the user pressed it, and nothing happened, with a password field
  directly below. The password field already had `onSubmitted`, which is why the
  last step of the form worked and this one did not.

- **A single-series chart's label was unconstrained.** `maxLines: 1` and
  `ellipsis` on a non-flex `Row` child can never take effect, so the `Flexible`
  sibling received whatever was left — which is zero once the label is wide. Both
  sides are now `Flexible` with the label on the lower flex, because a label that
  can push the numbers to nothing reintroduces from the other side the very
  truncation its sibling `FittedBox` exists to prevent.
- **Every pH alarm read `pH too high: 9.10  (limit 8.5 )`** — two spaces before
  the parenthesis and one before the closing paren. pH is the only rule built
  with an empty unit, and the message template interpolated the unit with
  surrounding spaces unconditionally. The malformed string reached the user three
  ways: the in-app banner, the persisted alarm record, and the background
  notification, because all three call the same formatter.

  It survived with both language test suites green, and the reason is worth
  stating because it is general: **`alarm_parity_vectors.json` is generated from
  the Dart formatter.** A golden fixture produced by the thing under test cannot
  catch a defect in it. The fixture pins the two languages to each other, which
  is what it is for; it was never a claim that the shared text is correct.

  Fixed on both sides. `formatAlarmMessage` in Dart and `AlarmMessageFormat.kt`
  in Kotlin now route the unit through a helper that collapses the padding when
  there is nothing to pad. The fixture was regenerated **after** updating the pin
  in `tool/generate_alarm_parity_fixture.dart`, deliberately, because refusing to
  bless a wording change silently is that tool's entire purpose. Its diff is two
  lines and both are pH messages, which is the check that nothing carrying a
  unit was disturbed.

  New tests assert the shape rather than one golden string: no range message ends
  in a space, and none contains a doubled space. A future template change now
  fails on the whitespace rule instead of needing somebody to notice a doubled
  space in a notification.

- **The energy report readout overflowed at a large font scale.** Measured on the
  widget, not predicted:

  | viewport | text scale | overflow before the fix |
  |---|---|---|
  | 381 dp | 1.0 | none |
  | 320 dp | 1.0 | none |
  | 381 dp | 2.0 | **19 px on the right** |
  | 320 dp | 2.0 | **80 px on the right** |

  The readout row held two `MainAxisSize.min` values with no `Flexible` around
  them, so at 2x they had nowhere to go. On a phone that is the overflow stripe,
  and 2x is a normal accessibility setting.

  The fix is a `Wrap`, and specifically **not** `Flexible` plus
  `TextOverflow.ellipsis`. That is the regression this project already shipped on
  27 September 2026 — a unit truncated to `109....`, alongside two other label
  defects in one session that `flutter analyze`, a release build and every
  existing test all passed. A truncated energy figure is worse than a wrapped
  one, because the reader cannot tell a rounded value from a cut-off one. The
  values wrap to a second line instead, and nothing is ever abbreviated. Six
  viewport and scale combinations are now permanent tests, plus an assertion
  that the value's `TextOverflow` is not `ellipsis`.

  `PRD_PLTS_Monitoring_App.md` §7.2 item 4 lists this layout among three that
  "`flutter test` cannot catch". For this one that is wrong: the overflow was a
  plain `RenderFlex` in a `Row`, and a widget test sets the viewport width
  through `MediaQueryData.size` and the scale through `textScaler`.

### Added

- `design_tokens_test.dart` now asserts the hairline lifts each dark page less
  than the bounce does, and that light keeps its larger alpha because its page
  has a ninth of the headroom. **Verified not vacuous**: the guard fails on both
  dark themes when the alpha is put back to `0x14` and passes at `0x0A`.
- `absent_and_failed_states_test.dart`: five tests for the two states this app was
  conflating -- a failed chart request versus a quiet day, and a date chip that
  honours the font scale it was silently overriding.
- `alarm_rules_test.dart` gains four tests for the message formatter, which
  previously had no direct coverage of the range messages.

### Changed

- `FEATURE.md` §18.5 has asked for a pixel-brightness scanline across a card
  edge since before the file existed. It has now been run, and it is the reason
  this patch exists — twice over, first for the Dracula shadow alphas and then
  for the hairline. What it also did was invalidate the arithmetic guard in
  `design_tokens_test.dart` that had been standing in for it, which is the
  argument for doing the measurement.
- Test count corrected from 452 to 479, and the file count from 32 to 33, in
  the five places that claimed it. Counted per file rather than taken on trust.

### Still unverified

- **The `LoginScreen` route after removing the biometric gate.** The device had
  a stored session, so the straight-to-dashboard path was confirmed on screen
  with a genuine cold start — and so was the absence of the prompt, checked
  against the `FLAG_SECURE` failure mode described in `AGENT_PLAYBOOK.md` §7.10
  that would otherwise have produced a black screenshot. The no-session branch
  is a one-line ternary that `flutter analyze` and the suite agree with, but it
  has not been looked at on a screen. Signing out to see it would have meant
  ending a real session, so it was left alone.
- A scanline across a card's **top** edge. The light half of Dracula's pair has
  never been sampled, and that is the one open question the correction raises.
- No frame-time telemetry has ever been taken.

## [1.7.0] - 2026-10-01

### Fixed

- **The time axis printed the same label up to five times.** The rule was
  `spansMultipleDays ? DD/MM : HH:MM` — a boolean on the range. On any window
  longer than a day, every tick inside a day rendered as that day, so the PV
  chart read `29/09 30/09 30/09 30/09 30/09 01/10` and three of the five said
  nothing. The label now carries whatever the tick's position makes necessary:
  the time alone in a single-day window, the date alone when the interval is a
  day or more, and on a multi-day window with sub-daily ticks the date at each
  day turn and the time in between.
- **A day-turn label was printed on top of its neighbours.** The first version of
  that fix printed `30/09 01:00`, which is unambiguous and also unrenderable —
  eleven characters at a six-hour spacing is wider than the gap, and the axis
  read `19:0000/09 01:00 07:00 13:00 19:0001/10 01:00` on the device. A day turn
  now prints the date alone, the same width as the time it replaces. The test
  asserts distinctness *and* width, because "no two labels are equal" is
  necessary and not sufficient: the device found what the unit test could not
  predict.
- **`isDayBoundaryTick` compared epoch days, not local ones.** `value / 86400000`
  counts from midnight UTC, seven hours behind WIB, so a tick at local 00:00 was
  not recognised as a day turn at all. Caught by the sweep test on its first run.
- **`AppTile` was below WCAG AA and the test measuring it deliberately excluded
  it.** Tiles fill with `AppSurfaces.track` and text is drawn on them: measured in
  light mode, `faintColor` 3.85:1, `statusOk` 3.85, `statusWarn` 3.87, `statusBad`
  3.86, `statusAlert` 3.86, all under 4.5. The large value is fine at 11.09:1;
  what failed is the caption, which is exactly the small grey text. The
  exclusion's own comment says "no text is ever drawn on one" — true of the 6–8dp
  progress bar that also uses that token, false of a ~190dp text box. Two
  consumers, one exclusion written for the first and applied to both, which is the
  same shape as the surface-list drift below. Fixed in two parts, because a tile
  with no inner shadow at all gets its inset read purely from a darker fill:
  fill to `AppSurfaces.input` (4.99–5.02:1) *and* `AppElevation.inset`. Each half
  is guarded separately — reverting the fill alone fails two tests, dropping the
  shadow alone fails one.

### Changed

- **A one-series chart puts its statistics on one line.** Four of the seven
  chart groups have a single series, and the three-line block per series existed
  to stop two series' readings running together — a consequence of splitting the
  card's width. A one-series card has the whole width, so the same three lines
  were three lines of vertical space describing one quantity. The unit is now
  printed once at the end rather than three times, and the figures scale down
  rather than ellipsise: turbidity was truncating to `max 300…`, which is the
  exact failure the stacked layout existed to prevent.
- **The greenhouse and fish tank charts are shorter** — 260dp for a single-series
  card, 300 for the two-sensor temperature card that still needs its height. Four
  charts at a fixed 400dp put the fourth about 1,600dp down a page, on the two
  pages whose whole purpose is a glance. The height travels with the group
  declaration, so it is a property of what the page charts rather than a
  page-index conditional in the screen.
- **Cards are 20dp apart instead of 10, and it is a shadow measurement rather
  than a preference.** The ambient half of the raised pair reaches 20dp at 1σ,
  which is the part that actually draws the edge, so in a 10dp gap the upper
  card's shadow was cut off while still ~8% darker than the page and stopped at
  a hard edge. Two cards read as one block with a smudge between them. At 20dp
  the falloff completes and the page colour appears in the middle.
- **The navigation bar is centred** and its selected destination has its filled
  accent circle back. It was left-aligned when it became content-sized, which put
  four icons hard against the left edge with a third of a phone empty on the
  right. The circle came out with the `AnimatedSwitcher` and should not have —
  what was wrong was the cross-fade, not the circle, and a hue on a small icon is
  a far weaker "you are here" than a 44dp disc.
- The date-range control is out of the app bar, at the user's request: it sat
  between the wordmark and the history icon and read as clutter. The gap that
  fixed is therefore back — `DateStrip` on Overview is the only route to a custom
  range again, so the other three tabs cannot change the date.
- **The "Resolved" alarm badge was green, which the app's own colour rule
  forbids.** The stronger argument is tense rather than hue. `statusOk` is a
  status colour, and on this screen a status colour can only mean a condition
  that exists *now*; `Resolved` is a fact about a row in a list, sitting one line
  from a live red alarm. One colour doing two opposite jobs on one screen. The
  pill went too, not just the green — the tinted wash is the shape that says
  "this has a status, look at it", and a resolved record is the only row the user
  cannot act on. The word "Resolved" remains, in ordinary text.
- **The right-hand ambient shadow was clipped by the screen edge.** `BoxShadow`
  paints a mask blur of `sigma = blurRadius / 2`, so the ambient (offset 9, blur
  22) reaches 20dp at 1σ — the part that actually draws the edge — against a 16dp
  page margin, so it was cut halfway through the part that matters. Page margin
  16 → 24dp. Shrinking the shadow instead was rejected: the contact already fits,
  the ambient is the point of the three-shadow change, and shrinking it turns the
  ambient back into a second contact shadow, which is the 1990s bevel the token
  file's own comment exists to prevent. The nav bar margin moved 14 → 24dp in the
  same change, or the pill would sit 10dp proud of the content column.
- **A pH chart whose whole story was squeezed into the top fifth of the plot.**
  Zero is the honest baseline for a magnitude and wrong for a bounded
  dimensionless index. `ChartGroup.zeroAnchored` now says which is which, in the
  one place that already declares what each page charts; pH gets
  `minimum − 0.25 × range` snapped to an interval, giving an axis of 6.0–8.5 with
  gridlines that are all real pH values, and the data filling 55% of the plot
  against 14% before. Turbidity deliberately does **not** get it: the sensor
  reads 2396 NTU, which is why its limit is uncapped, and NTU has a real zero.
- **The custom date range was unreachable on three of the four tabs.** The old
  diagnosis was half right — the `DateStrip` calendar button still worked, but
  `DateStrip` only exists on Overview, so on Power, Hydroponics and Fish there was
  no way to change the date at all short of navigating back. There is now an
  app-bar control on all four tabs, whose icon switches between a single day and a
  range and whose tooltip is built from the same `describeHistoryRange` the chart
  headers use, so the two cannot disagree.
- **Removed `ConnectionTransportStatus.connecting` and `markConnecting`.** Both
  were verified unreachable before removal, per the standing rule that a dead-code
  claim gets a search: `markConnecting` had zero callers in `lib/`, `test/` and
  `android/`, the WebSocket path could only ever report two states, and the one
  caller that had been removed was removed because `connecting != connected` would
  have made the health indicator re-render on every poll. The two now-dead
  `statusMessage` branches went with it — leaving a `connecting` branch in a label
  nothing renders is an invitation to re-wire it and get the per-poll rebuild
  back.

### Known gaps found, not fixed

- ~~**`energy_report_screen.dart` has `_pickPeriod()` with zero call sites.**~~
  **The premise was false.** It is wired to the report's own `PeriodSelector`
  button at the top of the list, and the date was never locked. The agent I gave
  it to checked the call graph instead of taking my word for it, and the four
  real defects it found while looking are fixed — see above. Recording this
  because it is the second confident "dead code" report in this repo that was
  wrong, `AGENTS.md` having already recorded the first, and neither started as a
  measurement.
- ~~**The icon ring on a resolved alarm row is still a red `severityColor`
  wash.**~~ **Fixed.** A resolved row's ring is now ordinary text colour and its
  caption reads `Resolved · Critical` / `Resolved · Warning`, so the severity
  survives as a word rather than a hue. A word survives greyscale, being read
  aloud, and a screenshot; a ring does not.
- ~~**The icon ring on a resolved alarm row is still a red `severityColor`
  wash.**~~ **Fixed.** See above; the severity moved into the caption as a word.

### Fixed (earlier in this release)

- **The contrast test had been measuring surfaces the app stopped using, and
  three colours were under WCAG AA the whole time.** All six hex values in
  `test/color_helpers_test.dart`'s surface list were stale — not one matched a
  fill the app paints. They were the pre-restyle values, and the soft-UI work
  then made a third change to those fills without updating the test. The stale
  light values were *lighter* than the real ones, so the suite measured against
  a more forgiving surface than the one rendering and stayed green: on the page
  that actually paints, `faintColor` measured 4.47:1, `statusBad` 4.48 and
  `statusAlert` 4.47 against a requirement of 4.5. The margin went negative on
  exactly the commit whose purpose was to make the shadows readable. The list is
  now read from `AppSurfaces`, so it cannot drift again.

### Added

- **The app can be pressed.** `AppCard.pressed` existed since the soft-UI
  migration and nothing in the app ever passed it, so the press vocabulary was
  written and never switched on — it added a small extra shadow, which makes a
  card slightly darker rather than pressed. `Pressable` now inverts the surface
  properly, and it turned out "pressed" is *two* states: a raised block being
  pushed flattens into the page, a well being pushed goes deeper into it. One
  pair for both means either a block that sinks or a well that pops out.
- **Raised surfaces have three shadows, not two.** Two equal shadows read as a
  float — one dark halo and one light halo with no surface between them. Real
  extruded objects have a tight contact shadow where they meet what they sit on
  and only then a soft ambient one spreading away. Two distinct distances is
  what gives a card measurable thickness.
- `test/design_tokens_test.dart`, 12 cases pinning the shadow *geometry* rather
  than its values: every offset diagonal, the dark half at two distinct blur
  radii, the fill still exactly the page colour, the press pairs inverse to the
  resting ones. Each was verified by breaking the bug on purpose and confirming
  the test fails.

### Changed

- **Depth moved into the shadows, and the measurement is why that is a rule
  rather than a preference.** A `BoxShadow` paints outside the decoration's
  rect, so it cannot darken a card's interior where every caption is drawn. A
  gradient across the fill can, and was measured and rejected: at 4% the
  light-mode worst case is already 4.15:1, at 15% it is 3.34.
- The light-mode dark shadow was raised from `0x4D`/`0x33` to `0x66`/`0x40` after
  a pixel measurement showed it only reaching a 4.6% luminance drop against the
  page — thin enough that the light half was doing all the work and cards read as
  lit rather than standing off the surface. Dark mode needed no change and was
  left alone; it already measured a 44% drop.
- The nav bar's press now changes geometry rather than colour. On an opaque
  surface with an opaque fill behind it, the ripple was close to invisible and a
  pressed tab looked like a dropped frame. Its `AnimatedSwitcher` is also gone:
  it re-ran on every press, because selecting *is* a press, so tapping the tab
  you were already on cross-faded two copies of the same circle through an
  interpolated shadow pair.
- Three light-mode colours darkened by 1.1–1.3%, the smallest change that clears
  AA with margin. They are channel-scaled rather than lightness-stepped, because
  HSL moved `faintColor`'s hue from 150.00° to 146.67° — a caption colour that
  shifts hue when you darkened reads warm beside a green theme.

### Verification

`flutter analyze` clean. `flutter test` **351 passing** in 25 files, run
per-file. `./gradlew :app:testDebugUnitTest` 11 passing. Release build installed
on the Xiaomi 24090RA29G, and the depth measured from the screenshot in both
colour modes by scanline pixel brightness — the check `FEATURE.md` §18.5 has
been asking for and that had never been made:

```
dark  card 31.4 -> contact 17.6, recovering over ~35px
light page 229.5 -> contact 213
```

Never seen on a device: the `insetDeep` well state, which needs a finger held
down mid-screenshot; and whether the 150 ms down / 120 ms up asymmetry actually
feels physical rather than merely moving.

### Known gaps introduced here

- **The right-hand shadow is clipped by the screen edge.** Cards run to the right
  edge on the Power and Overview pages, so the ambient half of the depth is not
  visible on that side. **Fixed in this release** by raising the page margin to
  24dp, which is what the ambient's 20dp at 1σ needs.
- **Dracula has never been seen on a device.** Its shadow alphas were solved so
  that each shadow's absolute ΔLuminance on `#282A36` matches what the same
  shadow does on the app's dark page, and the light-to-dark ratio is asserted to
  hold within 0.7%. That is arithmetic about a relationship to a theme already
  known to look right. It is not a claim that a card reads as raised on
  `#282A36`, and nobody has looked. **Check this first if anything about the
  preset looks wrong.**
- **The light-mode accent is short of 1.4.11 for a while longer.** The metric
  icons were fixed by `metricGraphic`, but a fixed HSL lightness cannot serve all
  four hues — amber needs 0.39 and cyan needs 0.33 — so any other accent-coloured
  graphic added later needs the same treatment rather than another constant.
- `FilledButton` is still a flat accent block. Its contrast is right; a strict
  neumorphic treatment would raise or inset it. Not done because it is the one
  control whose fill is the accent, and inverting it would make the accent stop
  reading as an action.

### Also unreleased (the rest of 1.7.0)

Everything below shipped after the `v1.6.1` tag and belongs to the same release.
One `[Unreleased]` header on purpose: this file had three of them at 1.4.0, from
an unclean merge, and the rule that came out of that is keep exactly one and map
it to a version at release time. **Cut this as 1.7.0, not 1.6.2** — the surface
system, the navigation and the chart set all changed, which is not a patch.

### Added

- **The greenhouse and the fish tank have charts.** Seven in total, all drawing
  real data: Hydroponics gets Temperature (the two sensors on one axis),
  Humidity, Light and TDS; Fish gets pH, Temperature and Turbidity. Both pages
  had none at all, and the reason was structural rather than missing work —
  see Fixed below.
- `test/bound_test.dart`, the first coverage `Bound` has ever had. Thirteen cases
  pinning the caching, the token comparison, the listener swap, and the
  reused-`State` splice that PV/AC/Battery depend on. Its token contract has
  already failed twice in this repo, and both times the symptom was the AC card
  sitting under the PV header, visible only on a device.

### Fixed

- **The chart could not draw anything but voltage, current and power.** Three
  things blocked it together: `HistoryKeys` was a three-field record and
  `TelemetryChartCard` composed its lookup key from a `const suffixes` list of
  the same three names, so there was no field for pH and no slot to name it;
  `_prefixForPage` returned null for the two pages, and a null prefix means no
  request; and `historyDeviceForPrefix` sent everything that was not the battery
  to the PZEM meter, so a request for `ph` would have been issued against a
  device that does not publish it. All three now come from one declaration, so a
  page cannot request keys nothing draws. PV, AC and Battery are unchanged.
- **Buttons in dark mode were white text on light green**, about 1.5:1.
  `filledButtonTheme` had never existed, so every `FilledButton` was a raw
  Material block at the framework's own radius and `ColorScheme.fromSeed`'s
  light `onPrimary`. The fill and the label are now derived from the user's own
  seed at a lightness chosen per mode.
- **The card hairlines were tinted with the theme accent**, putting a green
  outline on every card in the app. A coloured border is a drawn edge, and a
  drawn edge is the one thing the soft-UI surface exists to replace — it was
  undoing the whole migration on its own. The hairline stays, because WCAG 1.4.11
  wants 3:1 for a component boundary and no test measures it, but it is now a
  very light neutral aligned with the light source.
- **The soft-UI surfaces did not read as soft UI.** The light page was close
  enough to white that the light half of every shadow pair had nowhere to be
  lighter *to*, so only the dark half showed and every card read as flat Material
  with a grey edge. The page is a mid-tone now and the shadow pair is retuned for
  it.
- **Scrolled content was legible through the app bar.** The scrim was 86% opaque,
  and a 17sp bold greeting stayed plainly readable behind the title.
- **Both y axes drew two labels on top of each other.** The dashboard snapped
  `maxY = max * 1.1` to a whole number of intervals; the energy report divided
  the padded maximum by four and got `0.12 / 0.23 / 0.35 / 0.46` — each correct
  to two decimals, none of them a number anyone would write. Both now use
  `niceStep`, and the top label hangs below its own line instead of being
  centred on a line the plot has no room above.
- **Alarm severity colours failed WCAG AA**: `0xFFF57C00` measured 2.44:1 and
  `0xFFD32F2F` 4.50:1 as 11 to 13dp text, a second unpinned palette one file from
  the measured one. The background check's "ok" was the EnerGrow seed hardcoded,
  so a user who picked Solar amber got green beside an amber theme, at 2.70:1.
  The CCTV status pill drew its 9dp label at 1.66:1. The login error was 3.67:1.
  Chart axis labels were 4.30:1. All now use the measured palette.
- **The alert banner read as salmon.** Darkening `_alertAccent` to stop it being
  the third amber in its file was a judgement made without measuring the result,
  and the result was pink. It is orange again.
- **Cards, list tiles and nav items lost their ink.** An opaque card fill paints
  over the ink layer of the nearest Material above it, so every `ListTile`,
  `SwitchListTile` and `InkWell` inside a card had its splash painted and then
  covered — pressing a tab gave no feedback at all. A transparent `Material` now
  sits between each card's decorated box and its content.
- **The statistics columns ran together** on a two-series chart, so `min 22.73 C`
  ran straight into the `Panel` column and two readings looked like one line of
  text.

### Changed

- **The whole surface system is opaque soft-UI**, replacing the "liquid glass"
  that had no token layer at all: one card primitive beside roughly thirty-five
  hand-written `BoxDecoration`s, six card treatments, three shadow vocabularies
  and twelve radius values. `design_tokens.dart` now holds every fill, radius,
  shadow pair and duration. The three full-screen ambient orb gradients are gone;
  they existed only so the translucent cards had something to reveal, and they
  were the most expensive paint in the app — while not being gated by the
  Performance setting whose own subtitle promised "flat cards, smoother
  scrolling".
- **Telemetry rebuilds are narrowed per device.** A WebSocket frame from the
  battery used to rebuild the greenhouse card, which could not have drawn
  anything different, and `PageView` keeps the Power page alive while the user
  reads Overview, so that rebuild happened off-screen too. Five cards that each
  read exactly one device now have their own counter. The four consumers that
  genuinely read across devices stay on the wide one.
- `markConnecting` is no longer called on the poll path. It fired a real
  notification every poll and the status strip has no branch that renders the
  state it described.
- The CCTV WebView is isolated behind a `RepaintBoundary`. It is a
  virtual-display texture invalidating 30 to 60 times a second, and a live stream
  was re-rasterising the whole page display list around it.
- **The navigation bar lost its labels and is now as wide as its contents.** The
  labels never fit — `Hydroponics` measures 62dp in a 60dp slot — and the width
  carried no information, because each destination is already named by the header
  of the page it opens. The 48dp tap target and the semantic labels are
  unchanged, so only the visible text went.
- The camera moves above the readings on both the greenhouse and the fish page.
  It was last because those pages had no chart, so a camera at the bottom meant
  scrolling past every number to reach the one control that is not a number.
- The energy report's list is a `ListView.builder`, so the bar chart is not
  constructed on the loading, error and empty paths, and the settings
  `ListenableBuilder` no longer wraps the whole Scaffold, which was rebuilding the
  app bar and the save button on every dropdown.
- The energy report's bar chart no longer animates on every rebuild, matching
  the dashboard's line chart which already opted out.

### Removed

- **The Performance setting**, and `performanceMode` with it. It promised frosted
  cards and smoother scrolling; the `BackdropFilter` it gated had exactly one
  caller in the entire app, and everything else it named is gone. A switch that
  says it does nothing is still a switch. The `performance_mode` key is left in
  SharedPreferences and read by nobody.
- **The chart header's calendar button**, and with it the only route to a custom
  date range. The date strip can only pick a single day. The range is still named
  in the header, so nothing becomes ambiguous, and if it comes back it belongs in
  the app bar. Six of these buttons were about to exist on the greenhouse page
  alone.
- The environment grid's breach border. It was the third channel for a state the
  range caption and the out-of-range tag already carry, and signalling one
  condition three ways reads as a checklist rather than a reading.
- The energy report's title said "Energi Analytics", a half-translation left in
  from 1.3.1, on a screen whose body reads "Summary" and "hours with data".

### Known gaps introduced here

- **The pH chart's y axis starts at zero.** Its data lives between 6.37 and 7.75
  in a 0 to 10 range, so the drop from 7.75 to 6.37 is squeezed into the top
  fifth of the plot. Zero is the honest baseline for lux and watts, where it
  means something, and not for a dimensionless index. Undecided, and not changed
  globally on a hunch.

### Verification

`flutter analyze` clean. `flutter test` **338 passing** in 24 files, run per-file
with up to three attempts because this 7 GB machine OOMs on a single run and
reports it as `did not complete` with no stack trace — confirmed against a
stashed baseline, where the same suite fails the same way with no code change.
`./gradlew :app:testDebugUnitTest` 11 passing. Release build installed on the
Xiaomi 24090RA29G and both colour modes checked by screenshot across all four
tabs, the energy report and Settings. 120 fps is the device owner's report; no
`dumpsys gfxinfo` measurement has been taken. Never seen on a device: the CCTV
stream end to end, and the energy report with a full month of data.

## [1.6.1] - 2026-09-29

### Fixed

- **The shipped turbidity default was arming an alarm that could never clear.**
  The sensor on the test device reads 2396 NTU and later 3000 NTU for the same
  tank, against a default limit of 100 NTU chosen from real aquaculture
  guidance — so the sensor is not on the scale that guidance assumes, and
  nobody has established what it measures. The moment a user saved the Fish tank
  alerts section, that default became a live rule and produced "Turbidity too
  high: 3000.0 NTU (limit 100.0 NTU)" every minute, indefinitely. There is no
  replacement number: any value is a guess about an uncalibrated sensor, and a
  guess that fails high is worse than no limit, because it manufactures an
  alarm that can never resolve. The default is now null, the field starts empty,
  and "Blank limits are not monitored" is the whole story. The upper cap, removed
  in the previous commit, is what lets a user now set a limit above 3000 once the
  scale is known.

- **The energy report no longer contradicts the dashboard card about the same
  two numbers.** `comparisonLabel` in the report had no minimum-meaningful
  threshold while `EnergySummaryCard` had one at 0.1 kWh, so a period that
  produced 0.01 kWh followed by one that produced none read "-100% from the
  previous period" in the report and "Nothing to compare yet" on the dashboard,
  in the same session. The threshold was also duplicated as two literals in two
  files, and the copy that had never been fixed was the report's, so the two
  were one forgotten edit away from disagreeing again. It is now a single
  `kMeaningfulEnergyKwh` in `lib/utils/energy_comparison.dart`, imported by both.
  The wording is still deliberately different per surface: the card's two tiles
  sit side by side and wrap independently, the report's label has a full line.

  Correcting an earlier claim in this changelog: the misleading "-100%" does
  **not** reach the exported CSV. `totals_card.dart` calls `comparisonLabel` from
  a `Semantics(label:)` and a `Text`, both on screen. The CSV is built by
  `csv_builder.dart`, which does not call it.

- **October and December render in English.** `_monthNames` in
  `energy_report/utils/format_helpers.dart` listed 'Oktober' and 'Desember'
  among ten English names, in an app whose locale is en_US, so a monthly report
  for those months said "Oktober 2026". Unlike the previous defect this one did
  reach exported files: `csv_builder.dart` writes `formatMonthLabel` into the
  `Period` row. `formatMonthLabel` had no test at all, so there was nothing to
  stop the Indonesian spellings coming back; there are now twelve assertions.

- **Swiping a tab no longer walks past the end of the dashboard.** Eight swipes
  left on the Overview tab landed on page nine of a four-tab pager. The gate
  class that stops a chart drag from also changing page,
  `ChartGestureLockPhysics`, decided whether a gesture was *accepted* but never
  what happened when it was *released*: it did not delegate
  `createBallisticSimulation`, so the fling fell through to `ScrollPhysics`'s
  plain friction simulation instead of `PageScrollPhysics`'s spring. A pager
  without that spring is not a pager — it coasts to wherever friction ends and
  keeps taking velocity past the end of the content. Delegating the fling
  restores the snap. It also stopped overriding `allowUserScrolling`, which is
  read when `Scrollable` installs a drag recognizer rather than when a gesture
  starts, so a chart drag could switch dragging off and lifting the finger
  could not switch it back on; paging then stayed dead until an unrelated
  rebuild arrived, up to ten seconds on a dashboard that polls every ten.

  Pinned by `test/chart_gesture_lock_test.dart`, which had no equivalent: the
  class landed in 1.6.0 with no coverage at all. The eight-swipe case is the
  regression guard, because a single swipe passes even with the bug.

- **A limit shown in Settings is no longer indistinguishable from a limit that is
  actually being enforced.** The Fish tank alerts section showed
  `Max (NTU) 100` with its switch on while turbidity read 2396 NTU and the grid
  stayed silent. Nothing was broken and nothing threw: `SettingsController`
  keeps the shipped default in the field when the preference key is missing, and
  that prefill looked exactly like a stored value. The native side had been
  configured with 19 rules, and 19 is the count *without* a turbidity rule — 20
  with one — so the key had never been written. It had no chance to be: the key
  was introduced in 1.6.0, after the last time these settings were saved, so
  every other limit persisted and only the new one did not. A user reading that
  screen believed the tank was guarded at 100 NTU when no rule anywhere
  enforced it.

  Fixed in the mechanism rather than the parameter, because every future release
  that adds a limit hits the same path: `EnvRangeSetting` now tracks whether
  each side holds an unsaved default, `load()` clears that only when the key is
  actually found, and `save()` clears it once the write succeeds. A prefilled
  number renders in the faint italic with a `Not saved yet` caption, and each
  section says once how many limits are showing defaults and are not monitored
  yet. Pinned by `test/settings_prefill_test.dart`.

  The grid was right to stay silent — with no limit there is nothing to breach —
  and it is now backed by `test/fish_turbidity_grid_test.dart`, because the fish
  specs shared a widget with the greenhouse ones without ever being exercised
  against it.

### Added

- **Turbidity can now be set to any value the sensor reports.** It was capped at
  1000 NTU while the sensor reads 2396 and then 3000, so the field rejected
  anything higher with "Turbidity cannot be higher than 1000" and the alert could
  not be configured against reality at all. The cap is removed the way TDS
  already has none, for the reason the TDS comment in `alarm_rules.dart` gives:
  a cap low enough to look safe gets crossed by every real reading, which makes
  the alert unreachable rather than safe. A cap of 10000 would be the same bug at
  a different scale, so there is no new magic number. The lower bound stays at 0
  because a negative NTU reading cannot be real.

  The bound went unnoticed because the sensor bounds tests in
  `settings_validation_test.dart` only ever reached into `envRanges`. A new
  "fish sensor bounds" group pins the three fish ranges in display order, the pH
  and water temperature caps that are left in place because those are physically
  real limits, turbidity having no upper cap, values up to 100000 validating, and
  a negative value still being rejected.

- **`EnergySummaryCard` has a widget test for the first time.** A 339-line widget
  on the Overview tab that no test had ever looked at, in a repo where three
  label regressions once passed `flutter analyze`, a release build and the entire
  suite. Eighteen tests now pin the title, the period selector, the method note,
  both tiles, the forecast block, the empty state and the 0.1 kWh comparison
  threshold, with every asserted string carrying the widget line it was copied
  from so a rename fails here rather than reaching a device.

- **`ChartBounds.maxY` is covered for a non-positive peak, and the Settings
  category list is complete.** The y range stays strictly increasing for peaks of
  0, -1 and -1e6, which is what stops fl_chart drawing an inverted axis. The
  settings test was asserting eight of ten category titles, missing both "Fish
  tank alerts" and "Background checks".

### Documentation

- `AGENTS.md` and `AGENT_PLAYBOOK.md` now describe both build machines. The
  project moved from CachyOS/Arch to Windows, and the difference that actually
  breaks a build is `android/local.properties` still holding the other
  machine's paths: Flutter rewrites that file for itself, but a bare
  `gradlew.bat` reads it directly, which is how a stale Linux path surfaces as
  `flutter.sdk not set in local.properties` on a machine that plainly has
  Flutter installed. The `dl.google.com` throttle is now scoped to the Linux
  machine and explicitly marked as never re-measured on Windows — a normal
  Windows build downloads nothing because the Gradle distribution and the NDK
  are already in the Gradle user home, so its speed says nothing about
  throughput.
- `FEATURE.md` corrected three stale figures: the alarm parity fixture has 23
  scenarios, not 17, and the device now pushes 19 rules across 4 devices rather
  than 13. The Fish and Hydroponics pages moved out of §18.5, having been seen
  on the device for the first time on 29 September 2026, and the prefill
  mechanism is recorded as §18.7.
- `PRD_PLTS_Monitoring_App.md` §7.1 marked two items done that 1.6.0 finished
  and dropped `weather_card.dart`, which no longer exists.

## [1.6.0] - 2026-09-28

### Added

- **Hydroponics and Fish pages, driven by a fourth ThingsBoard device.** The
  standalone CCTV tab is gone; its greenhouse sensors and its camera now share a
  **Hydroponics** tab, and a new **Fish** tab shows water quality from device
  `1c433980-ba25-11f1-b893-9dd5b4b6bde1` next to a second camera
  (`?src=cam2`, same allowlisted go2rtc host, separate setting and separate
  secure-storage key). The Fish page reads pH, temperature, turbidity and water
  level.

  The fish device is a first-class `AlarmDevice`, so `buildAlarmRules` arms
  `stale_fish` and `offline_fish` for it exactly as it does for the other three.
  That gives background notifications for the new device — "no fresh data" at ten
  minutes, "stopped reporting" at sixty — with no thresholds configured, which is
  what a monitor-only device cannot do. Three scenarios were added to
  `alarm_parity_vectors.json` and it was regenerated, so the Dart and Kotlin
  evaluators are still pinned to identical wording for the new device's messages.

  Threshold rules arrived in the same release. Settings gains a **Fish tank
  alerts** section (pH 6–8.5, water temperature 20–30 °C, turbidity ≤ 100
  NTU, each limit individually blank-able, and a blank limit is not
  monitored), and `buildAlarmRules` arms matching fish rules in both the
  Dart and Kotlin evaluators. The parity fixture grew to 23 scenarios
  pinning the shared wording, and the Fish grid on the dashboard now grades
  against the same `AlarmThresholds` the alarms use — so the page and the
  notification can never disagree about what the limit is.

- **The test suite grew from 223 to 273 — and two files that had never run now
  do.** `widget_test_environment_grid.dart` and `widget_test_live_power_card.dart`
  did not match the `*_test.dart` pattern `flutter test` collects, so every gate
  reported green without executing either. Renamed to `metric_grid_test.dart`
  and `live_power_card_test.dart`, they immediately failed five assertions: three
  looked for value and unit joined as one string ("25.0 °C") when the card
  renders them as two separate `Text` widgets, and two asserted the *previous*
  BMS's sign convention — negative power labelled "Charging" — which the
  replaced pack had already invalidated. All five now assert what the screen
  actually shows. New files pin what this release could have silently broken:
  `settings_save_regression_test` (the full write set and blank-means-null),
  `alarm_path_thresholds_to_rules_test` (thresholds → rules → native JSON for
  both alert groups), `battery_sign_convention_test` and
  `energy_report_service_test`; `metric_grid_test` also carries the
  `showGridColors` gate added in this release.

### Fixed

- **Touching a chart rebuilt the entire page view, twice per gesture.** The
  `PageView`'s `physics` was being driven by a `ValueListenableBuilder` wrapped
  around the whole `PageView`, so a chart's `onPointerDown` / `onPointerUp` — and
  the chart covers most of the PV, AC and Battery pages — rebuilt every cached
  page twice for nearly every scroll. The lock now lives in a
  `ChartGestureLockPhysics` that reads the flag when a drag *begins*, so nothing
  rebuilds. The base physics is delegated to rather than replaced, so page snapping
  survives; swapping in `NeverScrollableScrollPhysics` would have silently dropped
  it.

- **The offline cache was a read-modify-write race.** Each device's fetch wrote
  `cached_telemetry` on its own, so four devices fetching inside one `Future.wait`
  read the same snapshot and the last writer discarded the other three buckets.
  Measured at 32-77 ms per write on the test device, all of it on the poll's
  critical path. `fetchLatestTelemetry` no longer caches; `_fetchAll` merges the
  tick's readings and writes once, unawaited.

- **The WebSocket announced every frame as a change.** `_handleRealtimeTelemetry`
  passed `changed: true` unconditionally, so the revision counter rose two or three
  times a second — about thirty times more often than the ten-second poll the
  counter was designed around — and every bound widget in the tree rebuilt with
  it. It now compares the merged values the same way the poll path does.

- **`ConnectionHealthService` notified on every telemetry frame.** It had no value
  equality, and `lastSuccessfulUpdate` plus `latency` both change on every frame
  anyway. Equality now covers only the three fields the UI actually draws: status,
  transport and reconnect count.

- **`_alarmRules` was a getter**, so `buildAlarmRules` allocated roughly fifteen
  `AlarmRule` objects plus nine helper instances on every telemetry frame, before
  `_evaluateEnergyAlerts` could reject the update as unchanged. It is now rebuilt
  only when the thresholds change.

- **The bound-widget token omitted `_thresholds`**, so saving a new limit in
  Settings left the environment grid captioning its old range and the status strip
  judging against the old low-SOC threshold until the next telemetry change
  happened to rescue it.

- **A metric row announced itself to a screen reader as `Instance of 'MetricDef':
  45 %`.** `Semantics.label` interpolated the object, which has no `toString()`. It
  compiles and passes every lint.

- **`turbidity_keruh` is deliberately not requested.** The fish device publishes
  it as a boolean. `TelemetryPoint.fromJson` parses with
  `double.tryParse(value.toString()) ?? 0.0`, so requesting it would not throw —
  it would store `0.0`, and the card would show a confident `0` meaning the
  opposite of the truth, indistinguishable from a real zero reading. The numeric
  `turbidity_ntu` carries the same fact with a scale. `turbidity_voltage` (the
  sensor's own 3.3 V rail) is also not requested.

- **Nine source files had CRLF in the working tree where git stores LF**, which
  would have shown as a whole-file rewrite on commit. Normalised.

- **The battery sign convention is now the opposite of what it was, and it is
  pinned by a test.** The hero card labelled a discharging pack "Charging" at
  −22 W. The cause was not a rendering bug: the previous pack was measured on
  27 September 2026 reporting `−12.92 W` while its state of charge was *rising*,
  and the current pack reports `−28 W` while the state of charge is *falling*.
  `AGENTS.md` had recorded the risk in advance — the convention was measured on
  one device, and replacing the BMS would invert every battery display without a
  single red indicator. The mapping now lives in `lib/utils/battery_sign.dart`
  with the measurement in the reason string, so the next swap fails a test that
  says what to re-measure instead of quietly inverting the app.

- **The status strip was reading the battery sign a second time, differently.**
  It derived "Charging" from `current < 0` while the hero card read `power`, so
  the two contradicted each other on the same screen from the same pack, and the
  bare comparison had no deadband to sit in when the BMS idled at 0.00 A. It also
  picked a full-charging-battery icon from the SOC rather than from the direction,
  so the icon drew a charging pack while it was discharging. Both now go through
  `batteryChargeState` on the same key.

- **Saving Settings failed silently whenever any limit field was blank.**
  `save()` threw on `range.minKey!` for turbidity — its minimum is deliberately
  unbounded, so `minKey` is null — the exception escaped `_save()` before the
  SnackBar could be shown, and the screen neither popped nor reported anything:
  from the user's side the Save button simply did nothing. The same crash also
  swallowed the `true` that drives the dashboard to re-ship alarm rules, so an
  edited threshold did not reach the background evaluator until the next app
  restart. Both save and load loops are null-guarded, `_save()` catches and
  surfaces unexpected errors instead of dying quietly, and
  `settings_save_regression_test.dart` reproduces the symptom — reverting the
  guard fails it four times over. Verified on the device: Save pops to the
  dashboard and `run-as` shows the new fish and environment limits in
  `shared_prefs`.

- **Switching between the PV, AC and Battery sub-tabs showed the outgoing
  page's numbers.** All three sit at the same tree position, so `Bound` reused
  the cached child across the switch and kept rendering the old view until the
  next ten-second revision bump happened to change the token. `_visualToken`
  now includes `_powerSubNotifier.value`. Verified on the device: one second
  after an AC → PV switch the screen showed DC metrics only.

- **The CSV export button never showed "Preparing CSV…".** `sharingNotifier`
  was written but never listened to, so the button could not rebuild; it now
  listens, which also makes the double-tap guard visible instead of merely
  effective.

- **Tapping an alarm notification opened nothing.** The native side already
  stashed `EXTRA_ALARM_ID` and `AlarmBridge.launchAlarmId()` could read it, but
  no Dart code ever consumed it; `DashboardScreen` now drains it on init and
  routes to the alarm history. Not yet reproduced on the device — a genuine
  notification is needed to exercise it.

- **The environment alerts toggle now removes the grid's warning colours too.**
  It previously disabled only the background rules, so Settings could say
  alerts were off while the Hydroponics grid kept painting out-of-range
  readings red. `MetricGrid` now takes `showGridColors` from the same
  threshold the alarms read, and the "out of range" tag follows it; the
  "Stale data" tag deliberately does not, because a dead sensor is a fact
  about the data, not a configured limit.

- **The Fish dashboard page never showed the limits an alarm could be firing
  on.** It passed no thresholds to `MetricGrid`, so a pH of 14 rendered as an
  ordinary reading while the evaluator judged it against a limit the page never
  printed. It now grades and captions against the same `AlarmThresholds` as the
  alarms; a blank limit still shows no range.

- **A fish device that never saved its limits still armed the defaults.**
  `alarm_settings.dart` fell back to `defaultFish*` whenever a key was absent,
  turning "never configured" into "configured at the defaults" — a device the
  user had never set up would start alarming at numbers nobody chose. Absent
  now means null, matching the environment group, so the first Save is what
  arms the defaults.

### Changed

- **The Power tab is selected by a `ValueNotifier`, not screen `setState`.** A
  screen-level `setState` for the PV/AC/Battery selector cost 14-20 ms to the next
  frame against an 8.33 ms budget at 120 Hz, because it repainted the ambient
  background, the blurred app bar and every cached page to change one selector.
  Median is now 6 ms, measured on the device.

- **Entering the Power tab prefetches all three sub-views.** Switching used to
  leave the incoming card showing the previous fetch's numbers for as long as the
  request took, which read as the card being stuck. Three requests once on entry
  means every later switch lands on data that is already there; each switch still
  refreshes in the background.

- **The chart header says "Updating" while a request is in flight**, and nothing at
  all otherwise. The silence was the problem: a deliberate stale-while-revalidate
  is correct, but with no indication at all it is indistinguishable from a frozen
  card.

- **The OpenWeatherMap integration is gone, along with the location permission
  it needed.** The Overview card is removed, along with `WeatherService`, its
  fifteen tests, the `geolocator` dependency, the Settings section that asked for
  an API key nothing consumed, and `ACCESS_FINE_LOCATION` /
  `ACCESS_COARSE_LOCATION` from the manifest. Light (`lux`) already lives on the
  Hydroponics page and PV output already lives in Energy analytics, so the card
  showed numbers the user could see twice. What is lost is outdoor temperature,
  wind, cloud and any forward-looking forecast; `power_dc` and `lux` are
  measurements, not predictions. The one credential this app stored outside secure
  storage was that API key.

- **Bottom navigation is four tabs, not six.** PV, AC and Battery became one
  "Power" tab with a segmented selector, because they are three views of a single
  electrical system. Material 2 documents 80 dp as the minimum width of a
  bottom-navigation destination in portrait and this phone is 380 dp, so six tabs
  needed 480 dp; "Hydroponics" measured 62 dp in a 60 dp slot and was visibly
  truncated. Material 3 names the limit and the symptom together: "the elements
  may collide and there likely won't be enough space for translated text." Both
  versions forbid the alternatives — "Don't shrink text to fit on a single line",
  "Don't truncate text", "Don't reduce the type size to fit more characters into a
  destination label" — and both independently forbid the per-tab colour that this
  project had already reverted. Four tabs need 320 dp and leave a slot spare.

- **`EnvironmentGrid` is now `MetricGrid`, and takes its readings as a
  parameter.** It was one widget hardcoded to five greenhouse sensors, laid out by
  hand as a 3 + 2 shape with `_envSpecs[0]` through `_envSpecs[4]` written out
  individually, so a sixth sensor meant rewriting the layout and a forgotten index
  renders nothing at all. The fish page uses it with two columns, and `decimals`
  is per spec rather than a fixed 1 — which mattered immediately: pH is
  logarithmic and wants two places, and an NTU turbidity sensor printing
  "2395.5" implies precision it does not have.

- **The two hardcoded switches mapping a telemetry key to its configured limit now
  live on `AlarmThresholds` as `minFor` / `maxFor`.** They were duplicated inside
  the grid, once to colour a card and once to caption it, and both ended in
  `_ => (null, null)` — safe for the three keys that had a case, and silent for
  anything added later.

- **A `RenderFlex` overflowed by 12 pixels in Settings → Background checks.** Two
  `OutlinedButton.icon`s sat in a `Row` with neither child flexible, and the
  second one only appears when the app is *not* exempt from battery optimisation,
  so it overflowed for exactly the user who had something to fix. Now a `Wrap`.

- **"Battery optimisation" ran into its own value.** The label column was a fixed
  150 px and that label is a couple of pixels wider, so the row read
  "Battery optimisationActive". A fixed gap now sits between them, which also
  stops the next label to exceed the column from colliding the same way.

- **`ThingsBoardApi.deviceKeysById` is the canonical device list.** The REST
  shortcuts, the WebSocket subscriptions, the offline cache split and the key-set
  tests were four hand-written lists that had to be extended in step. A device
  added to the constants but missed in `splitCachedTelemetry` polled live and
  correctly, then came up empty from the offline fallback — no error, no log. The
  tests now derive from the map, and a new test asserts every key of every device
  reaches its own cache bucket, so a fifth device cannot silently drop out of
  coverage either.

- **The environment grid moved from Overview to the Hydroponics tab.** The
  readings and their limits are unchanged, so no alarm behaviour changed; Overview
  is now only what the power system is doing.

- **Settings → CCTV source has two URL fields**, labelled "Hydroponics camera URL"
  and "Fish camera URL". Both go through the same host allowlist and both are
  validated on save.

- **The dead-code inventory in `FEATURE.md` §18.2 was worked down.** Roughly
  two dozen symbols with no callers were deleted rather than left to rot —
  `SeriesStats.average`, `batteryCapacityKwh`, `ExportButton.onShare`,
  `AlarmBridge.isScheduled`, `AlarmTokenStore.updateAccessToken`,
  `AlarmBridgeStatus.configSavedAt`, the never-written connection-status timer
  fields, `solarProductionFactor`, and the unreachable `ConnectionHealth`
  status `error` among them. Two entries on that list turned out to be
  call-site problems rather than dead code: `clearCctvUrl` now runs on logout
  and `launchAlarmId` now has its consumer.

### Known issues still open

- **The dashboard still feels sluggish on the test device.** See `progress.md` for
  every measurement taken, every tool that turned out not to work, and the three
  candidates that remain. This is unresolved and is the first thing to pick up.

- **The Offline fallback only ever ran on a cold start.** Not touched this
  session, but the race above is the same failure family: the page polls live,
  shows correct numbers, and the offline path comes up empty with nothing logged.

## [1.5.0] - 2026-09-27

### Changed

- **The app is now entirely in English.** The interface had been a mix: alarm
  messages, the energy card, the status strip and the environment grid were
  Indonesian while the settings screens, the detail pages and the metric labels
  were English, so the same screen could read two languages. Terms are chosen once
  and used throughout — "limit" for a configured bound, "stale" for telemetry that
  has stopped being fresh, "out of range" for a breached threshold, "AC grid" for
  the mains supply, "Live" for the realtime connection. The alarm message strings
  changed too, in both `formatAlarmMessage` and `AlarmMessageFormat.kt`, and
  `alarm_parity_vectors.json` was regenerated so the Dart and Kotlin evaluators are
  still pinned to identical output.

### Fixed

- **The alarm banner now collapses instead of vanishing.** It was rendered by a
  plain conditional, so an alarm clearing made the entire Overview jump up by the
  banner's full card height in a single frame with no transition, which reads as a
  glitch rather than as a condition ending. Every banner now goes through a
  switcher that fades it, lifts it slightly and shrinks its height continuously.
  The collapse needs a `SizeTransition` and not just a fade: the switcher stacks
  the outgoing banner under the incoming one, and a stack takes the largest of its
  children, so a banner that only faded would hold its full height for the whole
  exit and then snap to zero on the last frame. The exit is longer than the
  entrance — an alarm appearing deserves to be noticed quickly, one clearing is
  information but does not need to interrupt. A change to *which* alarms are active
  cross-fades the text as well as resizing.
- **The chart's min and max are no longer truncated.** "↓ 6.98 ↑ 21.43 V" on one
  line overflowed a third of the card width and ellipsised to "109....", losing the
  one figure a reader cannot afford to lose. Each figure gets its own line.
- **The chart Y axis carries real values again.** Normalising each series to 0–100 %
  of its own range was tried so all three would fill the plot height. It was
  reverted at the user's request: a reader who sees "0%, 50%, 100%" has to look up
  three separate scales in the legend to learn anything, and on the PV and battery
  pages the three quantities are within an order of magnitude anyway, so the raw
  axis was already readable. Only the AC page has power two orders above current,
  and a flat trace there is honest rather than broken.
- **The chart no longer renders an empty plot.** Passing an empty `dashArray` to
  fl_chart does not mean "solid", it means "draw nothing": the pattern is walked by
  `pattern[index % pattern.length]`, so a zero-length list produces no output at
  all. The card came up with correct axes, a correct legend and correct statistics
  and no lines, which is the worst shape of bug to spot on a device. Leaving the
  field unset is what draws a solid line.
- **Overlapping chart traces are both visible.** Current and power are
  proportional, so their lines usually coincide exactly and the one drawn last hid
  the other completely. The lines are slightly transparent, so a trace underneath
  shows through.
- **The "Live" indicator takes the accent rather than green**, for the same reason
  as the rest: a green badge for a condition that is normally fine is a second
  colour system next to the theme.
- **The device charts plot voltage, current and power together again.** Splitting them behind a metric picker was wrong: seeing all three at once is the reason the chart exists. They are drawn raw against one shared, dynamic Y axis. The series colours are fixed red, green and blue and the lines are solid; deriving three series from the theme accent as lightness steps, and then telling them apart with dash patterns, were both tried and both rejected, because three obvious colours need no legend decoding and a dashed trace on a phone reads as broken.
- **The card outline now follows the theme accent.** It was a neutral white or black hairline, so a card in an amber theme held amber numbers inside a cold grey frame and the palette read as two systems. It is taken from `colorScheme.primary` rather than a new parameter, because the theme already carries the accent and threading a `seedColor` through every call site would only let the two disagree later.
- **Green no longer appears on a healthy dashboard.** The status strip coloured the value text, the battery icon and the tick green even when nothing was wrong, and every environment card in range got a green border and a green range caption. In an amber or cyan theme that put a second colour system all over the page. Now only a breach is coloured; a healthy reading keeps the card's accent-tinted outline and ordinary text, which is the same rule already applied to the environment grid's verdict.
- **`SegmentedButton` no longer fills the selected segment with a muddy tone.** Material uses the colour scheme's `secondaryContainer`, which `ColorScheme.fromSeed` desaturates until it reads as neutral — invisible with the default green, an olive block on a near-black card with "Solar amber". All three segmented buttons in the app now take their selected fill and text from the accent through a `SegmentedButtonThemeData`, since the seed is available where the `ThemeData` is built.
- **The energy comparison no longer prints "−100% from the previous period"** when the previous period held 0.01 kWh. That figure is arithmetically right and reads as a catastrophe; below 0.1 kWh both periods are rounding noise against a value displayed to two decimals, so the card says what actually happened instead.
- **The alarm banner appears on the Overview page only.** A threshold breach is a fact about the greenhouse, not about the tab being looked at, and repeating it above the PV, AC, Battery and CCTV pages pushed four already-read lines above the content the user opened a tab to see. Connection state still shows on every page, because a page of numbers that cannot be trusted needs to say so wherever it appears, and the alarm count is in the status strip on every page.
- **The date range picker is now localised in English.** Its chrome comes from a `Locale` argument rather than from the strings passed to it, so it was the last Indonesian surface in the app: day headers and month names inside an otherwise English dialog.
- **The exported CSV is named `energy_report_*.csv`** rather than `laporan_energi_*.csv`. The filename reaches the user through the share sheet, so it is part of the interface.
- The energy comparison caption is short enough not to wrap. The two tiles sit side by side and wrap independently, so a caption that wraps on one of them leaves the pair with mismatched heights.
- **The hero card now shows where the power is going** instead of three shortcut capsules. The capsules showed PV output, AC load and battery charge, and all three were already on that same card: the PV figure is the number directly above in the hero, the battery charge is the gauge beside it, and as navigation they duplicated the bottom bar, which already has PV, AC and Battery tabs. Their progress bars were the weakest part of all — PV was divided by a hard-coded 300 W and the load by 2000 W, so a bar could read full while the number beside it was wrong. The strip reads solar, house and battery, draws the house's share of the array's output as a proportion, and states in one line whether the array is covering the load.
- **The battery figure comes from the BMS's own `power` key**, not multiplied out from voltage and current. The device reports all three. Deriving it gave two separate wrong answers: the product collapses to zero whenever current reads 0.00 A, which this BMS does report while idle, and the two figures drift apart whenever the pack is not at its nominal voltage.
- **The battery state is a three-way split, not a boolean.** The pack genuinely moves between charging, standby and discharging, and at zero current the sign of the reading is pure noise, so the strip would flip between "Charging" and "Discharging" several times a minute while asserting a direction the data does not establish. Below 1 W it says "Standby" and claims nothing.
- **The hero card prints the battery figure with the sign the device reports.** Negating it so the card read "Charging 12 W" was tried and reverted: the Battery page, one tab away, says "Power -12.92 W", and making the hero prettier at the cost of two screens disagreeing about the same measurement makes the app less trustworthy. The label carries the direction and the number matches the other page exactly.
- **"PV Output" no longer appears three times on one card.** It was the card header, the caption directly under the big number, and the first capsule's label. The header now names the card ("Live power") and the duplicate caption is gone; the capsule label is the one that had to stay, because three identical tiles in a row are indistinguishable without it.
- **The split bar under the power flow actually draws.** `SizedBox(height: 5)` alone leaves `maxWidth` at infinity, so the `Row` beneath it was unbounded and its `Expanded` segments resolved to nothing — the bar rendered as empty space with no exception to notice.



- **Fixed a background check that could be killed mid-write.** The worst case ran about 48 seconds against the ~10 seconds a manifest `BroadcastReceiver` is allowed, and the slow path was the *expected* one whenever the access token had expired. Being killed between writing credentials and saving the active set made the next tick treat the same alarms as new, which is the duplicate notification the design exists to prevent. A wall-clock budget is now enforced, per-request timeouts are capped below it, and the token refresh is skipped rather than started when the budget is already spent.
- **Fixed three independent check runners with no mutual exclusion.** The scheduled receiver, the "check now" button and the debug trigger each ran on their own thread, so two could read the same active set and both decide an alarm was new. One process-wide guard now covers all three.
- **Fixed "check now" silently doing nothing.** The manual trigger inherited the foreground stand-down, so pressing the button while looking at the app skipped the check. It now bypasses the stand-down, which is what a user pressing it means.
- **Fixed `allowBackup="false"` not covering device-to-device transfer.** Since Android 12 that attribute disables cloud backup but not D2D, so a phone-to-phone migration would have carried the plaintext preferences to the new device, including the OpenWeatherMap key. `dataExtractionRules.xml` and `backup_rules.xml` now exclude everything from both paths.
- **Fixed the ThingsBoard host being validated only by an `https://` prefix.** A prefix test accepts *any* TLS host, so the first time the base URL became configurable — a normal request for an app like this — a mistyped or malicious host would have received a live bearer token. It is now an exact host allowlist, rejecting userinfo, non-443 ports and paths, which mirrors what `parseAllowedCctvUrl` already did correctly.
- **Fixed the OpenWeatherMap key going into logcat by accident.** An `org.json` parse error on the token refresh path embeds a fragment of the unconsumed response, which for that request is the JWT. Only the exception class is logged now.
- **Removed two unused permissions.** `WAKE_LOCK` was never acquired and `ACCESS_BACKGROUND_LOCATION` is never requested at runtime; the second is one a store review treats as sensitive.
- **Fixed background alarms never firing at all.** `android_alarm_manager_plus` requires its `AlarmService` and `AlarmBroadcastReceiver` to be declared in the app manifest, and neither was. The 15-minute alarm was therefore registered but never delivered, which is why `progress.md` recorded "never a real alarm appeared" as untested rather than broken. The dependency is removed entirely and replaced by native Kotlin; see the Added entry below.
- **Fixed three light-mode colours that claimed to pass WCAG AA and did not.** Measured against the surfaces they are actually drawn on rather than against white, the amber warning colour was 4.02:1 and the secondary-text grey 4.29:1, both below the 4.5:1 that AA requires for text at 9–11dp; green was only 4.67:1. They are now 5.21:1, 5.11:1 and 5.19:1. The earlier claim of compliance had been measured against the wrong surface, and `test/color_helpers_test.dart` now checks every colour against the real values from `main.dart` and `liquid_glass.dart`.
- **Fixed a duplicate notification on every cold start.** The active-alarm set was read from the native module *asynchronously, after* the dashboard had already decided an alarm was new, so opening the app re-announced alarms the background had already reported. The set is now read before the first evaluation, and notifications are held back until it arrives. Covered by `test/alarm_rules_test.dart` via `newlyActiveSignals`.
- **Fixed the background alarm being dropped by vendor power management.** The repeating alarm fired six times and then silently disappeared from `dumpsys alarm` on MIUI/HyperOS, with `com.miui.powerkeeper` in the same output, so alarms simply stopped arriving with nothing to indicate why. A second `setAndAllowWhileIdle` trigger, re-armed after every run, now backs it up.
- **Fixed a failed poll being reported as stale telemetry.** A device that produced no reading raised a `stale_*` alarm, so a network outage or a dead token turned into three misleading alarms instead of silence. An unread device now produces nothing, while a device that has stopped reporting still alarms — that is the distinction the alert was meant to draw.
- **Fixed background alarm credentials never reaching the native side.** The access token was sent inside the config payload while the native code read it as a top-level argument, so every check logged "no credentials stored" and did nothing. The credentials are now sent separately, which also keeps them out of the config file written to disk as plain JSON.
- Fixed `WeatherForecast.fromJson` parsing One Call API payloads with `WeatherData.fromJson`, which read `main.temp` / `wind.speed` / `coord` — keys that do not exist in that format. Added `WeatherData.fromOneCallJson` to correctly parse One Call entries (scalar `temp` in hourly, `temp.day` object in daily, snake_case `wind_speed`, no per-entry `name` or `coord`).
- Fixed `_estimateSolarIrradiance` to handle both current-weather (`clouds.all` nested) and One Call (`clouds` scalar) formats.
- Fixed splash screen logo not being rounded — wrapped `BrandLogo` in `ClipRRect` for consistency with the biometric unlock screen.

### Added

- **Added native background alarm checking** in `android/app/src/main/kotlin/tech/mbkm/energrow/alarm/`. An `AlarmManager` repeating alarm wakes a `BroadcastReceiver` that does the ThingsBoard reads with `HttpURLConnection` and posts notifications with `NotificationCompat`, so no Flutter engine is started. A background tick costs single-digit MB of RAM instead of the tens of MB a background Flutter isolate holds resident. Devices are polled in parallel and not retried, which fits the roughly ten seconds a manifest receiver is allowed; a full check measures around 0.45 s on the test device, against a worst case of over three minutes for the old sequential, retried Dart poll.
- **Added a second alarm trigger, `setAndAllowWhileIdle`, re-armed after every run.** A repeating alarm is the first thing vendor power managers remove: on the test device the repeating alarm fired six times and then silently disappeared from `dumpsys alarm`, with `com.miui.powerkeeper` in the same output, leaving alarms that were simply never delivered. The Doze-exempt trigger repairs that.
- **The check now runs every minute**, down from fifteen, and stands down while the app is in the foreground. A greenhouse alarm is only useful while the condition still is, and a check is now cheap enough to afford it. The stand-down avoids polling ThingsBoard twice over while the dashboard is already evaluating the same rules every ten seconds.
- Added `AlarmDebugReceiver`, declared only in `src/debug/AndroidManifest.xml` and refusing to act unless the app is debuggable, so one background check can be triggered on demand. Verifying the notification otherwise means waiting for a genuinely new condition, which can take hours.
- Added `lib/utils/alarm_rules.dart` as the single source of truth for what counts as an alarm. `buildAlarmRules` turns the user's thresholds into a rule list, `evaluateAlarmRules` runs it, and `alarmRulesToJson` ships the same list to the native module. The dashboard banner and the background notification now evaluate one rule list, so a threshold edited in Settings changes both and the wording cannot drift between the two.
- Added environment limits to the background check. Previously the periodic check only looked at low SOC and stale telemetry, so temperature, humidity and TDS alarms never produced a notification no matter how they were configured.
- Added `android/app/src/test/resources/alarm_parity_vectors.json`, replayed by `test/alarm_parity_test.dart` and by `AlarmParityTest.kt`, which pins the Dart and Kotlin evaluators to the same messages. The two implementations exist because Dart is not running during a background check; the shared fixture is what keeps them honest. Regenerate with `dart run tool/generate_alarm_parity_fixture.dart`.
- Added `test/alarm_rules_test.dart` — 20 tests covering rule construction, evaluation, freshness gating, announce-once semantics and JSON round-tripping, including the guard that TDS keeps no upper bound.
- **Added a "device has stopped responding" alarm** for every device, critical and separate from the stale warning. Ten minutes of silence in an MQTT pipeline is a hiccup; an hour is a sensor or gateway that has stopped, and the two need different responses. The threshold is configurable in Settings and defaults to 60 minutes, deliberately far above the stale window so a brief gap never escalates on its own.
- **Added working environment limits out of the box.** Temperature 15–35 °C, humidity 40–85 %, TDS ≥ 800 ppm, and environment alerts now default to on. Previously the feature existed but shipped empty, so the grid showed five numbers with nothing to read them against. The values suit a tropical greenhouse and live in `AlarmThresholds` as named constants, with the Settings screen and the engine both reading them.
- **Added a Background checks section to Settings** showing whether the check is armed, whether credentials are stored, when it last ran and what it found, plus a "check now" button and a shortcut to the battery optimisation screen. This exists because the failure mode is invisible by construction: a dropped alarm looks exactly like nothing to report, and this project spent several sessions guessing between the two.
- Added `AlarmBridgeStatus` and the bridge `status` / `checkNow` / `isScheduled` / `isIgnoringBatteryOptimizations` calls, so a background check can be inspected instead of guessed at.
- Added a second notification channel for critical alarms, letting the user silence warnings while keeping a low-battery alert.
- Added `WeatherService.dispose()` to release GPS handle and cached coordinates. Dashboard now calls it in its own `dispose()`.
- Added `test/weather_service_test.dart` — 15 tests covering both current-weather and One Call API parsing, serialization round-trips, and computed properties.
- Added `test/thingsboard_realtime_service_test.dart` — 21 tests covering service lifecycle, device configuration, `TelemetryPoint`, and `DeviceTelemetry`.
- Added `test/color_helpers_test.dart` — 8 tests pinning that `metricColor` and `strongMetricColor` never rotate hue away from the accent the user picked, and that every text colour in the file clears AA on the real surfaces.
- **Environment cards now show whether each reading is inside its limit**, with the configured range printed under the value and a single verdict for the whole grid. Five numbers with nothing to read them against is what the feature looked like before; a reading of 38 °C was visually identical to a healthy one until an alert banner appeared elsewhere on the screen. A stale sensor now says so instead of claiming everything is fine.
- **One status strip replaces three stacked banners.** Offline mode used to show a green "polling active" line directly above an orange "offline" line — two opposite claims about the same connection, stacked before any content. Precedence is now failure > offline > alert > stale, and the strip no longer auto-hides after three seconds, because a 3-second flash was the only connection indicator there was.
- **The dashboard's date strip now states the selected day** rather than the span of the seven chips. Tapping a chip left the label describing a range that no longer matched the selection, while the detail pages showed the correct single day, so two screens disagreed about the same state.
- **Telemetry values no longer all show two decimals.** A count and a percentage do not have hundredths, so the battery page read "Cycles 12.00" and "State of Charge 45.00 %". `MetricDef` takes a `decimals` and SOC, cycles and power now use one. DC and AC metrics are also labelled by side, so "Voltage" on the PV page is no longer ambiguous.
- **A fresh-data indicator is now always visible** on the hero card, quiet when current and amber when stale. There was no persistent sign of liveness anywhere in the Overview, so a dashboard that had quietly stopped updating looked exactly like a live one.
- **Metric colours follow the chosen accent, with no automatic variation.** A per-index hue rotation of 40° was added so the PV, AC and battery pages would be told apart by colour, and it was reverted at the user's request: a colour the user did not choose is a colour they cannot predict, and the app looked arbitrary rather than themed. The pages are distinguished by title and icon instead. If per-page colour is ever wanted it belongs in Settings as an explicit choice, not as a default.
- **The in-app alarm notice is now only the banner above the greeting.** The same messages were also shown in a `SnackBar`, so every alarm was stated twice — once where the user was already looking and once over the bottom of the screen, covering the energy card and the navigation bar. Worse, the `SnackBar` re-fired on any change to the message set rather than on any new alarm, so a reading drifting in and out of range popped a bar every few seconds while the persistent banner simply stayed.
- **Environment cards no longer carry tick and warning glyphs.** Out of range was signalled three ways on one card at once — a tick, a warning triangle and a coloured border — which turned a sensor reading into a checklist item. The border and the range caption remain, and the grid's permanent green "semua normal" state is gone; the header now speaks only when something is wrong.
- **Secondary text now passes WCAG AA.** The `Colors.white54` / `Colors.black45` pair measured about 3.4:1 on the light surface for text as small as 9dp, in 22 places. A contrast-checked pair replaced it, and small status colours moved off the Material defaults, which measure 2.3:1 at that size.
- **A white border on a white card is now a faint black one**, matching what the date chip already did in the same file.
- The four accent colours are unchanged. `Ocean cyan` and `Forest teal` do sit 19° apart and render similarly, and moving `Ocean cyan` to separate them was tried and reverted: a user who had already picked it would have silently been given a different colour, which is worse than two swatches looking alike.
- The glass toggle is now named for what it does. "Smooth Glass Mode" turned the blur *off* when switched on, the opposite of what the name promised.
- An empty or loading chart no longer reserves a full plot's height, and chart axis labels moved from 8dp to 10dp.
- The full battery capacity was already being fetched and displayed nowhere, so "Remaining Capacity 50.0 Ah" appeared with nothing to compare it to. It now sits next to the pack size.
- Health messages and transport state reach the UI in the interface language rather than as raw model strings.
- The environment range keys are named from `SettingsKeys` by the settings controller rather than re-derived from a sensor id, so the two can no longer drift apart uncaught.

- **Alarms are reported once per occurrence, not on every check.** The active alarm set is shared between the dashboard and the native module, so an ongoing low-battery condition produces one notification rather than one per interval. The previous implementation de-duplicated with a five-minute timer, which is *longer* than the check interval and so never actually prevented a repeat.
- Background alarm tokens are stored encrypted under a hardware-backed AndroidKeyStore key instead of being readable only by `flutter_secure_storage`, which cannot be reached without a Flutter engine. Dart keeps the canonical copies and re-pushes on launch; a refresh performed in the background updates only the native copy.
- The background check renews its own access token on a 401 and stops itself if the refresh token is rejected, so an expired session no longer looks like three unreachable devices.
- A device that produced no reading no longer counts as stale. A failed poll is missing data, not a condition, and treating it as stale turned a network outage into three misleading alarms.
- Removed the `android_alarm_manager_plus` dependency and its manifest receiver, and dropped the Android plugin count from 12 to 11.
- Moved `AlarmType`, `AlarmSeverity` and `AlarmRecord` from `alarm_history_service.dart` to `lib/models/alarm_record.dart`, so the rule engine depends on a model rather than on a service that does I/O.
- Promoted `alarm_helpers.dart` from `screens/dashboard/utils/` to `utils/`, now that the native module and the dashboard both read it.
- Added `lib/services/alarm_settings.dart` so the alert defaults are written in one place. They were previously repeated in the settings controller, the dashboard and the background service, which is how the same setting came to default to different values in different readers.
- Alarm history merges the records the background check wrote with the ones the dashboard wrote, and acknowledging or resolving now applies to both. The two stores stay separate because `shared_preferences` encodes a `List<String>` as a Base64 Java-serialized blob that the native side would have to reproduce byte for byte.
- All user-facing text in `alarm_history_screen.dart` is now English (title, dialog, buttons, filters, status badges, menu actions, empty state, month names).
- Documented battery power sign convention in `energy_forecast_service.dart` — `.abs()` is used because BMS vendors disagree on charge/discharge sign.
- Made dashboard overview page more compact: reduced card spacing from 12–20px to 8px, reduced internal padding across all dashboard cards (LivePowerCard 18→14, DualStatusCards 14→10, EnergySummaryCard 14→10, WeatherCard 12→10), changed EnvironmentGrid layout from 2+2+1 to 3+2 for better space efficiency.

### Removed

- Removed the `geocoding`, `csv` and `cupertino_icons` dependencies. None of them was imported anywhere, and `geocoding` was still pulling a full Android plugin into the build for no reason — it had even been upgraded once specifically for Android 14 compatibility, for a code path nothing used.
- Removed `WeatherService.searchCities`, `AlarmHistoryService.getAlarmsSince` / `acknowledgeAlarm` / `resolveAlarm` / `_find`, `alarmValueFromId`, `clearCctvUrl`, `fetchHistory` and the `DashboardShortcut` widget, plus the unused `EnergyForecastCard` file. All were verified to have no callers before removal.
- Removed the 22 telemetry key literals duplicated in `telemetry_helpers.dart`. They were written out a second time despite a comment on the originals stating that one source makes it impossible for them to come apart, which is exactly what would have happened.

### Documentation

- Added `AGENT_PLAYBOOK.md`, a working manual for agents on this repo: the
  mandatory reading list with the five questions it should answer, when a subagent
  is worth spawning and when one `grep` is enough, the six rules about subagents
  that prevent file collisions, the environment numbers that decide whether two
  builds can run at once, the hard rules, ten harness and domain gotchas that have
  cost real time, the verification gates including what can only be checked on a
  device, and the commit protocol. It is written from what actually happened this
  session, including the harness failures: file content mutating on write,
  backticks inside a shell-interpreted `python3 -c` silently deleting a filename,
  line-index edits landing on the wrong line, and a long `write` call truncating
  mid-document.
- Added `FEATURE.md`, an inventory of what is actually implemented, verified
  against the source rather than against the other markdown files. Each entry says
  where the feature lives and what proves it works, and §18 lists the gaps: nine
  functional ones, twenty-odd dead or unreachable symbols, seven behaviours that
  are counter-intuitive rather than wrong, five test gaps, and six things that no
  one has yet seen on a device. The reason it exists is in its own header: three
  label regressions in one session passed `flutter analyze`, the release build and
  every existing test, and were only found by looking at the screen.

- Documented the native alarm module in `AGENTS.md`: the one-rule-list contract, why `AlarmManager` is inexact and why there are two triggers, the foreground stand-down, the token handover, the debug trigger, and the parity fixture that keeps the two evaluators in agreement.
- Rewrote `README.md` around the background alarm capability, with the measured cost of a native check against a Flutter isolate, and corrected the stale "push notification belum tersedia" claims.
- Corrected `PRD_PLTS_Monitoring_App.md` §4.5, §6 and §7, which still claimed no alert reaches the user while the app is closed.
- Replaced `progress.md` §10.5, which had recorded the old Dart alarm as merely untested. It was broken, and the reason was a missing manifest declaration.
- Recorded the security review outcome in `AGENTS.md`, including the two findings that were real defects in brand-new code: the receiver time budget and the missing mutual exclusion between check entry points.
- Updated `AGENTS.md` with current test coverage (227 Dart tests, 11 Kotlin unit tests), coordinated upgrade blocker for `package_info_plus` / `share_plus`, and `WeatherService.dispose()` note.

# Changelog

All notable changes to this project are documented here.

## [1.4.0] - 2026-09-26

### Added

- Added `dart_test.yaml` serialising the test suite, which keeps the Dart compiler and the test isolate from competing for memory on low-RAM machines
- Added `SettingsKeys` (`lib/models/settings_keys.dart`) as the single source of truth for `SharedPreferences` keys shared by the Settings screen, Dashboard, and background alarm service
- Added `SettingsController` (`lib/screens/settings/settings_controller.dart`) owning all settings state, validation, and persistence
- Added `CctvStatus` (`lib/screens/cctv/utils/cctv_status.dart`) deriving the stream state from the player flags
- Added `PeriodTotals` plus `bucketsForPeriod`, `previousPeriodTotals`, `totalsOf`, and `totalSampleCount` (`lib/screens/energy_report/utils/period_buckets.dart`)
- Added `niceStep` and `niceTimeStep` (`lib/screens/dashboard/charts/chart_data.dart`) for human-friendly axis intervals
- Added `formatAxisDate` and `formatAxisTick` for axis ticks that span more than one day
- Added unit tests for the extracted settings validation (`test/settings_validation_test.dart`)
- Added unit tests for the CCTV status model and the `parseAllowedCctvUrl` host allowlist (`test/cctv_test.dart`)
- Added unit tests for the energy report period and chart helpers (`test/energy_report_helpers_test.dart`)
- Added unit tests for the chart axis interval logic (`test/chart_bounds_test.dart`)
- Added widget tests for the settings browser (`test/settings_screen_test.dart`) covering category listing, section drill-down, back navigation, and CCTV URL rejection
- Added unit tests for the extracted dashboard helpers (`test/dashboard_helpers_test.dart`) covering history window resolution, sampling intervals, energy integration, cached telemetry partitioning, and telemetry comparison
- Added `glassDividerColor` helper so divider tinting stays consistent across glass cards
Added `AGENTS.md`, a working-notes file for coding agents covering the build
environment, the `dl.google.com` throttling workaround, and the project conventions
that are easy to get wrong.
Added `.gitattributes` forcing LF line endings, plus `core.autocrlf = input` on this
repository, so the 126 files that were showing as modified purely because they had
CRLF in the working tree no longer do.
Added `SettingsKeys` usage notes and the `dependency_overrides` block that keeps
`path_provider_android` on 2.2.23.

### Changed

- Changed the Android `applicationId` and `namespace` from `com.example.plts_monitoring` to `tech.mbkm.energrow`, and moved `MainActivity` to the matching package path
- Changed chart axis intervals to snap to round values, so a 24-hour view now labels ticks on the hour instead of at arbitrary offsets such as 02:10
Pinned `path_provider_android` to 2.2.23 via `dependency_overrides`. Version 2.3.0
rewrote its Kotlin side on top of the `jni` package, which forced a CMake and NDK
toolchain to build a 130 KB shared library. This drops the Android plugin count from
14 to 12 and removes `libdartjni.so` from the APK. `share_plus_platform_interface`
depends on `path_provider` unconditionally in every published version, so the chain
cannot be cut at the app level. Both versions target the same
`path_provider_platform_interface ^2.1.0`, so the plugin API is unchanged.
Removed `ndkVersion = "30.0.16248370"` from `android/app/build.gradle.kts`. Nothing in
the app compiles native code, and the pin only made AGP fetch a second, divergent NDK
copy. Note this does not stop the download: AGP still installs Flutter's default NDK
during configuration. Verified with no `ndk/` and no `cmake/` in the SDK: it fetches
28.2.13676358, then produces zero `.o` files and no `build.ninja`.
Lowered the Gradle JVM heap in `android/gradle.properties` from `-Xmx8G`
`-XX:MaxMetaspaceSize=4G` to `-Xmx1536M`, plus a 1 GB Kotlin daemon. The old values
reserved 12 GB on a machine with 7.1 GB of RAM, so the daemon could never be
satisfied and was at risk of being OOM-killed.
Changed the Gradle wrapper distribution from `gradle-9.3.1-all.zip` to `-bin.zip`,
saving roughly 1.2 GB of download since only the binaries are needed to build.
Ignored `/.kotlin` in `android/.gitignore`; the Kotlin Gradle plugin writes session
state and incremental caches there during every build.

### Fixed

- Fixed telemetry chart axis labels being clipped or overlapping at the plot edges, by nudging the first and last bottom-axis labels back inside the chart
- Fixed multi-day chart ranges labelling every tick with a clock time, which made a week view show `00:00` repeatedly; ticks now show a date instead
- Fixed a test in `cctv_test.dart` that called `tester.getSemantics` without enabling semantics, which could hang the isolate and mark every later test in the file as "did not complete"
- Fixed that same test matching a `Semantics` node owned by `Scaffold` instead of the one under test
- Fixed the CCTV stream URL set in Settings never taking effect: it was written to `SharedPreferences` while the Dashboard reads it from secure storage, so the edit was silently discarded. Settings now persists it through `saveCctvUrl()` and loads it through `loadCctvUrl()`
- Fixed a duplicate `defaultCctvUrl` constant in Settings that shadowed `defaultAllowedCctvUrl` from `cctv_url.dart`
- Fixed the embedded and full screen CCTV layouts maintaining two copies of the video/standby/loading/error stack, which could drift apart
- Fixed the expanded and collapsed glass nav bars keeping duplicate icon/label literals by sharing one `kNavDestinations` list

### Removed

- Removed the unused `active` parameter from `CctvScreen`

### Documentation

- Updated the README Known Issues: the CCTV stream is now live, so the pending `go2rtc` note was replaced with the actual caveats (WebView battery cost while polling continues, rounded Y axis labels)
- Documented that changing `applicationId` requires uninstalling the previous build, and that the stored session does not carry over
- Recorded the features verified on a physical Android 16 device
Consolidated this changelog. It had accumulated three `[Unreleased]` headings and three
conflicting `1.3.0` headings from an unclean merge. The three `1.3.0` blocks were all
part of the tagged `v1.3.0` release and are now merged into one section; the block
headed `[Unreleased] - 2026-09-25` was verified against git tags and belongs to 1.3.1,
since the realtime telemetry, connection health, energy forecast, and background alarm
commits all landed before the `v1.3.1` tag.
Recorded in `AGENTS.md` that the NDK download cannot be avoided from the project side:
`FlutterPlugin.kt` calls `forceNdkDownload` unconditionally for every app project, and
that function fabricates a synthetic `externalNativeBuild` so AGP believes an NDK is
required. There is no opt-out flag.

### Refactoring

- Refactored CCTV screen from 480 lines to 319 lines (-34%), sharing one `CctvViewport` between the embedded and full screen layouts
- Refactored Energy Report screen from 233 lines to 174 lines (-25%), moving period bucketing and comparison totals into pure helpers
- Extracted `_SelectedBucketReadout` and `_BucketStepper` from the energy report chart card, which had duplicated the touched-index clamping in two listeners
- Replaced the opaque `(double, double)?` totals record with a named `PeriodTotals` class
- Simplified `calculateMaxY`, which used a four-branch nested ternary fold
- Refactored Settings screen from 754 lines to 157 lines (-79%), splitting it into a controller, shared field widgets, and one file per settings group
- Extracted dashboard presentation widgets into `lib/screens/dashboard/widgets/`: `GlassNavBar`, `LivePowerCard`, `DualStatusCards`, `EnvironmentGrid`, `GreetingHeader`, `DateStrip`, `TelemetryCard`, `TelemetryChartCard`, `ChartSectionHeader`, and the banner set (`ConnectionStatusBanner`, `OfflineBanner`, `EnergyAlertBanner`, `TelemetryErrorView`)
- Extracted dashboard logic into pure helpers under `lib/screens/dashboard/utils/`: `history_range.dart`, `energy_helpers.dart`, `telemetry_helpers.dart`
- Refactored Dashboard screen from 3,046 lines to 1,389 lines (-54%), leaving the screen as a state container plus page composition
- Replaced the static section builders that reached into `_SettingsScreenState` with widgets that take `SettingsController` explicitly
- Replaced the `Map<String, _RangeControllers>` of environment limits with a typed `EnvRangeSetting` list that carries its own label, unit, bounds, and preference keys
- Moved threshold parsing in `_loadPreferences` into a single `_readDouble` helper
- Extract `_storeHistory` and `_notifyLive` in the dashboard to remove repeated notify branches

## [1.3.1] - 2026-09-26
### Added

- Added Weather monitoring feature with OpenWeatherMap API integration
  - New `WeatherService` class for fetching current weather and forecasts
  - New `WeatherData` and `WeatherForecast` data models
  - Weather card widget on Dashboard showing temperature, humidity, wind, cloud cover
  - Weather settings section in Settings screen with API key and city configuration
  - Test connection button to verify API key and location
  - GPS location support for automatic weather fetching
- Added modular architecture for Energy Report screen with extracted widgets (PeriodSelector, TotalsCard, ChartCard, DataNote, EmptyAndErrorViews, ExportButton) and utilities (format_helpers, csv_builder, chart_helpers, chart_helpers)
- Added modular architecture for Dashboard screen with extracted chart utilities (MetricDef, SeriesStats, ChartSeries, ChartBounds, processSpots) and helpers (alarm_helpers, bound, color_helpers, date_helpers)
- Added modular architecture for Settings screen with extracted _RangeControllers, _Section, static builder functions, and shared helpers
- Added Energi Analytics title for Energy Report screen (replaced "Laporan energi")
- Added comprehensive CHANGELOG documentation for all refactoring changes

### Changed

- Updated Android `compileSdk` to 36 to support latest plugin requirements (android_alarm_manager_plus, flutter_local_notifications, geolocator, etc.)
- Updated `geocoding` dependency from ^2.1.1 to ^5.0.0 for Android 14+ compatibility
- Added GPS permissions (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION) to AndroidManifest.xml
- Refactored Energy Report screen from 809 lines to 251 lines (-69%) with modular widget/utility structure
- Refactored Dashboard screen from 3,072 lines to 2,550 lines (-17%) with ~500 lines extracted to reusable utilities
- Refactored Settings screen from 816 lines to 470 lines (-42%) with consolidated validation, persistence, and builder patterns
- Renamed Energy Report screen title from "Laporan energi" to "Energi Analytics"
- Moved `await loadCctvUrl()` outside `setState` in `_loadPreferences` to fix async context issue
- Restructured all three screens to use modular widget/utility architecture with clear separation of concerns

### Improved

- Reduced total codebase by ~1,000 lines through modular extraction while preserving all functionality
- Improved maintainability with clear separation of concerns (widgets, utils, charts, helpers)
- Enhanced testability with pure functions in utility files
- Enhanced reusability of chart helpers, date formatters, color helpers, and alarm helpers across screens
- Zero breaking changes - all functionality preserved
- Better error handling in WeatherService with descriptive messages for API errors (401, 404, etc.)
- Weather service now properly throws exceptions for GPS permission issues instead of silently failing
- **Weather card compact redesign**: Single card with all metrics (temperature, humidity, wind, cloud cover) in one row; removed solar irradiance section; reduced padding and spacing; uses theme colors (primary, secondary, tertiary, outline) that adapt to accent color from Settings
- **Fixed humidity text overflow**: Reduced font sizes (value: 14→12, label: 12→9), added ellipsis handling, smaller icons (20→18), optimized padding

- Added a smooth bottom navigation collapse while scrolling down on dashboard pages.
- Added live ThingsBoard telemetry over WebSocket with automatic reconnect and REST polling fallback.
- Added custom telemetry chart ranges for up to 90 days with adaptive aggregation intervals.
- Added a live/polling connection indicator to chart headers.
- Added connection health tracking for REST, WebSocket, and polling transports, including reconnect count and last successful update.
- Added energy analytics for production forecasting, target comparison, peak usage, and estimated battery runway.
- Added a Settings field for configuring the daily production target in kWh.
- Combined dashboard energy summary and forecast into one Energy Analytics card.
- Added alarm deduplication, acknowledgement/resolution workflow, reopening, and severity/status filters.
- Hardened session refresh invalidation, token validation, WebSocket authentication guards, and API error handling.
- Added visible date-range calendar controls directly to PV, AC, and Battery chart headers.
- Anchored the collapsed navigation control to the left so the panel visually shrinks from right to left without shifting the dashboard content.
- Updated bottom navigation labels to English: `Overview`, `PV`, `AC`, `Battery`, and `CCTV`.
- Added scroll-direction and distance thresholds to prevent accidental navigation transitions during small gestures.

### Fixed

- Fixed Dart analyze errors in `weather_service.dart` (parentheses for type casting) and `weather_card.dart` (unnecessary underscores)
- Fixed async context error in Dashboard `_loadPreferences` by moving `await loadCctvUrl()` outside `setState` callback
- Resolved merge conflicts in settings_screen.dart and energy_report_screen.dart keeping refactored versions
- Fixed import paths in all extracted utility/widget files for correct module resolution
- Fixed weather data not updating on dashboard after saving API key in settings
- Fixed weather card refresh button and settings button in no-data state

- Prevented the bottom navigation animation from changing the Scaffold layout height or causing the dashboard to disappear while scrolling.
- Replaced abrupt navigation content switching with a crossfade and eased width animation.
- Fixed the date-range picker failing to open when the current day was selected by normalizing picker dates and validating the initial range.
- Optimized forecast calculations by removing redundant combined-history sorting and allocations.
- Forecast progress now refreshes after the daily target is changed in Settings.
- Forecast calculations now use today's PV production and show the actual energy accumulated today.
- Added local alarm notifications when alarms are detected during active monitoring.
- Added periodic Android background alarm checks with local notifications after reboot.
- Kept the detailed energy report flow for historical charts, custom ranges, and CSV export.
- Avoided blocking app startup on alarm notification setup by initializing alarm services asynchronously after `runApp` and guarding failures so they no longer prevent the dashboard from launching.

## [1.3.0] - 2026-09-25
### Added

- Added last-known telemetry caching with `SharedPreferences` and an offline dashboard banner showing the cache age.
- Added telemetry retry handling with exponential backoff for network failures and HTTP 5xx responses.
- Added persistent alarm history for low SOC, stale telemetry, and environment threshold alerts, with a dedicated history screen and clear action.
- Added screen-reader semantics for telemetry metrics, charts, gauges, connection status, CCTV controls, and energy reports.

- Added configurable local alerts for ambient temperature, humidity, and water TDS. Blank thresholds are ignored, and alerts only evaluate fresh sensor telemetry.
- Added a dashboard status that distinguishes ThingsBoard fetch failures from stale telemetry and shows the last successful fetch time.
- Added validation for environmental threshold ranges in Settings.

### Changed
- Restructured settings page from a single flat scrolling page into a nested category-based navigation pattern (like phone settings)
- Settings main page now shows a list of 8 categories: Appearance, Monitoring, Energy alerts, Environment alerts, CCTV source, Performance, About, Account
- Tapping a category navigates to a detail page showing only that category's options
- Added AnimatedSwitcher (200ms) for smooth transitions between category list and detail pages
- Added PopScope to intercept system back button: when viewing a detail page, back returns to the category list instead of exiting to dashboard
- AppBar dynamically shows the category name as title when viewing a detail page, with a back arrow button
- Save button is only visible on the main category list page (hidden in detail pages)
- All existing logic preserved: SharedPreferences keys, save mechanism, validation, theme controller calls, logout flow

### Improved

- Merged successful telemetry snapshots from the battery, PZEM, and environment devices so offline mode can restore the complete dashboard state.
- Preserved existing alert SnackBars while recording newly triggered alerts in alarm history.

- Smoothed dashboard page transitions by reducing unnecessary rebuilds, isolating page repaints, and optimizing chart rendering.
- Improved the ThingsBoard connection banner with a three-second display period and smooth fade/collapse exit animation.
- Enhanced chart touch tooltips with one shared timestamp and combined `V`, `A`, and `W` values in a rounded frosted-transparent panel.
- Rounded the saved-session logo shown on the biometric authentication screen.
- Reduced dashboard rebuilds during telemetry updates by isolating live metrics, alerts, connection status, charts, and CCTV content with targeted listenables.
- Added chart point processing and memoized statistics to reduce rendering work for large telemetry histories.
- Improved energy report chart interaction and rendering with repaint isolation and a dedicated touch-state notifier.
- Improved ambient glass rendering with repaint isolation for smoother scrolling and page transitions.

### Fixed
- System back button (Android gesture/swipe) now correctly returns to the settings category list instead of immediately exiting to the dashboard

### Validation

- `flutter analyze --no-pub` passed with no issues.
- `flutter test --no-pub` passed.
- Debug APK built, installed, and launched successfully on Android device `24090RA29G`.

## [1.2.3] - 2026-09-24

### Fixed

- Applied the configured stale telemetry threshold consistently to device cards and the Overview summary.
- Added landscape fullscreen playback controls for CCTV.
- Synchronized the Settings version label with the application release version.

## [1.2.2] - 2026-09-24

### Added

- Added estimated daily and seven-day PV production and AC consumption summaries, compared with the previous equivalent period.
- Added configurable in-app alerts for low battery SOC and stale telemetry.

### Improved

- Redesigned the CCTV page with a standby state, camera status, and clearer playback controls.
- Changed CCTV playback to start only after the user presses **Play kamera**; added stop, retry, and reload controls.
- Avoided rebuilding the dashboard when periodic telemetry polling returns unchanged values.

## [1.2.1] - 2026-09-24

### Improved

- Reduced chart history loading from three requests to one request per device.
- Smoothed the dashboard app bar blur and reduced excess scroll space.
- Refined the date selector and grouped Settings into clear sections with System, Light, and Dark appearance options.

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

### Validation

- `flutter analyze` passed with no issues.
- `flutter test` passed.
- Release artifact: `app-release.apk`.

### Known limitations

- Push notifications, biometric login, WebSocket telemetry subscriptions, and FNN/XAI prediction remain roadmap items.
- Historical chart availability depends on ThingsBoard telemetry keys and retention.
- The application requires access to the ThingsBoard server and does not provide full offline mode.
