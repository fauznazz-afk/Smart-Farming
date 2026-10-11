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
/// ## Monochrome, and what that costs
///
/// The rest of the app is categorical: PV lime, AC blue, Battery violet, and so
/// on, so a hue means a category of data. **This panel is monochrome on purpose
/// and that is a real divergence, not an oversight.** A terminal panel gets its
/// hierarchy from weight, case, tracking and position, and a categorical hue
/// sitting in every row would flatten exactly the structure the panel is
/// building. Hue on this page is reserved for one thing: **a value that is out
/// of bounds**, drawn in [AppPalette.error]. Red here means *wrong*, not
/// *battery*.
///
/// The other tabs keep their category hues. This is one page, not a new app.
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
  const TerminalPanel({super.key, required this.children, this.header});

  /// The panel's first row: a title, a station-style id, and any status.
  final Widget? header;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      semanticLabel: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            header!,
            const Divider(),
          ],
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
    this.trailing,
    this.onTap,
  });

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
  /// **A row is 43 dp tall, which clears the 48 dp minimum on its own** — unlike
  /// the meter's 6 dp bar, which is why that one needed its captions inside the
  /// hit region and this one does not.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueColor = alert ? AppPalette.error : AppSurfaces.onSurface;
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 11,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (tint != null) ...[
            _Dot(color: tint!),
            const SizedBox(width: AppSpacing.sm),
          ],
          // **`FittedBox`, because the vocabulary has no short words.** `Discharging` and
          // `Heavily overcast` are the values this panel actually renders, and on
          // a 411 dp phone at a 2.0 system font both overflow the value column —
          // `Discharging` lost its last two glyphs and `Heavily overcast` ran off
          // the right edge of the card. A panel whose own labels get clipped is
          // the one thing it must not do.
          //
          // `scaleDown` only shrinks; a value that already fits is untouched, so
          // this costs the short values nothing.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                label,
                maxLines: 1,
                style: AppType.slotKey.copyWith(
                  color: AppSurfaces.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (trailing != null) ...[trailing!, const SizedBox(width: AppSpacing.md)],
          // **The value is the one thing that must never be shortened**, so it is
          // outside the `FittedBox` and the *unit* is the one that yields when
          // the row is tight. `kW` becoming `k` would be wrong; `W` becoming
          // nothing would not.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: AppType.slotValue.copyWith(color: valueColor),
              ),
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              unit!,
              style: AppType.slotUnit.copyWith(color: AppSurfaces.onSurfaceVariant),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
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

/// The panel's hero: one figure, enormous, with a status tag above it.
///
/// **The figure is the page.** Everything else in the panel is supporting data,
/// and this is the one number that answers "what is happening" without a
/// calculation. It is drawn at [AppType.heroFigure] rather than reusing
/// [AppType.displayLg] because the tracking on the display scale is tuned for a
/// short headline and a live figure with changing digit count needs the tighter,
/// tabular setting — a value that changes width on every poll makes the whole
/// panel twitch.
class TerminalHero extends StatelessWidget {
  const TerminalHero({
    super.key,
    required this.figure,
    required this.unit,
    required this.caption,
    this.secondary = const [],
  });

  /// The main number, as the sensor reported it.
  final String figure;

  /// Its unit.
  final String unit;

  /// The line under the figure — what the figure *is*.
  final String caption;

  /// Right-hand stats, as `(key, value)` pairs. Rendered in the panel's own
  /// two-column key/value rhythm rather than as prose.
  final List<(String, String)> secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption.toUpperCase(),
                  style: AppType.slotKey.copyWith(
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      figure,
                      style: AppType.heroFigure.copyWith(
                        color: AppSurfaces.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      unit,
                      style: AppType.heroUnit.copyWith(
                        color: AppSurfaces.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (secondary.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (key, value) in secondary)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          key.toUpperCase(),
                          style: AppType.slotMicro.copyWith(
                            color: AppSurfaces.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          value,
                          style: AppType.slotValueSmall.copyWith(
                            color: AppSurfaces.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
class TerminalMeter extends StatelessWidget {
  const TerminalMeter({
    super.key,
    required this.fraction,
    this.alert = false,
    this.leftCaption,
    this.rightCaption,
    this.onTap,
  });

  /// The filled proportion, clamped by the caller.
  final double fraction;

  final bool alert;
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
  Widget build(BuildContext context) {
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final fill = alert ? AppPalette.error : AppSurfaces.onSurface;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // **`Positioned.fill` on the FILL, not just on the track.** This is the same
        // bug the sky card's bar had in 1.9.1, in the same shape: a
        // `FractionallySizedBox` in a `Stack` is a *non-positioned* child, so the
        // stack sizes itself to it and hands it loose constraints — with nothing
        // to scale against, `widthFactor` has no width to take a fraction *of*.
        // A 95% reading drew an empty track, which is the one number on the
        // panel a reader would act on directly.
        //
        // Positioning it means the track's width is established first and the
        // fill is then resolved against it. `Align(alignment: centerLeft)` with
        // `widthFactor` keeps the fill left-anchored; a bare `FractionallySizedBox`
        // would centre it, and a 3% fill floating in the middle of a 95% track
        // reads as a rendering fault.
        SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppSurfaces.track,
                    borderRadius: AppRadius.all(AppRadius.sm),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  // **`widthFactor: 1` with the fill sized by a `FractionallySizedBox`
                  // is not the same thing as sizing the *width* of a box that fills
                  // the height.** This meter is 6 dp tall, and the fill came out
                  // **0 dp tall on the device while every widget test measured it
                  // at the right width** — so the ratio assertions passed and the
                  // bar was invisible anyway.
                  //
                  // The cause is `Align`: it passes *loose* constraints to its
                  // child, and a `DecoratedBox` with no child under loose
                  // constraints collapses to `constraints.smallest`, which is zero
                  // on an unbounded axis. A `FractionallySizedBox` with only
                  // `widthFactor` leaves the height to that child — so the height
                  // was always going to be nothing.
                  //
                  // The fix is to make the fill's *height* explicit with
                  // `heightFactor: 1` inside a `Positioned.fill`, which resolves it
                  // against the track's height rather than against a loose box.
                  child: FractionallySizedBox(
                    widthFactor: clamped,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: AppRadius.all(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (leftCaption != null || rightCaption != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Text(
                  leftCaption ?? '',
                  style: AppType.slotMicro.copyWith(
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  rightCaption ?? '',
                  style: AppType.slotMicro.copyWith(
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (onTap == null) {
      return Padding(padding: _inset, child: body);
    }
    return Padding(
      padding: _inset,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.all(AppRadius.sm),
          child: body,
        ),
      ),
    );
  }

  /// The meter's own inset, kept in one place.
  ///
  /// **Two call sites needed it and one of them was wrong.** The untappable
  /// branch padded unconditionally; the tappable branch has to pad *outside* the
  /// `InkWell` so the ripple is clipped to the meter's box rather than running
  /// under the panel's edge. Having the padding as a field is what stops the
  /// two from being written separately and disagreeing.
  static const EdgeInsets _inset = EdgeInsets.fromLTRB(
    AppSpacing.cardPadding,
    0,
    AppSpacing.cardPadding,
    AppSpacing.md,
  );
}

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