import 'package:flutter/material.dart';

import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';
import '../services/energy_forecast_service.dart';
import '../utils/energy_comparison.dart';
import 'liquid_glass.dart';

/// Bolivian residential tariff, CRE upper residential step.
///
/// **Retired from the tile, kept for reference.** The tiles used to multiply
/// every kWh by this constant and print `≈ Bs. 10.42`, which is a money figure
/// computed from a rate the user never supplied and cannot change. The app
/// already has a tariff field (`SettingsKeys.electricityTariffPerKwh`, in
/// rupiah) and a cost panel that refuses to price anything without it; this
/// constant was a second, hidden source of truth that silently disagreed with
/// it, and on this installation it disagreed by three orders of magnitude.
///
/// The value stays declared because the doc records where it came from, and a
/// reader who finds `Bs.` in a git blame deserves the reason it left.
const double kTariffBsPerKwh = 0.84;

class EnergySummaryCard extends StatelessWidget {
  const EnergySummaryCard({
    super.key,
    required this.weekly,
    required this.loading,
    required this.hasData,
    required this.errorMessage,
    required this.solarKwh,
    required this.previousSolarKwh,
    required this.loadKwh,
    required this.previousLoadKwh,
    required this.onRangeChanged,
    required this.onOpenReport,
    this.forecast,
  });

  final bool weekly;
  final bool loading;
  final bool hasData;
  final String? errorMessage;
  final double solarKwh;
  final double previousSolarKwh;
  final double loadKwh;
  final double previousLoadKwh;
  final ValueChanged<bool> onRangeChanged;
  final VoidCallback onOpenReport;
  final EnergyForecastResult? forecast;

  String _formatEnergy(double value) => value.toStringAsFixed(2);

  /// How this period compares with the one before it.
  ///
  /// A percentage is only meaningful once the previous period held a real
  /// amount of energy. It used to be printed whenever `previous > 0`, so a
  /// period that generated 0.01 kWh followed by one that generated none showed
  /// "-100% from the previous period": arithmetically correct, and it reads as a
  /// catastrophic loss rather than as "there was nothing then". Below
  /// [meaningfulPrevious] the absolute figures speak for themselves and a
  /// percentage would only dramatise rounding.
  ///
  /// The threshold is 0.1 kWh, not the 0.01 kWh the value above is displayed
  /// to. A tenth of a kilowatt-hour is 360 Wh; below that the two periods are
  /// both rounding noise, and a user reading "−100%" against "0.00 kWh" is being
  /// told a hundred percent about a number that is displayed as zero.
  String _comparison(double current, double previous) {
    final change = classifyEnergyChange(current, previous);
    return switch (change.kind) {
      // The card has no "no previous period selected" state, so a null and a
      // zero previous period are the same situation here and are allowed to say
      // the same thing. The kinds stay separate so a surface that *does*
      // distinguish them, as the report does, still can.
      EnergyChangeKind.noPreviousData ||
      EnergyChangeKind.previousWasZero ||
      EnergyChangeKind.nothingToCompare => 'Nothing to compare yet',
      EnergyChangeKind.noProduction => 'No production',
      // Short on purpose. The two tiles sit side by side and wrap independently,
      // so a caption long enough to wrap on one of them leaves the pair with
      // mismatched heights. "from the previous period" was long enough to do that
      // on a 360dp screen.
      EnergyChangeKind.bothNegligible =>
        'Both periods under ${kMeaningfulEnergyKwh.toStringAsFixed(1)} kWh',
      EnergyChangeKind.unchanged => 'Same as before',
      EnergyChangeKind.changed =>
        '${change.percent > 0 ? '+' : ''}${change.percent}% vs previous',
    };
  }

