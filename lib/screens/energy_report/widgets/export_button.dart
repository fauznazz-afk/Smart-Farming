import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../utils/csv_builder.dart';
import '../../../services/energy_report_service.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    required this.sharing,
    required this.buckets,
    required this.selectedDate,
    required this.monthly,
    required this.sharingNotifier,
  });

  final bool sharing;
  final List<EnergyBucket> buckets;
  final DateTime selectedDate;
  final bool monthly;
  final ValueNotifier<bool> sharingNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: sharingNotifier,
      builder: (context, isSharing, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.all(AppRadius.pill),
            boxShadow: isSharing
                ? null
                : [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
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
          ),
        );
      },
    );
  }
}