/// The Overview page, rebuilt as one instrument panel.
///
/// ## Why this file exists
///
/// The Overview used to be five separate cards — the live-power hero, the sky
/// card, the energy summary and the status strip, each in its own rounded box
/// with its own padding and its own gap. On a 411 dp phone that is five
/// rectangles, five sets of edges, and four gaps that all say "these are
/// different things" — which was true, and also not what the page is.
///
/// The page is one instrument. A grower opening it is asking a single question:
/// *what is the system doing right now*. So it is now one panel: a header, a
/// hero figure, and a stack of labelled rows separated by hairlines, the way a
/// rack-mounted unit presents itself.
///
/// ## One accent, and what it costs
///
/// The rest of the app is categorical: PV lime, AC blue, Battery violet, and so
/// on, so a hue means a category of data. **This panel carries no category hue
/// at all, and that is a real divergence, not an oversight.** A terminal panel
/// gets its hierarchy from weight, case, tracking and position, and a
/// categorical hue sitting in every row would flatten exactly the structure the
/// panel is building.
///
/// The panel is a black instrument with a single red accent: the hero figure,
/// the section headings and the meter fills are [AppPalette.error], and the
/// rows are white on black. **Red is the instrument's own colour, not a claim
/// that something is wrong** — that is a deliberate change from the earlier
/// monochrome rule, which reserved red for an out-of-bounds value. The category
/// tabs keep their hues; this is one page, not a new app.
///
/// ## The label vocabulary
///
/// `PV_OUT`, `AC_LOAD`, `BAT_SOC` — abbreviated, underscored, monospace. This is
/// the panel's strongest signal and it costs nothing: it reads as instrumentation
/// rather than as a consumer dashboard, and an abbreviation is a smaller
/// promise than a word. A label is a *slot name*, and a slot name is what the
/// thing is called in the thing's own system.
///
/// ## What is deliberately absent
///
/// No sparkline, and no second chart. The Overview's job is the current state;
/// history is one tap away on three of the four tabs, and a trend line drawn at
/// this density would be too small to read a value off anyway.
library;

import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/design_tokens.dart';

/// The single frame every row in the panel is drawn inside.
///
/// **One [AppCard] for the whole page rather than five.** The previous layout
/// drew a border around each section and a gap between them, so the page read as
/// a stack of separate widgets rather than as one readout. A single frame with
/// hairline rules inside it is the difference between a list of cards and an
/// instrument.
class TerminalPanel extends StatelessWidget {
  const TerminalPanel({
    super.key,
    required this.children,
    this.header,
    this.semanticLabel = 'Overview',
  });

  /// The panel's first row: a title, a station-style id, and any status.
  final Widget? header;

  /// What a screen reader announces for this panel.
  ///
  /// **A parameter because the label used to be the literal `'Overview'`, which
  /// was correct only while every panel on screen was the Overview.** It is a
  /// shared primitive: `MetricGrid` uses it for the greenhouse and the fish tank
  /// too, and a screen reader read "Overview" while describing a pH table is not
  /// a cosmetic bug — it is the one string a non-sighted user has to judge the
  /// page by. Defaulted rather than required so no existing call site changes.
  final String semanticLabel;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const Divider()],
          ...children,
        ],
      ),
    );
  }
}

/// One labelled row: a monospace key on the left, a value on the right.
///
/// **The unit hangs off the value, not off the key.** `PV_OUT` / `412 W` says
/// what the number is; `PV_OUT (W)` / `412` makes the reader parse the key to
/// learn the unit and then look away to read the figure. The right edge is
/// where the eye lands, so that is where the unit belongs.
///
/// [divider] draws the hairline *below* this row, which is what makes a stack of
/// these read as a table rather than as unrelated lines.
class TerminalRow extends StatelessWidget {
  const TerminalRow({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.alert = false,
    this.divider = true,
    this.tint,
    this.glyph,
    this.trailing,
    this.onTap,
    this.valueStyle,
  });

