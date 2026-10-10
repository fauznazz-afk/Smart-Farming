import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../../widgets/liquid_glass.dart';
import '../../../services/energy_report_service.dart';

class DataNote extends StatelessWidget {
  const DataNote({
    super.key,
    required this.data,
  });

  final EnergyReportData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
              color: faintColor,
            ),
          ),
        ],
      ),
    );
  }
}
