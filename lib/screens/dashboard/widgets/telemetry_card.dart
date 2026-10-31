import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/app_motion.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

// Gradient dark-mode skin for the detail-page cards, local to this file so the
// shared token layer stays untouched.
const Color _glassFill = Color(0x0FFFFFFF);
const Color _glassBorder = Color(0x1FFFFFFF);
const Color _valueGradientStart = Color(0xFF00D97E);
const Color _valueGradientEnd = Color(0xFF00D97E);
const double _glassRadius = 26;

/// A cyan-to-violet wash over a value figure. `BlendMode.srcIn` keeps the
/// glyphs, so this paints the type rather than a box behind it.
class _GradientValue extends StatelessWidget {
  const _GradientValue({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_valueGradientStart, _valueGradientEnd],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Icon + title row used at the top of each detail page.
class GlassPageHeader extends StatelessWidget {
  const GlassPageHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // **A wash bed, not a frame.** This used to draw the brief's
        // `categoricalBorder` — a 1px outline of the category's own hue — all
        // the way round the circle, on top of the wash. The brief never combines
        // the two: a 20%-alpha tint behind a full-strength foreground *is* the
        // categorical chip, and a second, full-strength edge around it is the
        // card-frame habit this style replaced. A coloured border is a drawn
        // edge, and hue is spoken for — the hue belongs to the glyph inside.
        //
        // **A white wash, not [AppBorders.categoricalWash], and this is the same
        // correction `AppGlass.fillSoft` documents.** The wash used to be the
        // accent at 20%, measured over a *card*. This header is not over a card —
        // all five call sites in `dashboard_screen.dart` put it straight onto
        // `AppBackground` — and a tint of the same hue as the glyph inside it
        // leaves the glyph and its own chip at one value. A wash has to lift the
        // chip clear of the page, which is what a white wash does and what
        // re-tinting a saturated one never can.
        //
        // The ink follows the wash, for the reason `AppGlass.pageGlassInk`
        // exists: dark ink on a white wash. `accent` is unread here now, which
        // costs nothing — `categoryColor` resolves to one value for all five
        // categories, so the chip never said which one this was.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppGlass.fillSoft,
          ),
          child: Icon(icon, size: 18, color: AppGlass.pageGlassInk),
        ),
        const SizedBox(width: 10),
        // `headlineLg`, not `numeralLg`: this is a title, and the brief's
        // `headline-lg` is exactly "a card title inside a list row" at the same
        // 24sp/900 the numeral style uses. Reaching for the numeral style for a
        // word is what happens when there is only one 24sp Black in the file —
        // the two now exist separately and should be used for what they mean.
        //
        // **Page ink, not card ink, and the word "card" in the sentence above is
        // the historical one.** This header is not inside a card: all five call
        // sites put it directly on the page. `AppSurfaces.onSurface` is the token
        // for content on a card and is wrong here — the page has its own ink
        // ramp, and this header is on the page.
        Text(
          title,
          style: AppType.headlineLg.copyWith(color: AppGlass.pageInkStrong),
        ),
      ],
    );
  }
}

/// Vertical list of key/value metrics for a single device, with a stale
/// telemetry notice when the device has not reported recently.
class TelemetryCard extends StatelessWidget {
  const TelemetryCard({
    super.key,
    required this.data,
    required this.metrics,
    required this.staleMinutes,
  });

  final DeviceTelemetry? data;
  final List<MetricDef> metrics;
  final int staleMinutes;