  /// A fixed-size mark drawn just before the figure, e.g. [DotGlyph].
  ///
  /// **A separate slot rather than folding it into `trailing`, because the two
  /// sit on opposite sides of the row and mean opposite things.** `trailing` is
  /// metadata *about* the figure and hangs off the right edge. A glyph *is* the
  /// figure's subject - it is the sky, drawn - so it belongs with the value, on
  /// the value's side of the label.
  final Widget? glyph;

  /// The figure's type, and it exists because [AppType.slotValue] is too large
  /// for a row carrying three of them.
  ///
  /// **The value sits in a `FittedBox(scaleDown)`, so without this the size is
  /// decided by how much room is left over** — which is not a property of the
  /// value. On the Overview's own panel every row fits and draws at
  /// `slotValue`; on the period—summary panel the ENVIRONMENT and FISH rows
  /// carry `min / avg / max` triples plus a limit caption, and each one was
  /// shrunk by a *different* amount depending on how long its own numbers were.
  /// Two rows in the same column, the same widget, two font sizes, and the
  /// difference tracked string length rather than meaning. A caller that knows
  /// its values are all the same shape can name the size instead.
  ///
  /// [AppType.slotValueSmall] is what the summary panel passes.
  final TextStyle? valueStyle;

  /// The slot name — `PV_OUT`, `BAT_SOC`, `SKY_LUX`.
  final String label;

  /// The figure, right-aligned and tabular.
  final String value;

  /// The unit, set smaller and muted immediately after [value].
  final String? unit;

  /// Draw the value in [AppPalette.error].
  ///
  /// **The only colour this panel has**, and it means "out of bounds" — never
  /// "battery" or "environment" or any other category. A panel that colours by
  /// category cannot also colour by severity, because then red means two things
  /// on one screen.
  final bool alert;

  /// Draw a hairline under this row.
  final bool divider;

  /// An optional hue for the *label* only, for a category marker dot.
  ///
  /// Reserved. Nothing sets it today; it exists so a future row can carry a
  /// category cue without the value losing its severity colour.
  final Color? tint;

  /// Extra content between the value and the right edge — a badge, a mini bar.
  final Widget? trailing;

