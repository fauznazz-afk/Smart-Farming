import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../../../widgets/liquid_glass.dart';
import '../../../services/energy_report_service.dart';

class DataNote extends StatelessWidget {
  const DataNote({super.key, required this.data});

  final EnergyReportData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `headline-md`, the brief's uppercase card title at 20/900. It was a
          // bare `fontWeight: w800` at the framework's default body size, which
          // is neither the brief's headline slot nor a weight in its scale of
          // three.
          Text('Source & calculation', style: AppType.headlineMd),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ThingsBoard · PZEM · ${data.sampleCount} hourly power aggregates',
            // The brief's metadata line: uppercase, wide-tracked, secondary
            // ink. A literal 12px is what `label-uppercase-md` already is.
            style: AppType.labelUppercase.copyWith(color: faintColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hourly energy is calculated from the average Power DC/AC (W) stored in the time-series database. Data refreshes automatically every 5 minutes.',
            // The brief's "rare lowercase line for descriptive paragraphs",
            // which is exactly what this is. Left in the body face on purpose
            // — uppercasing a two-sentence footnote is legible but hostile, and
            // the brief marks body as the place lowercase survives.
            style: AppType.bodySm.copyWith(color: faintColor),
          ),
        ],
      ),
    );
  }
}
