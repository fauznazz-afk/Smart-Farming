import 'package:flutter/material.dart';

import '../../../utils/alarm_rules.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

/// One reading in a [MetricGrid]: which telemetry key, what to call it, and
/// whether anything is watching it.
class MetricSpec {
  const MetricSpec(
    this.key,
    this.label,
    this.unit,
    this.icon, {
    this.metric,
    this.decimals = 1,
  });

  final String key;
  final String label;
  final String unit;
  final IconData icon;
  final String? metric;
  final int decimals;
}

/// How a spec's configured range is captioned under its value.
typedef LimitLabelBuilder = String? Function(MetricSpec spec);

/// A titled grid of reading cards, used for the greenhouse sensors and for the
/// fish tank.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.title,
    required this.specs,
    required this.values,
    this.columns = 3,
    this.thresholds,
    this.limitLabelFor,
    this.staleMinutes = 10,
    this.lastUpdate,
    this.showGridColors = true,
  });

  final String title;
  final List<MetricSpec> specs;
  final Map<String, double>? values;
  final int columns;
  final AlarmThresholds? thresholds;
  final int staleMinutes;
  final DateTime? lastUpdate;
  final LimitLabelBuilder? limitLabelFor;
  final bool showGridColors;

  @override
  Widget build(BuildContext context) {
    final verdicts = _Verdicts.of(
      values,
      thresholds,
      lastUpdate,
      staleMinutes,
      specs,
    );
    final monitored = specs.where((spec) => spec.metric != null).toList();
    final breached = monitored
        .where((spec) => verdicts.isBreached(spec))
        .length;

    final rows = <List<MetricSpec>>[];
    for (var start = 0; start < specs.length; start += columns) {
      final end = (start + columns).clamp(0, specs.length);
      rows.add(specs.sublist(start, end));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelUppercase.copyWith(color: faintColor),
              ),
            ),
            const Spacer(),
            if (verdicts.isStale)
              Flexible(
                child: _Tag(text: 'Stale data', color: statusWarn),
              )
            else if (breached > 0 && showGridColors)
              Flexible(
                child: _Tag(text: '$breached out of range', color: statusBad),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          if (rowIndex > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < rows[rowIndex].length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    spec: rows[rowIndex][i],
                    value: values?[rows[rowIndex][i].key],
                    verdict: verdicts.verdictFor(rows[rowIndex][i]),
                    limit: limitLabelFor?.call(rows[rowIndex][i]),
                    showGridColors: showGridColors,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Whether each monitored reading sits inside its configured range.
class _Verdicts {
  const _Verdicts(this.breached, this.isStale);

  final Map<String, bool> breached;
  final bool isStale;

  static _Verdicts of(
    Map<String, double>? values,
    AlarmThresholds? thresholds,
    DateTime? lastUpdate,
    int staleMinutes,
    List<MetricSpec> specs,
  ) {
    final result = <String, bool>{};
    if (values != null && thresholds != null) {
      for (final spec in specs) {
        final metric = spec.metric;
        final value = metric == null ? null : values[metric];
        if (metric == null || value == null) continue;
        final min = thresholds.minFor(metric);
        final max = thresholds.maxFor(metric);
        result[metric] =
            (min != null && value < min) || (max != null && value > max);
      }
    }
    final stale =
        lastUpdate == null ||
        DateTime.now().difference(lastUpdate).inMinutes > staleMinutes;
    return _Verdicts(result, stale);
  }

  bool isBreached(MetricSpec spec) => verdictFor(spec) == false;

  bool? verdictFor(MetricSpec spec) {
    final metric = spec.metric;
    if (metric == null) return null;
    final out = breached[metric];
    if (out == null) return null;
    return !out;
  }
}

/// The grid's single verdict, shown only when something is wrong.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      // **No `fontWeight` override, and that is the change.** This used to set
      // `w600`, which is a weight the brief does not have: the type scale is 900
      // for what matters, 700 for the uppercase labels, 400 for the rare body
      // line. A semibold tag sat between the two and read as neither — it had the
      // tracking of a label and the presence of a numeral, so it looked like a
      // heading that had been shrunk. [AppType.labelMicro] is the brief's
      // micro-metadata style and it already carries the weight this wanted.
      style: AppType.labelMicro.copyWith(color: color),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.spec,
    required this.value,
    required this.verdict,
    required this.limit,
    required this.showGridColors,
  });

  final MetricSpec spec;
  final double? value;
  final bool? verdict;
  final String? limit;
  final bool showGridColors;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final accent = categoryColorForKey(spec.key) ?? AppPalette.primary;
    final breached = verdict == false;
    final status = (breached && showGridColors) ? statusBad : null;

    // **The brief's stat tile, and the edge is the whole recipe.**
    //
    // `card` + a leading icon in the category's own hue + a `numeral-lg` value +
    // a `label-uppercase-sm` unit, with a **2px categorical bottom border** to
    // colour-code the metric. What this replaces is the 1px categorical frame
    // drawn all the way round the tile: a frame is a *drawn edge*, and it put the
    // hue on four sides where the brief puts it on one. One coloured edge under
    // the value reads as the tile's own colour-code; four coloured edges read as
    // an outline, which is the thing this style exists to replace.
    //
    // The other three sides stay the neutral hairline, because the brief's card
    // is explicit that "a 1px border hairline always accompanies the stamped
    // shadow — the border defines the silhouette, the shadow displaces it."
    // Dropping the hairline entirely would leave the stamped shadow with nothing
    // to be the silhouette of. So the silhouette is neutral and exactly one edge
    // carries the category.
    //
    // The category edge is **not part of the Border**. A `BoxDecoration` with a
    // `borderRadius` throws at paint time if its border is not uniform —
    // "A borderRadius can only be given on borders with uniform colors" — and a
    // hairline on three sides with a 2px hue on the fourth is not. It was drawn
    // that way for one afternoon and `metric_grid_test.dart` caught it. The edge
    // is therefore a bar inside the card's content, flush to its bottom, which
    // is also what the brief's recipe is: a colour under the value, not a frame
    // around it.
    //
    // The border is always drawn, `showGridColors` or not: it is a *category*
    // marker, not a status, and switching alerts off in Settings must not
    // recolour which sensor is which. Only the breach caption below is gated.
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.labelMicro.copyWith(color: faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (spec.unit.isEmpty)
                Text(
                  value == null ? '--' : value!.toStringAsFixed(spec.decimals),
                  style: AppType.numeralLg.copyWith(color: appPrimaryText),
                )
              else
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value == null
                          ? '--'
                          : value!.toStringAsFixed(spec.decimals),
                      maxLines: 1,
                      style: AppType.numeralLg.copyWith(color: appPrimaryText),
                    ),
                  ),
                ),
              if (spec.unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  spec.unit,
                  style: AppType.labelMicro.copyWith(color: faint),
                ),
              ],
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: 2),
            Text(
              limit!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.labelMicro.copyWith(color: status ?? faint),
            ),
          ],
          // **The 2px categorical bottom edge, drawn inside the card.**
          //
          // It has to be a child rather than a `Border` side, and the reason is
          // a runtime error rather than a preference: `BoxDecoration` throws
          // "A borderRadius can only be given on borders with uniform colors"
          // the moment a hairline on three sides shares a border with a 2px hue
          // on the fourth. `test/metric_grid_test.dart` is what found it — the
          // widget built, analyzed clean, and threw on the first paint.
          //
          // The card's padding is 0 for this one child so the bar sits flush
          // with the rounded box's bottom edge, and it is drawn above the
          // card's own border rather than outside it.
          const SizedBox(height: 6),
          Container(height: 2, color: accent),
        ],
      ),
    );
  }
}
