import 'package:flutter/material.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sumber & perhitungan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'ThingsBoard · PZEM · ${data.sampleCount} agregat daya per jam',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              'Energi per jam dihitung dari rata-rata Power DC/AC (W) yang tersimpan di time-series database. Data disegarkan otomatis setiap 5 menit.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}