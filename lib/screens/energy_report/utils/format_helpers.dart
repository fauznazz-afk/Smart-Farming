import '../../../utils/energy_comparison.dart' show kMeaningfulEnergyKwh;

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

/// Below this, two periods are both too small for a ratio to mean anything.
///
/// The threshold is [kMeaningfulEnergyKwh], shared with
/// `EnergySummaryCard._comparison` in `lib/widgets/energy_summary_card.dart`
/// rather than duplicated in it. The two were separate literals, and the report's
/// copy was the one that had never been fixed while the card's had, which is
/// precisely how a dashboard and a report end up contradicting each other about
/// the same two numbers.
const double _meaningfulPrevious = kMeaningfulEnergyKwh;

/// Formats a kWh figure the way the card does — two decimals, the same
/// precision the comparison threshold is reasoned about in.
String _formatEnergy(double value) => value.toStringAsFixed(2);

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
  if (previous == null) return 'No comparison data yet';
  if (previous <= 0) return 'Previous period: 0 kWh';
  if (previous < _meaningfulPrevious) {
    if (current < _meaningfulPrevious) {
      return current <= 0
          ? 'No production'
          : '${_formatEnergy(current)} kWh, none last period';
    }
    return 'Nothing to compare yet';
  }
  final change = ((current - previous) / previous * 100).round();
  if (change == 0) return 'Same as the previous period';
  return '${change > 0 ? '+' : ''}$change% from the previous period';
}