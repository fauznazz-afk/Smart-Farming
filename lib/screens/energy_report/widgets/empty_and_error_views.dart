import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/format_helpers.dart';
import '../../../services/energy_report_service.dart';

class EmptyPeriodView extends StatelessWidget {
  const EmptyPeriodView({super.key, required this.data});

  final EnergyReportData data;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // 36, inside the brief's 32–40 band for a hero/tile icon. Neutral
          // rather than categorical: this state has no category, and the
          // categorical hues are markers for data rather than for chrome.
          const Icon(Icons.event_busy_outlined, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No data for this period',
            // `headline-md`, the brief's uppercase card title. It was a bare
            // `w800` at the framework's default size.
            style: AppType.headlineMd,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ThingsBoard data covers ${formatDateLabel(data.firstSample)} to ${formatDateLabel(data.lastSample)}.',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: faintColor),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: AppSpacing.md),
            Text(
              error,
              textAlign: TextAlign.center,
              // The brief's body line. The bare `Text` this replaces inherited
              // whatever the ambient default was, which on this screen is the
              // muted body style — the same colour, now stated.
              style: AppType.bodyMd.copyWith(color: AppSurfaces.onSurface),
            ),
            const SizedBox(height: AppSpacing.md),
            // The brief's `button-primary`, standing on the page with its
            // tinted hard shadow. The shadow comes from the `DecoratedBox`
            // behind the button rather than from `FilledButton`'s `elevation`,
            // which Material maps through `kElevationToShadow` and can only
            // render as a blurred halo — the one shadow language the brief bans.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.all(AppRadius.card),
                boxShadow: AppShadows.stampedIn(AppPalette.primary),
              ),
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: AppPalette.onHue,
                  textStyle: AppType.buttonLabel,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.all(AppRadius.card),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Check that the PZEM device is sending telemetry and that the ThingsBoard account has access to its history.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: faintColor),
            ),
          ],
        ),
      ),
    );
  }
}
