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

  /// The ThingsBoard telemetry key to read.
  final String key;

  final String label;
  final String unit;
  final IconData icon;

  /// The key this card is judged against in the alarm rules, or null when the
  /// reading is displayed but not monitored.
  ///
  /// Null is the established precedent for an informational reading: the value is
  /// shown, there is no verdict and no range caption, because inventing a limit
  /// the user never set would be worse than showing nothing. `temp_ds18b20`,
  /// `lux` and `water_level_percent` are the current examples — displayed,
  /// never graded.
  final String? metric;

  /// Decimal places for the printed value.
  ///
  /// Per spec, not a single global default. pH is logarithmic, so 6.240476 and
  /// 6.24 are the same reading and 6.2 throws away information the user has; a
  /// turbidity sensor good to a few percent must not print 2395.53, which reads
  /// as authority it does not have. A fixed one decimal did both wrong at once.
  final int decimals;
}

/// How a spec's configured range is captioned under its value.
///
/// Returned by the caller rather than looked up here, so a metric the widget has
/// never heard of is a plain unmonitored card instead of silently falling through
/// a switch to a fabricated range.
typedef LimitLabelBuilder = String? Function(MetricSpec spec);

/// A titled grid of reading cards, used for the greenhouse sensors and for the
/// fish tank.
///
/// Every card that has a limit shows whether the reading is inside it, and the
/// grid is closed with a single verdict. Before this, the five numbers were shown
/// with no reference to the limits the user had just configured, so a reading of
/// 38 °C looked the same as a healthy one until the alert banner appeared
/// somewhere else on the screen.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.title,
    required this.specs,
    required this.values,
    required this.theme,
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

  /// The appearance to paint, as an `AppTheme`.
  ///
  /// Threaded down to every card in the grid so the whole block agrees with the
  /// page it sits on. Each card's `AppCard` draws the `raised` pair and its
  /// accent comes from `metricColor`, and both of those are per-theme with a
  /// separately derived Dracula answer; the verdicts and captions on top pass
  /// `theme.isDark`, because a text or status colour is shared by the two dark
  /// presets.
  final AppTheme theme;

  final Color seedColor;

  /// Cards per row. Three suits the five greenhouse readings as 3 + 2; the fish
  /// page passes two so four readings land as a clean 2 + 2 rather than 3 + 1 with
  /// one card stranded beside a gap.
  final int columns;

  /// The user's current limits, used to grade each reading.
  final AlarmThresholds? thresholds;

  /// Used to decide whether the grid as a whole can be trusted.
  final int staleMinutes;

  final DateTime? lastUpdate;

  final LimitLabelBuilder? limitLabelFor;

  /// Whether to show status colors for out-of-range readings. When false, the
  /// grid shows only the accent-tinted hairline and ordinary text, but alarms are
  /// still evaluated normally.
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: faintColor(theme.isDark),
              ),
            ),
            const Spacer(),
            // Only speaks up when there is something wrong. The green "Semua
            // normal" state with a tick was the other half of the checklist
            // effect: readings in range is the boring case, and asserting it
            // permanently put a permanent badge on the screen.
            if (verdicts.isStale)
              _Tag(
                text: 'Stale data',
                color: statusWarn(theme.isDark),
              )
            // The breach tag follows showGridColors as well: with alerts off the
            // user has said these limits are not being monitored, and a red "out
            // of range" badge would assert the very condition they switched off.
            // Stale is different and stays, because a dead sensor is a fact
            // about the data, not about a configured limit.
            else if (breached > 0 && showGridColors)
              _Tag(
                text: '$breached out of range',
                color: statusBad(theme.isDark),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Data-driven rows, because the previous version indexed `_envSpecs[0..4]`
        // by hand in a fixed 3 + 2 shape. A fourth and fifth spec would have
        // needed the layout rewritten, and a forgotten index renders nothing at all
        // instead of failing.
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
                    theme: theme,
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
    // A stale reading says nothing about the current climate, so the grid must
    // not claim everything is fine while the sensor is dead.
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
  /// The tag's colour is chosen by the caller from `statusWarn` / `statusBad`,
  /// both of which take a brightness. It used to also take an unused `isDark`,
  /// which is what a `status*` call looks like before anyone checks whether the
  /// widget reads it — it does not, so the parameter is gone rather than
  /// converted.
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
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
    required this.theme,
    required this.seedColor,
    required this.showGridColors,
  });

  final MetricSpec spec;
  final double? value;

  /// True when inside the range, false when outside, null when unjudgeable.
  final bool? verdict;

  /// The configured range, shown so a number has something to be read against.
  final String? limit;

  /// See [MetricGrid.theme].
  ///
  /// This card's `AppCard` draws the `raised` pair and its icon takes
  /// `metricColor`, so both are per-theme. Everything printed on it — the label,
  /// the unit, the range caption and the breach colour — is text and passes
  /// `theme.isDark`.
  final AppTheme theme;

  final Color seedColor;
  final bool showGridColors;

  @override
  Widget build(BuildContext context) {
    final faint = faintColor(theme.isDark);
    final accent = metricColor(
      seedColor: seedColor,
      index: 3,
      theme: theme,
    );
    // Only a breach is coloured. A reading inside its range keeps the card's own
    // accent-tinted outline and an ordinary caption, because "fine" is the boring
    // case and green is not information: it is a second colour system sitting next
    // to the theme, and in an amber or cyan theme the page filled up with green
    // text the user had never chosen. The grid's verdict at the top already counts
    // what is out of range.
    final breached = verdict == false;
    final status = (breached && showGridColors) ? statusBad(theme.isDark) : null;

    return AppCard(
      theme: theme,
      padding: const EdgeInsets.all(8),
      // The breach outline is gone, and deliberately. It was the third signal on
      // one card — the coloured caption below and the grid's "N out of range" tag
      // were already saying the same thing — and AGENTS.md is explicit that
      // signalling one state three ways reads as a checklist rather than a
      // reading. Soft UI carries depth in a shadow pair, and a surface that needs
      // a red edge to explain itself is not the design language this file
      // migrated to. `AppCard` has no border override, and inventing one to keep
      // the third channel would have been the wrong repair.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 14, color: accent),
              const SizedBox(width: 4),
              // No tick or warning glyph. Out-of-range used to be signalled three
              // ways on one card — a tick, a warning triangle, and a red border —
              // which turned a reading into a checklist item. Two channels are
              // the right number, and they are the coloured range caption below
              // and the grid's own "N out of range" verdict; the caption stays
              // visible in peripheral vision the way an icon did not.
              Expanded(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // The unit is skipped entirely when empty, so pH reads as a bare
              // number rather than "6.24 " with a trailing space.
              if (spec.unit.isEmpty)
                Text(
                  value == null ? '--' : value!.toStringAsFixed(spec.decimals),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: appPrimaryText(theme.isDark),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    value == null ? '--' : value!.toStringAsFixed(spec.decimals),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: appPrimaryText(theme.isDark),
                    ),
                  ),
                ),
              if (spec.unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(spec.unit, style: TextStyle(fontSize: 11, color: faint)),
              ],
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: 2),
            Text(
              limit!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: status ?? faint),
            ),
          ],
        ],
      ),
    );
  }
}
