import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart'
    show AppSurfaces, AppBorders, AppRadius, AppCard;
import '../utils/format_helpers.dart';
import '../../../services/energy_report_service.dart';

class EmptyPeriodView extends StatelessWidget {
  const EmptyPeriodView({
    super.key,
    required this.data,
  });

  final EnergyReportData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined, size: 36),
          const SizedBox(height: 10),
          const Text(
            'No data for this period',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'ThingsBoard data covers ${formatDateLabel(data.firstSample)} to ${formatDateLabel(data.lastSample)}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: faintColor),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            Text(
              'Check that the PZEM device is sending telemetry and that the ThingsBoard account has access to its history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: faintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}