  /// Makes the whole row a target.
  ///
  /// **The row is ~47 dp tall, which is the 48 dp minimum to within a dp** —
  /// unlike the meter's 6 dp bar, which is why that one needed its captions
  /// inside the hit region and this one does not.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueColor = alert ? AppPalette.error : AppSurfaces.onSurface;
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        // 9, not 7. The row was 43 dp tall while the doc below claimed that
        // "clears the 48 dp minimum" — it did not, by 5 dp. A reading you are
        // meant to act on is the one row here that navigates, so it is the one
        // that has to be reachable with a thumb. 9 lands it at 47-48.
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (tint != null) ...[
            _Dot(color: tint!),
            const SizedBox(width: AppSpacing.sm),
          ],
          // **`Flexible` + `FittedBox`, because the vocabulary has no short
          // words.** `Discharging` and `Heavily overcast` are values this panel
          // actually renders, and at a 2.0 system font both overflowed the value
          // column — `Discharging` lost its last two glyphs and `Heavily
          // overcast` ran off the right edge of the card. A panel whose own
          // labels get clipped is the one thing it must not do.
          //
          // The `Flexible` is load-bearing and is the second half of that fix: a
          // `FittedBox` alone inside a `Row` gets an unbounded constraint, sizes
          // to its child and never scales. Without it, `FittedBox` is decoration.
          // **`FlexFit.tight`, and it is what puts the figure on the right edge.**
          //
          // Measured on an unmodified build (`test/zz_probe_test`, since deleted)
          // at 381 and 320 dp, with the real `TerminalPanel` around it:
          //
          // | slot | left | right |
          // |---|---|---|
          // | `AC_LOAD` | 16.0 | 97.6 |
          // | `26` | 109.6 | 157.3 |
          // | `W` | 161.3 | 172.6 |
          //
          // The row is 381 wide and the figure ends at 172.6 - 208 dp of empty
          // card to the right of the reading. `Flexible` defaults to
          // `FlexFit.loose`, so the `FittedBox` shrink-wraps to its own width and
          // `RenderFlex` packs every child from the start using the child's
          // *actual* size, not the space it was allocated. The leftover that
          // `mainAxisAlignment` would have distributed lands at the end of the
          // row, which is exactly where the figure was supposed to be.
          //
          // `tight` forces each flexible box to fill the share it was given, and
          // *then* the two alignments do what they already say: the slot name
          // paints from the left edge of its share and the figure paints to the
          // right edge of its own. The label walks away from the figure and the
          // figure walks to the right edge, in one change.
          //
          // The `FittedBox`es stay. A slot name long enough to need shrinking
          // still shrinks - that is the same `scaleDown` it has always had, only
          // now against a share that is actually its box.
          Flexible(
            fit: FlexFit.tight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: AppType.slotKey.copyWith(
                  color: AppSurfaces.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (glyph != null) ...[glyph!, const SizedBox(width: AppSpacing.xs)],
          // **The value is the one thing that must never be shortened**, so it is
          // outside the `FittedBox` and the *unit* is the one that yields when
          // the row is tight. `kW` becoming `k` would be wrong; `W` becoming
          // nothing would not.
          Flexible(
            // **`tight` here too, for the reason written on the label above.**
            // The figure's share has to be a box the figure can be pushed to the
            // right edge *of*; under the default `loose` the share is only a
            // ceiling and the box collapses to the glyphs.
            //
            // **`flex: 2`, and the caption is why.** The caption on the other
            // side of the unit is also flexible, so the free space is split by
            // flex ratio. At 1:1 the limit caption took half the row and the
            // figure's right edge stopped a third of the way short - measured
            // at 320 dp, a `40.1 / 71.6 / 94.9` triple ended at 193.5 of 320
            // with `15-50` filling the right. The figure is the reading and the
            // caption is metadata about it, so the figure gets the wider share
            // and the caption yields first.
            flex: 2,
            fit: FlexFit.tight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: (valueStyle ?? AppType.slotValue).copyWith(
                  color: valueColor,
                ),
              ),
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              unit!,
              style: AppType.slotUnit.copyWith(
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
          ],
          // **The caption sits at the right edge, after the figure, and never
          // between the slot name and it.**
          //
          // Measured with the caption in the slot before the value
          // (`test/zz_probe_test`, since deleted), 381 and 320 dp:
          //
          // | text | left | right |
          // |---|---|---|
          // | `AMBIENT_T` | 17.0 | 113.4 |
          // | `15-50` | 125.4 | 179.4 |
          // | `40.1 / 71.6 / 94.9` | 191.4 | 287.8 |
          //
          // The caption was painted 6.8 dp from the slot name and 12 dp from the
          // figure, so the three read as one run of text with the caption
          // attached to the label - which is the one thing a caption must not
          // do. The limit belongs to the *figure*, so it goes on the figure's
          // side of the row: the slot name owns the left edge, the figure owns
          // the right edge, and the caption hangs off the figure.
          //
          // **`trailing` is not flexible, and that is deliberate.** Both
          // flexible boxes above are `tight`, so they take whatever the caption
          // leaves - but only because the caption is measured *first*.
          // `RenderFlex` lays out non-flexible children against the row's own
          // width and divides what is left between the flexible ones, so a
          // non-flexible caption is measured at its natural width and can never
          // wrap.
          //
          // A `Flexible` here wrapped instead, and not at a synthetic size: at a
          // 2.0 system font `15-50` - five characters - laid out 120 dp tall,
          // which is four lines. A loose constraint is an invitation to a `Text`
          // to wrap, and the caption is the one thing in the row with no shorter
          // form to fall back on.
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.swap_vert,
              size: 12,
              color: AppSurfaces.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onTap == null)
          body
        else
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.all(AppRadius.sm),
            child: body,
          ),
        if (divider) const Divider(),
      ],
    );
  }
}

