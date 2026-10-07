import 'package:flutter/material.dart';
import '../../../theme/app_theme_of.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../../../services/energy_report_service.dart';

class DataNote extends StatelessWidget {
  const DataNote({
    super.key,
    required this.isDark,
    required this.data,
  });

  final bool isDark;
  final EnergyReportData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          // The resolved theme, not `isDark`: a `bool` cannot tell Dracula from
          // the app's own dark preset, and the hex pair this replaced had no
          // Dracula branch at all.
          gradient: AppSkeuo.fillGradient(
            AppSurfaces.card(appThemeOf(context)),
            foreground: AppSkeuo.textSide(appThemeOf(context)),
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source & calculation',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'ThingsBoard · PZEM · ${data.sampleCount} hourly power aggregates',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              'Hourly energy is calculated from the average Power DC/AC (W) stored in the time-series database. Data refreshes automatically every 5 minutes.',
              style: TextStyle(
                fontSize: 11,
                color: faintColor(isDark),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}