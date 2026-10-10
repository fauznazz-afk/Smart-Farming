import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/csv_builder.dart';
import '../../../services/energy_report_service.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.buckets,
    required this.selectedDate,
    required this.monthly,
    required this.sharingNotifier,
  });

  final List<EnergyBucket> buckets;
  final DateTime selectedDate;
  final bool monthly;
  final ValueNotifier<bool> sharingNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: sharingNotifier,
      builder: (context, isSharing, _) {
        return AppCard(
          padding: EdgeInsets.zero,
          child: FilledButton.icon(
            onPressed: isSharing
                ? null
                : () => shareEnergyReport(
                      context: context,
                      buckets: buckets,
                      selectedDate: selectedDate,
                      monthly: monthly,
                      sharingNotifier: sharingNotifier,
                    ),
            icon: isSharing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(isSharing ? 'Preparing CSV…' : 'Export CSV report'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        );
      },
    );
  }
}
