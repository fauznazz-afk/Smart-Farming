import 'package:flutter/material.dart';

import '../services/energy_forecast_service.dart';
import 'liquid_glass.dart';

class EnergyForecastCard extends StatelessWidget {
  const EnergyForecastCard({
    super.key,
    required this.result,
    required this.isDark,
    this.performanceMode = true,
    this.title = 'Energy forecast',
  });

  final EnergyForecastResult result;
  final bool isDark;
  final bool performanceMode;
  final String title;

  String _kwh(double value) => '${value.toStringAsFixed(2)} kWh';
  String _watts(double value) => '${value.toStringAsFixed(0)} W';

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? Colors.white60 : Colors.black54;
    final accent = Theme.of(context).colorScheme.primary;
    final target = result.productionTargetKwh;
    final targetText = target == null || result.targetProgress == null
        ? 'No production target configured'
        : '${(result.targetProgress! * 100).toStringAsFixed(0)}% of ${_kwh(target)} target';
    final batteryText = result.batteryDepletionHours == null
        ? 'Battery runway unavailable'
        : '${result.batteryDepletionHours!.toStringAsFixed(1)} h estimated runway';

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(16),
      child: Semantics(
        container: true,
        label:
            '$title. Daily production estimate ${_kwh(result.dailyProductionEstimateKwh)}. '
            '$targetText. $batteryText.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph_rounded, color: accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Calculated from available telemetry history',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(
                  'Daily production',
                  _kwh(result.dailyProductionEstimateKwh),
                  Icons.wb_sunny_outlined,
                  accent,
                ),
                const SizedBox(width: 10),
                _metric(
                  'Peak usage',
                  result.peakUsageWatts == null
                      ? 'Unavailable'
                      : _watts(result.peakUsageWatts!),
                  Icons.bolt_outlined,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: result.targetProgress?.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(targetText, style: TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.battery_charging_full_rounded,
                  size: 18,
                  color: Colors.green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    batteryText,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
                if (result.batteryStateOfCharge != null)
                  Text('${result.batteryStateOfCharge!.toStringAsFixed(0)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 3),
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
        ),
      ),
    );
  }
}
