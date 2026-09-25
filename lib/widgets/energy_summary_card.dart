import 'package:flutter/material.dart';

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
    this.forecast,
  });

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

  String _comparison(double current, double previous) {
    if (previous <= 0) return 'Belum ada pembanding';
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Sama dengan periode lalu';
    return '${change > 0 ? '+' : ''}$change% dari periode lalu';
  }

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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icon, color: color, size: 18)),
                const SizedBox(height: 9),
                Text(title, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  '${_formatEnergy(value)} kWh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
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
    final solarColor = isDark
        ? const Color(0xFFFFC857)
        : const Color(0xFFB77900);
    final loadColor = isDark
        ? const Color(0xFF69B7FF)
        : const Color(0xFF1769AA);

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
            'Forecast',
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