  /// The threshold and the decision both come from
  /// `lib/utils/energy_comparison.dart`, which is what the energy report's
  /// `comparisonLabel` uses too. The two used to hold separate `0.1` literals
  /// *and* separate copies of the same branch order, and the report's copies were
  /// the ones that had never been fixed — so the same pair of numbers could be
  /// called a 20% fall on this card and a rounding artefact in the report.
  Widget _metric({
    required String title,
    required double value,
    required double previous,
    required Color color,
    required IconData icon,
  }) {
    final label = _comparison(value, previous);
    return Expanded(
      child: MergeSemantics(
        child: Semantics(
          label: '$title: ${_formatEnergy(value)} kilowatt-hours. $label',
          // Was a hand-written wash at radius 16 while the energy report's
          // identical tile used 14. AppTile is that object, once.
          child: AppTile(
            accent: color,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, color: color, size: 18)),
                const SizedBox(height: 6),
                Text(title, style: AppType.caption),
                const SizedBox(height: 2),
                // **`FittedBox(scaleDown)`, and this is not the `DateStripChip`
                // mistake.** That widget put its label inside a `SizedBox` of
                // fixed height, so the text was laid out at one size and scaled
                // back to another and the user's font-scale setting was quietly
                // discarded. Here the box is unconstrained vertically, the text is
                // laid out at the size and scale the user actually chose, and it
                // only shrinks if it genuinely does not fit the column it was
                // given.
                //
                // It is there because the alternative was measured, not assumed.
                // The two tiles share a row and each gets an `Expanded`, so at
                // 320 dp a column is about 115 dp wide -- and `1.53 kWh` at 17sp
                // w800 needs a little more than that. With `overflow: ellipsis`
                // the engine drew `1.53 k…` and `0.27 k…`: the unit amputated off
                // an entirely ordinary reading, on a phone narrower than any
                // this had ever been checked on. That is the `109....` regression
                // from 27 September 2026 again under a different number, and it
                // is the reason this widget had no test.
                //
                // `softWrap: false` so a long value cannot become two lines
                // inside a box whose height is the scaled child's; the figure
                // shrinks instead, which keeps it on one line and readable.
                // The ellipsis is gone on purpose -- there is no width at which
                // amputating this number is the right answer.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_formatEnergy(value)} kWh',
                    maxLines: 1,
                    softWrap: false,
                    // `numeralLg`, and it was a hand-written 17sp/800. The brief
                    // has no 800 — it jumps from 900 to 700 — and a numeral is
                    // display copy in this system, so this is the 24sp/900 token
                    // as written. It is the whole point of the scale that the
                    // figure shouts.
                    style: AppType.numeralLg.copyWith(color: appPrimaryText),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  // **Three lines, and the two before it were two and one.**
                  //
                  // The caption is short on purpose so the pair of tiles keeps a
                  // matching height, which is why it was capped rather than
                  // allowed to wrap freely. At a 2.0 system font `10 sp` becomes
                  // `20 sp`, and `-3% vs previous` then needs about three lines in
                  // a column roughly 115 dp wide -- so the cap amputated it to
                  // `-3% v…`, which is a *worse* caption than a wrapped one
                  // because it looks like a complete statement. A tile pair of
                  // slightly unequal height is a cosmetic cost; a comparison the
                  // user cannot finish reading is a correctness one.
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.captionSmall.copyWith(color: faintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // **Two colours, from the categorical vocabulary.** PV and AC each take their
    // own hue from `categoryColor`, which is the same lookup every other PV and
    // AC surface in the app uses. Deriving them from a user accent by lightness
    // was the old approach and it collapsed the two tiles onto one value or
    // pushed one icon under 3:1; a categorical system removes the problem instead
    // of tuning it.
    final solarColor = categoryColor(MetricCategory.pv);
    final loadColor = categoryColor(MetricCategory.ac);

    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **`Wrap`, not `Row`, and this is a measured fix rather than a
          // preference.**
          //
          // The `Row` held the title in an `Expanded` and the two controls at
          // their intrinsic widths. `Expanded` can shrink the title to nothing,
          // but it cannot shrink a `SegmentedButton`, and at a 2.0 system font
          // the toggle's labels are 28 sp -- so the fixed part of the row grew
          // past the card and the layout overflowed. It overflowed on a 411 dp
          // phone too, by 20 px, so this was not a small-screen problem at all:
          // **it is an accessibility bug that a user with a large system font
          // hits on every phone this app runs on**, at every text scale above
          // roughly 1.4.
          //
          // `Wrap` is the right shape for "these belong together, but not at any
          // cost": when everything fits it lays out on one run and
          // `spaceBetween` spreads the title and the controls to the edges,
          // which is what the `Row` did; when it does not fit, the controls move
          // to a second run and both stay whole. The alternatives were a fixed
          // two-line header, which costs the design a line on every phone to fix
          // a problem only large fonts have, and letting the title ellipsise,
          // which does nothing because the title was never the part that did not
          // fit.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            children: [
              Text(
                'Energy analytics',
                // Not `const`: `.copyWith` is a method call, and the brief's
                // headline is a token rather than a literal.
                style: AppType.headlineMd.copyWith(color: appPrimaryText),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // **`Flexible`, and the `Wrap` above was not enough on its
                  // own.** Moving the controls to their own run fixed the header
                  // `Row` but not this one: at 2.0 the toggle is about 285 dp
                  // wide against 298 dp available, plus a 48 dp button, and a
                  // `SegmentedButton` at its intrinsic width cannot be squeezed
                  // -- so the inner row overflowed by 35 to 111 px instead.
                  //
                  // `Flexible` lets it take what is there and no more, and the
                  // segment labels ellipsise rather than being clipped silently.
                  // A truncated `7 day…` is a far smaller failure than a layout
                  // that throws on every frame and paints the overflow stripe,
                  // and at 2.0 the toggle is still perfectly usable because the
                  // selected segment is the one that keeps its full label for as
                  // long as it can.
                  Flexible(
                    child: _EnergyRangeSelector(
                      weekly: weekly,
                      onChanged: onRangeChanged,
                    ),
                  ),
                  // A round button. `AppSurface` with `circle`, because a multi-side
                  // `Border` on `BoxShape.circle` does not paint.
                  AppSurface(
                    circle: true,
                    fill: AppSurfaces.surface,
                    child: IconButton(
                      tooltip: 'Open the energy report',
                      visualDensity: VisualDensity.compact,
                      onPressed: onOpenReport,
                      icon: const Icon(Icons.insert_chart_outlined_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Estimated from average telemetry power',
            style: AppType.caption.copyWith(color: faintColor),
          ),
          const SizedBox(height: 8),
          if (loading)
            const SizedBox(
              height: 94,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!hasData)
            SizedBox(
              height: 94,
              child: Center(
                child: Text(
                  errorMessage ?? 'No power data available to calculate from.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metric(
                      title: 'PV production',
                      value: solarKwh,
                      previous: previousSolarKwh,
                      color: solarColor,
                      icon: Icons.wb_sunny_outlined,
                    ),
                    const SizedBox(width: 10),
                    _metric(
                      title: 'AC usage',
                      value: loadKwh,
                      previous: previousLoadKwh,
                      color: loadColor,
                      icon: Icons.electrical_services_outlined,
                    ),
                  ],
                ),
                if (forecast != null) ...[
                  const SizedBox(height: 8),
                  _forecastSummary(context, forecast!),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _forecastSummary(BuildContext context, EnergyForecastResult result) {
    final target = result.productionTargetKwh;
    final progress = result.targetProgress;
    final targetLabel = target == null || progress == null
        ? 'No production target set'
        : '${(progress * 100).toStringAsFixed(0)}% of ${target.toStringAsFixed(1)} kWh';
    final runway = result.batteryDepletionHours == null
        ? 'No battery runway available'
        : '${result.batteryDepletionHours!.toStringAsFixed(1)} h of estimated battery';
    return Semantics(
      container: true,
      label:
          'Energy forecast. Estimated production ${result.dailyProductionEstimateKwh.toStringAsFixed(2)} kilowatt-hours. '
          '$targetLabel. $runway.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forecast',
            style: AppType.sectionTitle.copyWith(color: faintColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _forecastMetric(
                  context,
                  'Daily estimate',
                  '${result.dailyProductionEstimateKwh.toStringAsFixed(2)} kWh',
                  Icons.auto_graph_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _forecastMetric(
                  context,
                  'Peak usage',
                  result.peakUsageWatts == null
                      ? 'Unavailable'
                      : '${result.peakUsageWatts!.toStringAsFixed(0)} W',
                  Icons.bolt_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (progress != null)
            // The brief's progress bar: a 12dp depressed track in the *page*
            // colour with a 1px hairline, and an accent fill. The track
            // has to be darker than the card it sits in for the fill to lift off
            // it, which is why `LinearProgressIndicator`'s own background is set
            // rather than left to its default (a tinted version of the fill).
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: AppSurfaces.track,
                borderRadius: BorderRadius.circular(AppRadius.bar),
                border: AppBorders.hairlineBorder,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.bar),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(AppRadius.bar),
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppPalette.error,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 5),
          Text(
            '$targetLabel · $runway',
            style: AppType.captionSmall.copyWith(color: faintColor),
          ),
          if (result.hasProduction)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Actual today: ${result.observedProductionKwh.toStringAsFixed(2)} kWh',
                style: AppType.captionSmall.copyWith(color: faintColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _forecastMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.captionSmall),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.numeralLg.copyWith(color: appPrimaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnergyRangeSelector extends StatefulWidget {
  const _EnergyRangeSelector({required this.weekly, required this.onChanged});

  final bool weekly;
  final ValueChanged<bool> onChanged;

  @override
  State<_EnergyRangeSelector> createState() => _EnergyRangeSelectorState();
}

class _EnergyRangeSelectorState extends State<_EnergyRangeSelector> {
  late bool _weekly = widget.weekly;

  @override
  void didUpdateWidget(covariant _EnergyRangeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekly != widget.weekly) {
      _weekly = widget.weekly;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Day', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        ButtonSegment(
          value: true,
          label: Text('7 days', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      selected: {_weekly},
      onSelectionChanged: (selection) {
        final value = selection.first;
        setState(() => _weekly = value);
        widget.onChanged(value);
      },
    );
  }
}
