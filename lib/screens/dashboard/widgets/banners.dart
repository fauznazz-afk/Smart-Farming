import 'package:flutter/material.dart';

import '../../../services/connection_health_service.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import '../utils/telemetry_helpers.dart';

/// Full-screen placeholder shown when the first telemetry fetch fails.
class TelemetryErrorView extends StatelessWidget {
  const TelemetryErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 42),
            const SizedBox(height: 12),
            const Text('Failed to fetch telemetry from ThingsBoard.'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber banner shown while the app displays cached telemetry.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.cacheTime, this.onRetry});

  final DateTime? cacheTime;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = statusWarn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppSurface(
        radius: AppRadius.inset,
        fill: AppBorders.categoricalWash(color),
        border: AppBorders.categoricalBorder(color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline - showing the last data from ${describeCacheAge(cacheTime)}',
                style: AppType.labelUppercase.copyWith(color: color),
              ),
            ),
            RetryButton(onRetry: onRetry, color: color),
          ],
        ),
      ),
    );
  }
}

/// The retry button both banners share.
class RetryButton extends StatelessWidget {
  const RetryButton({super.key, required this.onRetry, required this.color});

  final VoidCallback? onRetry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Try again',
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          button: true,
          label: 'Try again',
          child: InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.refresh, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline list of currently active energy/environment alerts.
class EnergyAlertBanner extends StatelessWidget {
  const EnergyAlertBanner({super.key, required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      radius: AppRadius.inset,
      fill: AppBorders.categoricalWash(statusAlert),
      border: AppBorders.categoricalBorder(statusAlert),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, color: statusAlert),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages
                  .map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(message, style: AppType.bodySm.copyWith(color: appPrimaryText)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grows a banner in and collapses it away instead of popping it.
class BannerSwitcher extends StatelessWidget {
  const BannerSwitcher({
    super.key,
    required this.visible,
    required this.identity,
    required this.builder,
    this.bottomSpacing = 10,
  });

  final bool visible;
  final Object identity;
  final Widget Function() builder;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.container,
      reverseDuration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.25),
              end: Offset.zero,
            ).animate(curved),
            child: SizeTransition(
              sizeFactor: curved,
              axis: Axis.vertical,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: visible
          ? KeyedSubtree(
              key: ValueKey('banner:$identity'),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomSpacing),
                child: builder(),
              ),
            )
          : const SizedBox(
              key: ValueKey('banner:none'),
              width: double.infinity,
              height: 0,
            ),
    );
  }
}

/// Connection health strip: fetch failures, stale devices, or transport health.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    super.key,
    required this.failed,
    required this.staleNames,
    required this.health,
    required this.lastSuccessfulAt,
    required this.errorMessage,
    this.onRetry,
  });

  final bool failed;
  final List<String> staleNames;
  final ConnectionHealth health;
  final DateTime? lastSuccessfulAt;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final stale = !failed && staleNames.isNotEmpty;
    final color = failed
        ? statusBad
        : stale
        ? statusWarn
        : statusOk;
    final label = failed
        ? 'ThingsBoard unreachable'
        : stale
        ? 'Connected - stale data: ${staleNames.join(', ')}'
        : health.statusMessage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppSurface(
        radius: 10,
        fill: AppBorders.categoricalWash(color),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                failed
                    ? Icons.cloud_off
                    : health.isHealthy
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: color,
                size: 17,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.labelUppercase.copyWith(color: color),
              ),
            ),
            if (failed)
              RetryButton(onRetry: onRetry, color: color),
          ],
        ),
      ),
    );
  }
}

/// Wraps a tooltip around [ConnectionStatusBanner] and animates it in and out.
class ConnectionStatusBannerSwitcher extends StatelessWidget {
  const ConnectionStatusBannerSwitcher({
    super.key,
    required this.failed,
    required this.staleNames,
    required this.health,
    required this.lastSuccessfulAt,
    required this.errorMessage,
    required this.visible,
    this.onRetry,
  });

  final bool failed;
  final List<String> staleNames;
  final ConnectionHealth health;
  final DateTime? lastSuccessfulAt;
  final String? errorMessage;
  final bool visible;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final stale = !failed && staleNames.isNotEmpty;
    final label = failed
        ? 'ThingsBoard unreachable'
        : stale
        ? 'Connected - stale data: ${staleNames.join(', ')}'
        : health.statusMessage;

    return BannerSwitcher(
      visible: visible,
      identity: '$failed:$stale:$label',
      bottomSpacing: 8,
      builder: () => Tooltip(
        message: failed
            ? 'Telemetry fetch failed. Check the connection or the server. ${errorMessage ?? ''}'
            : 'Fetch succeeded${lastSuccessfulAt == null ? '' : ' at ${formatClock(lastSuccessfulAt!)}'}${stale ? '. Stale data: ${staleNames.join(', ')}' : ''}',
        child: Semantics(
          label: label,
          child: ConnectionStatusBanner(
            failed: failed,
            staleNames: staleNames,
            health: health,
            lastSuccessfulAt: lastSuccessfulAt,
            errorMessage: errorMessage,
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
