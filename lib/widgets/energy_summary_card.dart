import 'package:flutter/material.dart';

import '../screens/dashboard/utils/color_helpers.dart';
import '../screens/dashboard/utils/design_tokens.dart';
import '../services/energy_forecast_service.dart';
import '../utils/energy_comparison.dart';
import 'liquid_glass.dart';

class EnergySummaryCard extends StatelessWidget {
  const EnergySummaryCard({
    super.key,
    required this.theme,
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
    required this.seedColor,
    this.forecast,
  });

  final Color seedColor;

  /// The appearance to paint, as an [AppTheme] rather than a bool.
  ///
  /// The card itself takes an [AppTheme] because it hands one straight to
  /// `AppCard` and `AppTile`, and a bool would have to be converted back into a
  /// theme at each of those calls — which is the conversion that loses Dracula.
  /// The two places below that genuinely only need a brightness (the two
  /// `themeColor` lightness steps and `faintColor`) pass `theme.isDark`, which
  /// is `true` for both dark presets.
  final AppTheme theme;
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
    if (previous <= 0) return 'Nothing to compare yet';
    if (previous < _meaningfulPrevious) {
      if (current < _meaningfulPrevious) {
        return current <= 0
            ? 'No production'
            : '${_formatEnergy(current)} kWh, none last period';
      }
      return 'Nothing to compare yet';
    }
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Same as before';
    // Short on purpose. The two tiles sit side by side and wrap independently,
    // so a caption long enough to wrap on one of them leaves the pair with
    // mismatched heights. "from the previous period" was long enough to do that
    // on a 360dp screen.
    return '${change > 0 ? '+' : ''}$change% vs previous';
  }

  /// Below this, two periods are both too small for a ratio to mean anything.
  ///
  /// Shared with the energy report's `comparisonLabel` through
  /// [kMeaningfulEnergyKwh]. The two used to hold separate `0.1` literals, and
  /// the report's was the copy that had never been fixed — so the same pair of
  /// numbers could be called a 20% fall on the dashboard and a rounding
  /// artefact in the report.
  static const double _meaningfulPrevious = kMeaningfulEnergyKwh;

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
            theme: theme,
            accent: color,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, color: color, size: 18)),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  '${_formatEnergy(value)} kWh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: faintColor(theme.isDark),
                  ),
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
    // Both tiles follow the accent the user picked, separated only by lightness.
    //
    // They were hard-coded amber and blue, which meant a user who selected
    // "Ocean cyan" got two large saturated tiles in colours that appear nowhere
    // in Settings. That is the same objection as the hue rotation, in a place
    // where it is more visible: the Overview page stopped matching the rest of
    // the app. Two lightness steps of one hue keeps the tiles distinguishable
    // from each other — which their icons and labels already do — while the page
    // stays inside the palette the user actually chose.
    // `theme.isDark` and not a Dracula branch, for the reason the rest of the
    // app's text and status palette keeps its boolean: these two lightness steps
    // are keyed on brightness. **That is true today and would need measuring
    // before Dracula is a supported appearance for this card** — the same
    // trap `metricColor` documents, where one HSL lightness cannot serve two
    // hues because green carries far more luminance than purple does.
    //
    // Measured, and it is exactly that trap. `themeColor(lightness: 0.52,
    // saturation: 0.5)` on Dracula's preset purple is `#7A47C2`, which is
    // **1.97:1 on the chrome surface** — the AC usage icon was effectively
    // invisible. These are **icons**, so WCAG 1.4.11 wants 3:1 rather than the
    // 4.5:1 that text gets, and both clear it now.
    //
    // **Two colours, not one.** Routing both through `metricColor` was the
    // first attempt and it collapsed the two tiles onto the same value — because
    // `metricColor` takes an `index` and deliberately **ignores** it, so there
    // is exactly one colour to give and the PV/AC distinction disappeared. The
    // existing test caught it. `strongMetricColor` is the sibling that is *not*
    // the same colour, and it is still a step away from the surface on all three
    // themes, which is the second thing that got measured rather than assumed.
    //
    // **Light mode was under 3:1 on both icons and this fixes it.** These are
    // icons, so WCAG 1.4.11 wants 3:1 rather than the 4.5:1 that text gets, and
    // `metricColor` is built for text: measured on the light page it is 2.28 /
    // 2.88 / 2.16 / 2.21 for the four accents the user can pick, so three of four
    // fail as a graphic. [metricGraphic] exists for exactly this requirement and
    // steps only the graphical uses, rather than darkening `metricColor` and
    // restyling every metric value in the app.
    //
    // **Two colours, not one.** Routing both through `metricColor` was the first
    // attempt and it collapsed the two tiles onto the same value, because
    // `metricColor` takes an `index` and deliberately **ignores** it. The
    // existing test caught it. The second steps further from the first so the
    // pair stays distinguishable at 3:1 rather than at 4.5:1.
    final solarColor = metricGraphic(
      seedColor: seedColor,
      index: 0,
      theme: theme,
    );
    final loadColor = theme.isDark
        ? strongMetricColor(seedColor: seedColor, index: 1, theme: theme)
        : HSLColor.fromColor(
            metricGraphic(seedColor: seedColor, index: 0, theme: theme),
          ).withLightness(0.24).toColor();

    return AppCard(
      theme: theme,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Energy analytics',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Day')),
                  ButtonSegment(value: true, label: Text('7 days')),
                ],
                selected: {weekly},
                onSelectionChanged: (selection) =>
                    onRangeChanged(selection.first),
              ),
              IconButton(
                tooltip: 'Open the energy report',
                visualDensity: VisualDensity.compact,
                onPressed: onOpenReport,
                icon: const Icon(Icons.insert_chart_outlined_rounded),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Estimated from average telemetry power',
            style: TextStyle(
              fontSize: 11,
              color: faintColor(theme.isDark),
            ),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: faintColor(theme.isDark),
            ),
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
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppRadius.bar),
            ),
          const SizedBox(height: 5),
          Text(
            '$targetLabel · $runway',
            style: TextStyle(
              fontSize: 10,
              color: faintColor(theme.isDark),
            ),
          ),
          if (result.hasProduction)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Actual today: ${result.observedProductionKwh.toStringAsFixed(2)} kWh',
                style: TextStyle(
                  fontSize: 10,
                  color: faintColor(theme.isDark),
                ),
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
              Text(label, style: const TextStyle(fontSize: 10)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