/// A 6 dp category dot, for a row that carries one.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The panel's hero: one figure, enormous, in the accent.
///
/// **The figure is the page.** Everything else in the panel is supporting data,
/// and this is the one number that answers "what is happening" without a
/// calculation.
///
/// **It is drawn in [AppPalette.error] because red is the panel's accent, not
/// because the reading is a breach.** The figure is the number the page is
/// about, and an 88 dp glyph in the same red as every other accent on the panel
/// is what makes this read as one instrument rather than as five widgets.
///
/// It is drawn at [AppType.heroFigure] rather than reusing [AppType.displayLg]
/// because the tracking on the display scale is tuned for a short headline and a
/// live figure with changing digit count needs the tighter, tabular setting — a
/// value that changes width on every poll makes the whole panel twitch.
///
/// **Lively:** while the array is producing and the feed is live, the glow
/// pulses gently. Over a zero, or over a stale reading, it rests — a calm zero
/// is honest, and a breathing glow over one would be the panel claiming activity
/// it cannot back up.
class TerminalHero extends StatefulWidget {
  const TerminalHero({
    super.key,
    required this.figure,
    required this.unit,
    required this.slot,
    this.secondary = const [],
    this.isLive = false,
  });

  /// The main number, as the sensor reported it.
  final String figure;

  /// Its unit.
  final String unit;

  /// What the figure *is*, in the panel's slot vocabulary — `PV_OUT`.
  ///
  /// **This replaced a spelled-out caption ("House load") and it is not only a
  /// space saving.** A caption in sentence case above a 72 dp figure is the
  /// loudest quiet thing on the panel: it is set at the same size as every row's
  /// key but is the only line of prose on the screen, so the eye goes there
  /// first and then has to travel down to the number. Naming the slot in the
  /// panel's own abbreviated, underscored voice puts it on the header row with
  /// the stats, where it labels the whole block instead of competing with it.
  final String slot;

  /// Right-hand stats, as `(key, value)` pairs.
  final List<(String, String)> secondary;

  /// Whether the data source is live (realtime). Drives the subtle pulse.
  final bool isLive;

  @override
  State<TerminalHero> createState() => _TerminalHeroState();
}

