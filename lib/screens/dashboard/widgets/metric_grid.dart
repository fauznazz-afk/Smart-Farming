import 'package:flutter/material.dart';

import '../../../utils/alarm_rules.dart';
import '../../../widgets/liquid_glass.dart'
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
    required this.seedColor,
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
  final Color seedColor;
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
            Text(
              title,
              style: AppType.labelUppercase.copyWith(color: faintColor),
            ),
            const Spacer(),
            if (verdicts.isStale)
              _Tag(
                text: 'Stale data',
                color: statusWarn,
              )
            else if (breached > 0 && showGridColors)
              _Tag(
                text: '$breached out of range',
                color: statusBad,
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
                    seedColor: seedColor,
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
        result[metric] = (min != null && value < min) || (max != null && value > max);
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
      style: AppType.labelMicro.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.spec,
    required this.value,
    required this.verdict,
    required this.limit,
    required this.seedColor,
    required this.showGridColors,
  });

  final MetricSpec spec;
  final double? value;
  final bool? verdict;
  final String? limit;
  final Color seedColor;
  final bool showGridColors;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor;
    final accent = categoryColorForKey(spec.key) ?? AppPalette.primary;
    final breached = verdict == false;
    final status = (breached && showGridColors) ? statusBad : null;

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
                      value == null ? '--' : value!.toStringAsFixed(spec.decimals),
                      maxLines: 1,
                      style: AppType.numeralLg.copyWith(color: appPrimaryText),
                    ),
                  ),
                ),
              if (spec.unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(spec.unit, style: AppType.labelMicro.copyWith(color: faint)),
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
        ],
      ),
    );
  }
}