  @override
  Widget build(BuildContext context) {
    final stale = data?.isStale(minutes: staleMinutes) ?? true;
    return Container(
      decoration: BoxDecoration(
        color: _glassFill,
        borderRadius: BorderRadius.circular(_glassRadius),
        border: Border.all(color: _glassBorder),
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            if (stale) _StaleNotice(ageLabel: data?.ageLabel),
            for (var index = 0; index < metrics.length; index++) ...[
              _MetricRow(
                metric: metrics[index],
                value: data?.latestValues[metrics[index].key],
                // **The accent, and it was the category hue.** The three call sites
                // in `dashboard_screen.dart` pass the PV keys, the AC keys and the
                // battery keys respectively — so every row in a given card is
                // *already* one category, and the colour could not be telling the
                // reader anything the card's own header does not already say. What
                // it was telling them is which of five hues the dashboard
                // currently believes the app is. Rows, icons and a 2px edge are
                // chrome and headings, so they take the one accent.
                accent: AppPalette.accent,
                // **The 2px categorical bottom border, and it replaces the
                // [AppDivider] this row used to be separated by.** The brief's stat
                // tile is "card + leading icon in a categorical colour + numeral
                // value + micro unit, with a 2px categorical bottom border", and a
                // divider-separated list of readings is a stack of those tiles as
                // surely as the 3-up grid is. A neutral hairline between the rows
                // described the *gap*; the categorical edge describes the *metric*,
                // which is the thing the brief wants colour-coded.
                //
                // The last row carries none: the card already has its own hairline
                // there, and two edges 4px apart read as a mistake rather than as a
                // design.
                //
                // Every reading in this card is one category — the three call sites
                // in `dashboard_screen.dart` pass the PV keys, the AC keys and the
                // battery keys respectively — so the hue used to be constant
                // *within* a card and only ever varied *between* cards, which is
                // decoration and not information.
                beneath: index < metrics.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.ageLabel});

  final String? ageLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 15, color: faintColor),
          const SizedBox(width: 6),
          Text(
            ageLabel ?? 'No update received',
            style: AppType.labelMicro.copyWith(color: faintColor),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.value,
    required this.accent,
    this.beneath = false,
  });

  final MetricDef metric;
  final double? value;
  final Color accent;

  /// Draw the brief's 2px categorical bottom border under this row.
  ///
  /// Named for what it draws rather than for where it sits, because the false
  /// case is not "the last row" — it is "nothing separates this row from the
  /// card's own edge", and a future caller with a different layout should not
  /// have to know that.
  final bool beneath;

  @override
  Widget build(BuildContext context) {
    final unit = metric.unit;
    final decimals = metric.decimals;
    final number = value?.toStringAsFixed(decimals);
    // **The label and the figure are the same string.** The label is the
    // reading the figure is heading for, so it is built from the same number
    // rather than from a second formatting of the value.
    final displayValue = number == null
        ? (unit.isEmpty ? '--' : '-- $unit')
        : (unit.isEmpty ? number : '$number $unit');
    return MergeSemantics(
      child: Semantics(
        label: '${metric.label}: $displayValue',
        child: Container(
          decoration: beneath
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: accent, width: 2)),
                )
              : null,
          child: Padding(
            // 14, from 13, so the row clears 48 dp with the 20 sp figure it
            // carries. 13 landed at 46 on the battery page's `%` row.
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(metric.icon, size: 18, color: accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    metric.label,
                    // The card's own secondary ink, not the primary: a row
                    // label is the muted half and the figure is the reading.
                    // Primary ink on both made every row a wall of white.
                    style: AppType.labelUppercase.copyWith(
                      color: AppGlass.glassInkFaint,
                    ),
                  ),
                ),
                // **The figure counts to its new value instead of jumping to
                // it.** A reading that moves from 1834 to 1841 every ten
                // seconds is a flicker, and a flicker reads as an error; a
                // figure that counts is motion. The tween lives inside the
                // widget, so the poll's rebuild does not reach the page above
                // it, and the figure starts at the value it was given — a card
                // that opens shows the reading, not a count-up from zero.
                _GradientValue(
                  child: TweenedFigure(
                    text: number ?? '--',
                    builder: (context, text) => Text(
                      unit.isEmpty ? text : '$text $unit',
                      style: AppType.numeralLg.copyWith(color: appPrimaryText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