class _TerminalHeroState extends State<TerminalHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  /// The glow at rest. **0.34, down from 0.55.**
  ///
  /// An 88 px figure carrying a *constant* halo is no longer a reading, it is a
  /// light source — the eye is pulled to the halo's edge rather than to the
  /// number inside it, and the row values below it, which are what the page is
  /// actually for, all read as secondary to a lamp. Dimmed to the point where
  /// you notice it only if you look for it.
  static const double _restStrength = 0.34;

  /// How many breaths the hero takes before it settles, per producing episode.
  static const int _pulseCycles = 6;

  /// Whether this episode has already used its cycles.
  bool _pulseExhausted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.26, end: 0.42).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.addStatusListener(_onPulseStatus);
    _updatePulse();
  }

  /// Records that this producing episode has spent its cycles.
  ///
  /// **Needed because `didUpdateWidget` runs on every poll.** Without it, the
  /// controller finishing its last cycle looks identical to "has not started",
  /// and the next ten-second poll restarts the whole thing — an unbounded
  /// animation wearing a `count`.
  void _onPulseStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _pulseExhausted = true;
  }

  @override
  void didUpdateWidget(TerminalHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePulse();
  }

  void _updatePulse() {
    final hasPower =
        widget.figure != '--' &&
        double.tryParse(widget.figure.replaceAll(',', '')) != null &&
        double.parse(widget.figure.replaceAll(',', '')) > 0;
    // **Pulse only while the array is producing and the feed is live.** A glow
    // that breathes over a zero, or over a stale reading, would be the panel
    // claiming activity it cannot back up.
    final shouldPulse = hasPower && widget.isLive;
    // **A pulse that runs a set number of cycles and then rests.**
    //
    // `repeat()` with no count never completes, and that has two costs that are
    // not visible in a screenshot. It repaints an 88 px shadowed glyph every
    // single frame for as long as the Overview is open — on a page whose whole
    // architecture is a `ValueNotifier` revision counter precisely so that
    // *nothing* rebuilds when nothing changed. And any future test that pumps
    // `OverviewReadings(isLive: true, pvPower: >0)` hits `pumpAndSettle()`, which
    // waits for frames to stop and would time out.
    //
    // The glow ends at [_restStrength], so what is left when it settles is the
    // same calm halo a non-animating panel would have drawn.
    if (shouldPulse && !_pulseController.isAnimating && !_pulseExhausted) {
      _pulseController.repeat(reverse: true, count: _pulseCycles);
    } else if (!shouldPulse) {
      // **The episode ends, so the next one is allowed its cycles again** — a
      // device that recovers and stops again should re-announce that it is
      // producing, not stay frozen at the resting glow for the rest of the day.
      _pulseExhausted = false;
      if (_pulseController.isAnimating) _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.removeStatusListener(_onPulseStatus);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.sm,
        AppSpacing.cardPadding,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.slot,
                style: AppType.slotKey.copyWith(color: AppPalette.error),
              ),
              const Spacer(),
              if (widget.secondary.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    for (final (key, value) in widget.secondary)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            key.toUpperCase(),
                            style: AppType.slotMicro.copyWith(
                              color: AppSurfaces.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            value,
                            style: AppType.slotValueSmall.copyWith(
                              color: AppSurfaces.onSurface,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
          // 8, from 4. The slot name and the secondary stats sit directly above an
          // 88 dp figure, and at 4 dp the cap-height of the figure touched the
          // descenders of the row it is labelled by.
          const SizedBox(height: AppSpacing.sm),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final strength = _pulseController.isAnimating
                  ? _pulseAnimation.value
                  : _restStrength;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // **`Flexible` + `FittedBox`, for the same reason every other
                  // figure on this panel carries it — and here the overflow is
                  // on the largest element in the app.** At 1.0 scale an 88 px
                  // monospace digit is ~53 dp, so `10000` is ~265 dp against
                  // ~379 dp of card and fits. At the 2.0 system font scale it is
                  // ~424 dp and the row is over by ~45: a hard `RenderFlex`
                  // overflow, drawn as a yellow-and-black stripe across the
                  // hero, on a phone with large text enabled. The figure shrinks
                  // before the unit does, which is the right order — `W` is three
                  // characters and `10000` is five.
                  Flexible(
                    fit: FlexFit.loose,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.figure,
                        maxLines: 1,
                        style: AppType.heroFigure.copyWith(
                          color: AppPalette.error,
                          shadows: AppShadows.glow(
                            AppPalette.error,
                            strength: strength,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.unit,
                    maxLines: 1,
                    style: AppType.heroUnit.copyWith(
                      color: AppSurfaces.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A bordered status tag — `[ CLEAR SKY ]`, `[ 2 ALARMS ]`.
///
/// **Outlined, not filled.** A filled tag is a block of colour, and this panel
/// spends its colour budget on severity alone; a fill here would make a routine
/// status louder than a real alarm. The outline says "this is a label" at the
/// same volume as everything else, and the text carries the meaning.
class TerminalTag extends StatelessWidget {
  const TerminalTag({
    super.key,
    required this.text,
    this.alert = false,
    this.onTap,
  });

  final String text;

  /// Red outline and red text — a breach, or an active alarm.
  final bool alert;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = alert ? AppPalette.error : AppSurfaces.onSurfaceVariant;
    final tag = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: alert ? 0.7 : 0.35)),
        borderRadius: AppRadius.all(AppRadius.badge),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppType.slotMicro.copyWith(color: color),
      ),
    );

    if (onTap == null) return tag;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.all(AppRadius.badge),
      child: tag,
    );
  }
}

/// A thin horizontal meter with a filled proportion and a caption underneath.
///
/// **The caption carries the two ends, because a bar with no scale is a shape.**
/// `0%` on the left and `100%` on the right turn a decorative bar into a
/// readable one, and they cost eight characters.
///
/// **The bar is 20 square blocks with 2 dp gaps, not a continuous rounded fill —
/// this follows the reference photo, so do not smooth it back into a pill.** A
/// continuous bar cannot show *where* the level is, and the flat ends are what
/// make the blocks read as blocks. The glow stays, per block: this is the one
/// surface on the panel where the accent is meant to emit.
///
/// **Lively:** the fill animates smoothly when the fraction changes, using
/// [AppMotion.state] (200ms ease-out) to reflect real-time updates.
///
/// The block height is explicit and `stretch` is load-bearing — a `Row` passes
/// loose vertical constraints, and a childless `DecoratedBox` under loose
/// constraints collapses to zero. That is the exact bar that shipped in 1.9.1.
class TerminalMeter extends StatefulWidget {
  const TerminalMeter({
    super.key,
    required this.fraction,
    this.alert = false,
    this.color,
    this.leftCaption,
    this.rightCaption,
    this.onTap,
  });

  /// The filled proportion, clamped by the caller.
  final double fraction;

  final bool alert;

  /// The fill colour. Defaults to the panel's red accent; a caller that needs
  /// another accent can pass one rather than the widget carrying a second rule.
  final Color? color;
  final String? leftCaption;
  final String? rightCaption;

  /// Makes the whole meter a target.
  ///
  /// **The hit area is the track plus its captions, not the 6 dp bar.** A 6 dp
  /// tall target is under the 48 dp minimum every platform calls accessible, and
  /// a shortcut to another page is exactly the control that has to survive a
  /// thumb. The `InkWell` wraps the column so the captions are in the hit region
  /// too, which is why this is a parameter rather than a gesture detector on the
  /// bar alone.
  final VoidCallback? onTap;

  @override
  State<TerminalMeter> createState() => _TerminalMeterState();
}

class _TerminalMeterState extends State<TerminalMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  double _prevFraction = 0.0;

  /// The fraction the last frame actually drew.
  ///
  /// **Kept separate from [_prevFraction] because the two answer different
  /// questions.** `_prevFraction` is where the next animation starts; this is
  /// where the bar visibly is. They are the same only when nothing is in
  /// flight.
  double _paintedFraction = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.state, vsync: this);
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _prevFraction = widget.fraction;
    // NaN- and range-safe, because a caller is allowed to pass an out-of-range
    // fraction and `TerminalMeter` clamps only at paint time. Seeding the
    // painted value with the raw one would carry NaN into the next
    // interpolation and the bar would go blank instead of clamping.
    _paintedFraction = widget.fraction.isNaN
        ? 0.0
        : widget.fraction.clamp(0.0, 1.0);
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(TerminalMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fraction != oldWidget.fraction) {
      // Seed from the value that was last painted, not from `oldWidget.fraction`
      // — the two differ whenever an animation is still running.
      _prevFraction = _paintedFraction;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // **The fill is the panel's red accent whether or not this meter is
    // alerting.** `alert` no longer changes the colour, because red is already
    // the accent — a second shade of it would say "worse" in a way the panel
    // cannot back up, and the row's own value already carries severity.
    final fill = widget.color ?? AppPalette.error;
    final clamped = widget.fraction.isNaN
        ? 0.0
        : widget.fraction.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Interpolate between previous and current fraction
        final t = _animation.value;
        final interpolatedFraction =
            _prevFraction + (clamped - _prevFraction) * t;
        // **Record what is actually on screen, not what it is heading for.**
        // `_prevFraction` used to be seeded from `oldWidget.fraction`, which is
        // the *target* of any animation still in flight rather than the value
        // being painted. The dashboard polls every 10 s against a 200 ms
        // animation, so that case is rare — but the one time it happens the
        // block count jumped backwards to a value the bar had already passed
        // and then animated forward again, and on a charging pack a 2-block
        // drop reads as a real change in state of charge.
        _paintedFraction = interpolatedFraction.clamp(0.0, 1.0);
        // **The proportion is quantised to whole blocks, and that is the bar.** 20
        // blocks on a ~349 dp track is a ~15 dp block and a 2 dp gap, which reads
        // as a segmented gauge at phone width and still resolves 5% steps —
        // finer than the caption's `NN%`, so the bar never claims more precision
        // than the label.
        final lit = (interpolatedFraction * _segmentCount).round().clamp(
          0,
          _segmentCount,
        );

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // **The block row is a `Positioned.fill` on the track, not a sibling.**
            // A non-positioned child lets the `Stack` size to it and hand it loose
            // constraints, which is how the 1.9.1 meter drew an empty track at 95%.
            SizedBox(
              // **8 dp, up from 6.** The bar is the only element on the panel
              // that answers "how full", and at 6 dp on a 47 dp row it read as a
              // rule that happened to be red on one end. 8 keeps it flat-ended
              // and square — the two things `terminal_panel_test.dart` pins —
              // and only gives it enough body to look like a gauge.
              height: 8,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppSurfaces.track),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _segmentCount; i++) ...[
                          if (i > 0) const SizedBox(width: _segmentGap),
                          Expanded(
                            child: i < lit
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: fill,
                                      boxShadow: AppShadows.glow(fill),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.leftCaption != null || widget.rightCaption != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Text(
                      widget.leftCaption ?? '',
                      style: AppType.slotMicro.copyWith(
                        color: AppSurfaces.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.rightCaption ?? '',
                      style: AppType.slotMicro.copyWith(
                        color: AppSurfaces.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

        if (widget.onTap == null) {
          return Padding(padding: _inset, child: body);
        }
        return Padding(
          padding: _inset,
          child: Semantics(
            button: true,
            // **And what it opens.** `button: true` on its own announces the
            // word "button" and nothing else — the caller has to say which
            // reading it is, because that is the one thing a sighted reader gets
            // from the figure and a screen-reader listener does not. Built from
            // the captions rather than from a separate argument, so it cannot
            // drift from what the meter actually prints.
            label: widget.leftCaption == null
                ? 'Open the battery readings'
                : 'Battery state of charge. ${widget.leftCaption}',
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: AppRadius.all(AppRadius.sm),
              child: body,
            ),
          ),
        );
      },
    );
  }
}

/// Blocks across the whole track.
const int _segmentCount = 20;

/// The gap between two blocks. Thin, because a wide gap makes the bar read as
/// a row of buttons rather than as one meter at a level.
const double _segmentGap = 2;

/// The air between a `TerminalRow` and the non-row content directly under it.
///
/// **Two call sites, and they disagreed.** The meter pads itself by this;
/// `MetricGrid`'s caption-only fallback — the row it draws when a spec has a
/// limit but no meter fraction — wrote its own `Padding` with a top of `0`. So
/// one cell's caption sat 4 dp higher than the rest of the column, and which
/// cell it was depended on whether the bar happened to exist for that spec.
const double kTerminalGapAbove = AppSpacing.xs;

/// The meter's own inset, kept in one place.
///
/// **Two call sites needed it and one of them was wrong.** The untappable
/// branch padded unconditionally; the tappable branch has to pad *outside* the
/// `InkWell` so the ripple is clipped to the meter's box rather than running
/// under the panel's edge. Having the padding as a field is what stops the
/// two from being written separately and disagreeing.
const EdgeInsets _inset = EdgeInsets.fromLTRB(
  AppSpacing.cardPadding,
  // **`kTerminalGapAbove`, from 0.** The bar is the only element on the panel
  // that is not a `TerminalRow`, so it has no row padding of its own to inherit
  // and was landing flush against the value above it — `BAT_FLOW`'s figure sat
  // one hairline away from a red gauge that belongs to the row *below* it. On a
  // panel that draws its depth from hairlines, touching is the same as joined.
  kTerminalGapAbove,
  AppSpacing.cardPadding,
  AppSpacing.md,
);

/// A full-width hairline inside the panel.
///
/// **A named widget rather than a repeated `Divider`, because the insets are
/// the design.** A rule that runs edge to edge reads as a border between two
/// regions; the same rule inset to the panel's content padding reads as a
/// *row separator*, which is what it is. Three call sites copying
/// `Divider(indent: 16)` is how they drift apart.
class TerminalRule extends StatelessWidget {
  const TerminalRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
      child: Divider(),
    );
  }
}

/// Formats a double for a panel cell.
///
/// **Right-trimmed, and that is the whole point.** `sensor.ageLabel` and the
/// power figures come out of `toStringAsFixed` with a trailing run of zeros —
/// `81.0 W`, `12.00 A` — which in a tabular monospace column reads as false
/// precision. The device reported a whole number; the display says so.
///
/// Never returns `''` for a null input: the caller decides what an absent
/// reading looks like, and this only formats the ones that exist.
String slotNumber(double? value, {int decimals = 1}) {
  if (value == null || value.isNaN || value.isInfinite) return '--';
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
