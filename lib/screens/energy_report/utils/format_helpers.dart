import '../../../utils/energy_comparison.dart'
    show
        EnergyChangeKind,
        classifyEnergyChange,
        kMeaningfulEnergyKwh;

/// Formats a date as DD/MM/YYYY.
String formatDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Formats a date as HH:00.
String formatHourLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:00';

/// Formats a date as MonthName YYYY.
String formatMonthLabel(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Escapes a value for CSV output.
String escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

/// The threshold and the decision both come from `energy_comparison.dart` now,
/// not just the constant. They used to be a shared `0.1` and two private
/// four-way `if`s, with a comment here asserting that the branch order "cannot
/// disagree" — which was a claim about a convention rather than anything a
/// compiler or a test could check, and the two did disagree.

/// Generates a comparison label between current and previous values.
///
/// A percentage is only meaningful once the previous period held a real amount
/// of energy. Printing one whenever `previous > 0` meant a period that produced
/// 0.01 kWh followed by one that produced none read as "-100% from the previous
/// period": arithmetically correct, and it reads as a catastrophic loss rather
/// than as "there was nothing then".
///
/// The branch order and threshold are those of
/// `EnergySummaryCard._comparison`, so the two cannot disagree about the same
/// two numbers. Two differences are deliberate and are the only ones:
/// `previous` is nullable here, so a null — no previous period at all — answers
/// 'No comparison data yet' before any arithmetic, and the percentage and
/// no-change phrasings keep this report's existing wording, which is longer
/// than the card's because these labels are not side by side in a two-tile row.
String comparisonLabel(double current, double? previous) {
  final change = classifyEnergyChange(current, previous);
  return switch (change.kind) {
    // The two the card folds together, kept apart here because this surface has
    // a real "no previous period selected" state and the difference is worth a
    // sentence to a reader choosing between ranges.
    EnergyChangeKind.noPreviousData => 'No comparison data yet',
    EnergyChangeKind.previousWasZero => 'Previous period: 0 kWh',
    EnergyChangeKind.noProduction => 'No production',
    // **This used to be '${_formatEnergy(current)} kWh, none last period'.** The
    // decision is unchanged — both periods are under the threshold — but the
    // wording claimed an absence the report was displaying one line above. The
    // decision now comes from `classifyEnergyChange`, so the dashboard and this
    // report cannot answer this case differently again.
    EnergyChangeKind.bothNegligible =>
      'Both periods under ${kMeaningfulEnergyKwh.toStringAsFixed(1)} kWh',
    EnergyChangeKind.nothingToCompare => 'Nothing to compare yet',
    EnergyChangeKind.unchanged => 'Same as the previous period',
    EnergyChangeKind.changed =>
      '${change.percent > 0 ? '+' : ''}${change.percent}% from the previous period',
  };
}