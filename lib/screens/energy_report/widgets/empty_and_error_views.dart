import 'package:flutter/material.dart';

import '../utils/format_helpers.dart';
import '../../../services/energy_report_service.dart';

class EmptyPeriodView extends StatelessWidget {
  const EmptyPeriodView({
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.event_busy_outlined, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Belum ada data untuk periode ini',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Data ThingsBoard mencakup ${formatDateLabel(data.firstSample)} hingga ${formatDateLabel(data.lastSample)}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.isDark,
    required this.error,
    required this.onRetry,
  });

  final bool isDark;
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
              label: const Text('Coba lagi'),
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan perangkat PZEM mengirim telemetry dan akun ThingsBoard memiliki akses histori perangkat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}