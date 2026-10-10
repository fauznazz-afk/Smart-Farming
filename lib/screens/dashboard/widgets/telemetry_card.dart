import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

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
        // The wash stays at [AppBorders.categoricalWash]'s 20% rather than the
        // 10% the brief's list-row thumbnail uses, because 20% is the only wash
        // the token file has and a hand-mixed alpha here is exactly the
        // unmeasured-value problem `color_helpers_test.dart` exists to stop.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppBorders.categoricalWash(accent),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        // `headlineLg`, not `numeralLg`: this is a title, and the brief's
        // `headline-lg` is exactly "a card title inside a list row" at the same
        // 24sp/900 the numeral style uses. Reaching for the numeral style for a
        // word is what happens when there is only one 24sp Black in the file —
        // the two now exist separately and should be used for what they mean.
        Text(title, style: AppType.headlineLg.copyWith(color: appPrimaryText)),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          if (stale) _StaleNotice(ageLabel: data?.ageLabel),
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricRow(
              metric: metrics[index],
              value: data?.latestValues[metrics[index].key],
              accent:
                  categoryColorForKey(metrics[index].key) ?? AppPalette.primary,
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
              // battery keys respectively — so the rules are one hue per card and
              // the card reads as its page's colour.
              beneath: index < metrics.length - 1,
            ),
          ],
        ],
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
    final displayValue = value == null
        ? (unit.isEmpty ? '--' : '-- $unit')
        : (unit.isEmpty
              ? value!.toStringAsFixed(decimals)
              : '${value!.toStringAsFixed(decimals)} $unit');
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
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(metric.icon, size: 19, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    metric.label,
                    style: AppType.labelUppercase.copyWith(
                      color: appPrimaryText,
                    ),
                  ),
                ),
                Text(
                  displayValue,
                  style: AppType.numeralLg.copyWith(color: appPrimaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
