import 'package:flutter/material.dart';

import '../screens/dashboard/utils/color_helpers.dart';
import '../services/energy_forecast_service.dart';
import 'liquid_glass.dart';

class EnergySummaryCard extends StatelessWidget {
  const EnergySummaryCard({
    super.key,
    required this.isDark,
    required this.performanceMode,
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
  final bool isDark;
  final bool performanceMode;
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
  /// "−100% dari periode lalu": arithmetically correct, and it reads as a
  /// catastrophic loss rather than as "there was nothing then". Below
  /// [meaningfulPrevious] the absolute figures speak for themselves and a
  /// percentage would only dramatise rounding.
  ///
  /// The threshold is 0.1 kWh, not the 0.01 kWh the value above is displayed
  /// to. A tenth of a kilowatt-hour is 360 Wh; below that the two periods are
  /// both rounding noise, and a user reading "−100%" against "0.00 kWh" is being
  /// told a hundred percent about a number that is displayed as zero.
  String _comparison(double current, double previous) {
    if (previous <= 0) return 'Belum ada pembanding';
    if (previous < _meaningfulPrevious) {
      if (current < _meaningfulPrevious) {
        return current <= 0
            ? 'Tidak ada produksi'
            : '(${_formatEnergy(current)} kWh, sebelumnya nihil)';
      }
      return 'Belum ada pembanding berarti';
    }
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Sama dengan periode lalu';
    return '${change > 0 ? '+' : ''}$change% dari periode lalu';
  }

  /// Below this, two periods are both too small for a ratio to mean anything.
  static const double _meaningfulPrevious = 0.1;

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
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
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
                    color: isDark ? Colors.white60 : Colors.black54,
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
    final solarColor = themeColor(
      seedColor: seedColor,
      lightness: isDark ? 0.72 : 0.42,
    );
    final loadColor = themeColor(
      seedColor: seedColor,
      lightness: isDark ? 0.52 : 0.30,
      saturation: 0.5,
    );

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
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
                  ButtonSegment(value: false, label: Text('Hari')),
                  ButtonSegment(value: true, label: Text('7 hari')),
                ],
                selected: {weekly},
                onSelectionChanged: (selection) =>
                    onRangeChanged(selection.first),
              ),
              IconButton(
                tooltip: 'Lihat laporan energi',
                visualDensity: VisualDensity.compact,
                onPressed: onOpenReport,
                icon: const Icon(Icons.insert_chart_outlined_rounded),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Estimasi dari daya rata-rata telemetry',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
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
                  errorMessage ?? 'Data daya belum tersedia untuk perhitungan.',
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
                      title: 'Produksi PV',
                      value: solarKwh,
                      previous: previousSolarKwh,
                      color: solarColor,
                      icon: Icons.wb_sunny_outlined,
                    ),
                    const SizedBox(width: 10),
                    _metric(
                      title: 'Pemakaian AC',
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
        ? 'Target produksi belum diatur'
        : '${(progress * 100).toStringAsFixed(0)}% dari ${target.toStringAsFixed(1)} kWh';
    final runway = result.batteryDepletionHours == null
        ? 'Battery runway tidak tersedia'
        : '${result.batteryDepletionHours!.toStringAsFixed(1)} jam estimasi baterai';
    return Semantics(
      container: true,
      label:
          'Forecast energi. Estimasi produksi ${result.dailyProductionEstimateKwh.toStringAsFixed(2)} kilowatt-hours. '
          '$targetLabel. $runway.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prediksi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _forecastMetric(
                  context,
                  'Estimasi harian',
                  '${result.dailyProductionEstimateKwh.toStringAsFixed(2)} kWh',
                  Icons.auto_graph_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _forecastMetric(
                  context,
                  'Puncak pakai',
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
              borderRadius: BorderRadius.circular(8),
            ),
          const SizedBox(height: 5),
          Text(
            '$targetLabel · $runway',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          if (result.hasProduction)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aktual hari ini: ${result.observedProductionKwh.toStringAsFixed(2)} kWh',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54,
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
