import 'package:flutter/material.dart';

import '../utils/csv_builder.dart';
import '../../../services/energy_report_service.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.isDark,
    required this.sharing,
    required this.buckets,
    required this.selectedDate,
    required this.monthly,
    required this.sharingNotifier,
    required this.onShare,
  });

  final bool isDark;
  final bool sharing;
  final List<EnergyBucket> buckets;
  final DateTime selectedDate;
  final bool monthly;
  final ValueNotifier<bool> sharingNotifier;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: sharing
          ? null
          : () => shareEnergyReport(
                context: context,
                buckets: buckets,
                selectedDate: selectedDate,
                monthly: monthly,
                sharingNotifier: sharingNotifier,
              ),
      icon: sharing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      label: Text(sharing ? 'Menyiapkan CSV…' : 'Ekspor laporan CSV'),
    );
  }
}