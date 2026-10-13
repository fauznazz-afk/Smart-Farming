/// What came IN and what went OUT over the selected date.
///
/// ## Why this exists
///
/// The Overview answers one question — *what is the system doing right now* —
/// and the date strip directly above it changes nothing on the page when you
/// touch it. That is the gap this closes. Tapping yesterday and still reading
/// today's live hero figure is the sort of thing a user does not report as a
/// bug; they just conclude the date strip is decorative.
///
/// ## Why it is its own panel rather than rows inside `OverviewPanel`
///
/// The two panels are about different times. `OverviewPanel` is the present
/// tense and its hero is a live watt figure; everything here is an integral or
/// an extremum over a window. Mixing them would mean the page has a section
/// that is instantaneous and a section that is not, with no marker saying
/// which, and the ENERGY block already sits between them saying `24H` while
/// being fed a *rolling* 24 h that ignores the selected date entirely.
///
/// ## Why it only appears for a past selection
///
/// For today, `OverviewPanel` already reports generation, load and net-energy
/// figures, one section and one screen above. A second panel restating them
/// would be the same numbers twice with no second reading of them — which is the
/// checklist failure `AGENTS.md` records for the old environment cards, not a
/// feature. For a past date the page reports nothing at all, so the panel is
/// the only thing on screen that answers the question.
///
/// ## Why a period with no history says so
///
/// `--` is not a formatting choice here, it is the feature. See
/// `lib/utils/date_summary_stats.dart`: the power history is a rolling fourteen
/// day window and the picker reaches back ninety, so "nothing recorded" is a
/// state the user hits routinely, and a `0.00 kWh` printed for it would be a
/// confident false statement about the array.
library;

import 'package:flutter/material.dart';

import '../../../utils/date_summary_stats.dart';
import '../utils/design_tokens.dart';
import 'terminal_panel.dart';

/// One reading summarised over the period, resolved before it reaches the panel.
///
/// **A record of plain numbers for the same reason `OverviewReadings` is one.**
/// The screen owns the history maps and the thresholds; this widget owns the
/// table. Resolving here is what lets the whole panel be pumped in a widget test
/// from literals.
class DateSummaryStat {
  const DateSummaryStat({
    required this.label,
    required this.stats,
    this.unit = '',
    this.decimals = 1,
    this.limitLabel,
    this.breached = false,
  });

  /// The slot name — `AMBIENT_T`, `PH`. Taken from the same `MetricSpec` the
  /// metric grids use, so a renamed label cannot leave this panel behind.
  final String label;

  final PeriodStats stats;

  final String unit;
  final int decimals;

  /// The configured band, as `MetricGrid` captions it.
  final String? limitLabel;

  /// Whether the period left [limitLabel]'s band at any point.
  final bool breached;

  bool get hasData => stats.hasData;

  /// `min / avg / max`, or `--` when the period holds no samples.
  ///
  /// **The separator is a slash with spaces, and it is not decoration.** Three
  /// numbers in one cell is ambiguous the moment someone reads it back, and the
  /// section heading names the order for exactly this row.
  String get value {
    if (!hasData) return '--';
    return '${slotNumber(stats.minimum, decimals: decimals)}'
        ' / ${slotNumber(stats.average, decimals: decimals)}'
        ' / ${slotNumber(stats.maximum, decimals: decimals)}';
  }
}

/// The period summary. One [TerminalPanel], three groups.
class DateSummaryPanel extends StatelessWidget {
  const DateSummaryPanel({
    super.key,
    required this.periodLabel,
    this.solarKwh,
    this.loadKwh,
    this.environment = const [],
    this.fish = const [],
  });

  /// What is being summarised, from `describeHistoryRange` — a date or a range.
  final String periodLabel;

  /// Energy the array delivered over the period, and the house drew.
  ///
  /// Null when the period is outside the fetched history window. See
  /// `energyForCoveredPeriod` for why a partial window reports nothing.
  final double? solarKwh;
  final double? loadKwh;

  final List<DateSummaryStat> environment;
  final List<DateSummaryStat> fish;

  /// Generation minus load, or null when either side is unknown.
  ///
  /// **The net, and it may be negative, which is the whole reason it is here.**
  /// A grower wants to know whether the day paid for itself, and that is a
  /// subtraction of two integrals, not either of them alone. The alternative
  /// group — generation here, load there, arithmetic left to the reader — is
  /// the reason the request was made.
  ///
  /// Not clamped, unlike the hero's PV_OUT. A negative day is a real and
  /// important answer (overcast week, battery carried the house), and clamping it
  /// to zero would render that day indistinguishable from a day the array did
  /// nothing.
  double? get netKwh =>
      (solarKwh == null || loadKwh == null) ? null : solarKwh! - loadKwh!;

