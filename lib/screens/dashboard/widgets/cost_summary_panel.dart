import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import '../utils/energy_helpers.dart';
import 'terminal_panel.dart';

/// What the array was worth and what the house cost, over the same window the
/// ENERGY section above it reports.
///
/// ## Why this is a panel and not a fifth card on the existing one
///
/// Because the numbers would lie. `SOLAR_GEN_24H` and `LOAD_USED` are kWh, and
/// a kWh is not money until the user supplies a price for it — so putting
/// rupiah figures under the ENERGY heading would put two quantities in one
/// block with different units and no way to tell which is which. A separate
/// panel can say, in its own header, that it is money, and can stay entirely
/// absent when the user has not told the app what a kWh costs.
///
/// ## Everything here is optional, and the absences are not errors
///
/// [tariffPerKwh] and [installedWp] are null until the user types them. A null
/// hides the money rows; a null nameplate hides the performance rows. Neither
/// prints a dash, because a dash reads as "we looked and found nothing" and
/// the truth is "you have not told us".
///
/// ## The balance is never coloured
///
/// The app's rule is that a status colour means a condition, and it is a rule
/// this panel could most easily break by accident: a negative balance means the
/// house drew more than the array made, which is what happens on every night
/// of normal operation and during any heavy cloud. Painting that red would put
/// a permanent alarm on the dashboard for a condition nobody can act on. The
/// sign is carried by the minus sign, which is the one piece of that information
/// the reader cannot miss anyway.
class CostSummaryPanel extends StatelessWidget {
  const CostSummaryPanel({
    super.key,
    required this.solarKwh,
    required this.loadKwh,
    required this.periodLabel,
    required this.hours,
    this.tariffPerKwh,
    this.installedWp,
  });

  /// Energy produced over the window, kWh.
  final double solarKwh;

  /// Energy drawn over the window, kWh.
  final double loadKwh;

  /// What this window is, in the app's own words — `Last 24 hours`, `Last 7 days`.
  final String periodLabel;

  /// How many hours the window actually covers.
  ///
  /// **The denominator of the capacity factor, so it has to be the window's real
  /// length.** Using a flat 24 for a day that started at midnight would divide
  /// by hours that have not happened yet and report an array as underperforming
  /// before noon.
  final double hours;

  final double? tariffPerKwh;
  final double? installedWp;

  MoneyPeriod? get _money => moneyForPeriod(
    solarKwh: solarKwh,
    loadKwh: loadKwh,
    tariffPerKwh: tariffPerKwh,
  );

  PvPerformance? get _performance =>
      pvPerformance(solarKwh: solarKwh, installedWp: installedWp, hours: hours);

  @override
  Widget build(BuildContext context) {
    final money = _money;
    final performance = _performance;
    // **Nothing to say.** Not a dash, not a zero — the card does not exist
    // until one of the two optional numbers has been entered, which is the
    // same rule the Overview panel follows for the alarms tag.
    if (money == null && performance == null) return const SizedBox.shrink();

    return TerminalPanel(
      semanticLabel: 'Cost and performance',
      header: _Header(periodLabel: periodLabel),
      children: [
        if (money != null) ...[
          const _Section('VALUE'),
          TerminalRow(
            label: 'SOLAR_VALUE',
            value: rupiah(money.solarValue),
            divider: false,
          ),
          TerminalRow(
            label: 'LOAD_COST',
            value: rupiah(money.loadCost),
            divider: false,
          ),
          // **Neutral, per the file doc.** The balance is a difference, not a
          // condition, and it is negative on every ordinary night.
          TerminalRow(
            label: 'BALANCE',
            value: rupiah(money.balance),
            divider: false,
          ),
        ],
        if (performance != null) ...[
          const TerminalRule(),
          const _Section('PERFORMANCE'),
          TerminalRow(
            label: 'FULL_LOAD',
            value: performance.fullLoadHours.toStringAsFixed(2),
            unit: 'h',
            divider: false,
          ),
          TerminalRow(
            // **As a percentage of a nameplate, which is what it means.**
            // "Capacity factor" printed as 0.183 is a number nobody reads; the
            // same number as 18% is the thing a person compares against a
            // datasheet.
            label: 'CAP_FACTOR',
            value: (performance.capacityFactor * 100).toStringAsFixed(1),
            unit: '%',
            divider: false,
          ),
          TerminalRow(
            // **The nameplate is echoed back.** It is the only number here the
            // app cannot verify, and every other row on this panel is that
            // number divided by something. Showing it means a mis-keyed 4500
            // instead of 450 is visible on the card rather than only in
            // Settings.
            label: 'RATED_WP',
            value: installedWp!.toStringAsFixed(0),
            unit: 'Wp',
            divider: false,
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.md,
        AppSpacing.cardPadding,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            periodLabel.toUpperCase(),
            style: AppType.slotKey.copyWith(
              color: AppSurfaces.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'COST & PERFORMANCE',
            style: AppType.slotMicro.copyWith(color: AppPalette.error),
          ),
        ],
      ),
    );
  }
}

/// The same ruled heading `OverviewPanel` uses, so the two panels share one
/// voice rather than growing a second style for the same idea.
class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.md,
        AppSpacing.cardPadding,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppType.slotMicro.copyWith(color: AppPalette.error),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}