  @override
  Widget build(BuildContext context) {
    final all = [...environment, ...fish];
    final breached = all.where((stat) => stat.breached).length;
    // "Nothing at all" is a distinct state from "some things missing". One row
    // saying so is more useful than three groups of `--`, and a page of dashes
    // is a page the reader learns to scroll past.
    final nothingRecorded =
        solarKwh == null &&
        loadKwh == null &&
        all.every((stat) => !stat.hasData);

    return TerminalPanel(
      semanticLabel: 'Period summary',
      header: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                // Uppercased because every heading on this style is; the date
                // picker shows the same digits in sentence case just above.
                periodLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.slotKey.copyWith(color: AppPalette.error),
              ),
            ),
            const Spacer(),
            // **One tag, and it is the breaches.** `MetricGrid` puts the breach
            // count here for the same reason, and for the same reason there is
            // no "all within range" counterpart: a green badge on a healthy day
            // is a verdict on data the reader did not ask about, occupying the
            // space a real excursion needs.
            if (breached > 0)
              TerminalTag(text: '$breached out of range', alert: true),
          ],
        ),
      ),
      children: [
        if (nothingRecorded)
          const TerminalRow(
            label: 'NO_DATA',
            value: 'Nothing recorded',
            divider: false,
          )
        else ...[
          _heading('POWER'),
          TerminalRow(
            label: 'SOLAR_IN',
            value: slotNumber(solarKwh, decimals: 2),
            unit: 'kWh',
            divider: false,
          ),
          TerminalRow(
            label: 'LOAD_OUT',
            value: slotNumber(loadKwh, decimals: 2),
            unit: 'kWh',
            divider: false,
          ),
          TerminalRow(
            label: 'NET',
            value: slotNumber(netKwh, decimals: 2),
            unit: 'kWh',
            divider: false,
          ),
          if (environment.isNotEmpty) ...[
            const TerminalRule(),
            _heading('ENVIRONMENT  MIN / AVG / MAX'),
            for (final stat in environment) _statRow(stat),
          ],
          if (fish.isNotEmpty) ...[
            const TerminalRule(),
            _heading('FISH  MIN / AVG / MAX'),
            for (final stat in fish) _statRow(stat),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  Widget _statRow(DateSummaryStat stat) {
    return TerminalRow(
      label: stat.label,
      // **One size for every min / avg / max triple, and it is named rather than
      // inherited.** `TerminalRow` puts the value in a `FittedBox(scaleDown)`,
      // so the drawn size was whatever was left over after the slot name and the
      // limit caption. On this panel that produced one size for the short
      // triples and a smaller, different size for each long one — the same
      // widget, the same column, a font size that tracked string length. The
      // user read it as the Overview being inconsistent when looking at an older
      // date, which is exactly what it was.
      //
      // `slotValueSmall` is the token the hero's own secondary figures use, so
      // the summary's triples sit on the same scale as the rest of the panel's
      // small figures. The `FittedBox` stays as the safety net for the longest
      // triple, but it now has to shrink past a size every row shares.
      valueStyle: AppType.slotValueSmall,
      value: stat.value,
      unit: stat.unit.isEmpty ? null : stat.unit,
      // Red is the panel's only severity colour and it means exactly one thing
      // here: the period left the band on a row that has a band. The limit
      // caption sits between the slot and the figures so the reader can see
      // what was crossed without leaving the row.
      alert: stat.breached,
      trailing: stat.limitLabel == null
          ? null
          : Text(
              stat.limitLabel!,
              // **`maxLines: 1`, and without it the caption wrapped to four
              // lines.** `TerminalRow` gives `trailing` a `Flexible` of its own
              // so it can yield space to the figure, and a loose constraint is
              // an invitation to a `Text` to wrap. Measured at a 2.0 system font
              // — a real accessibility setting, not a synthetic one — `15-50`
              // laid out 120 dp tall, which is four lines of a caption that is
              // meant to be five characters on one.
              //
              // Ellipsis rather than the default `clip`, so a caption that
              // genuinely cannot fit says so instead of losing its right edge
              // silently.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.slotMicro.copyWith(
                color: AppSurfaces.onSurfaceVariant,
              ),
            ),
      divider: false,
    );
  }

  /// A group heading. Private rather than shared because `OverviewPanel` has the
  /// same private helper and that file is owned by a different change; promoting
  /// it would have meant an edit to two files that are being written to
  /// concurrently, for twenty lines of padding and a `Text`.
  static Widget _heading(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.sm,
        AppSpacing.cardPadding,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: AppType.slotMicro.copyWith(color: AppPalette.error),
      ),
    );
  }
}
