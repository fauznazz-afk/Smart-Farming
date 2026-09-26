import 'package:flutter/material.dart';

import '../../../services/connection_health_service.dart';
import '../utils/telemetry_helpers.dart';

const Color _alertAccent = Color(0xFFE66A45);

/// Wraps a dashboard card so tapping it jumps to the matching detail tab.
class DashboardShortcut extends StatelessWidget {
  const DashboardShortcut({
    super.key,
    required this.pageIndex,
    required this.onSelect,
    required this.child,
  });

  final int pageIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(pageIndex),
      child: child,
    );
  }
}

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
            const Text('Gagal mengambil telemetry dari ThingsBoard.'),
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
    final color = Colors.orange.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline — menampilkan data terakhir dari ${describeCacheAge(cacheTime)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 18, color: color),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _alertAccent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _alertAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: _alertAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: messages
                    .map(
                      (message) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(message),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
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
    required this.isDark,
    this.onRetry,
  });

  final bool failed;
  final List<String> staleNames;
  final ConnectionHealth health;
  final DateTime? lastSuccessfulAt;
  final String? errorMessage;
  final bool isDark;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final stale = !failed && staleNames.isNotEmpty;
    final color = failed
        ? Colors.deepOrange
        : stale
        ? Colors.orange.shade800
        : Colors.green;
    final label = failed
        ? 'ThingsBoard gagal'
        : stale
        ? 'Terhubung · stale: ${staleNames.join(', ')}'
        : health.statusMessage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: Tooltip(
          key: ValueKey('$failed:$stale:$label'),
          message: failed
              ? 'Fetch telemetry gagal. Periksa koneksi/server. ${errorMessage ?? ''}'
              : 'Fetch sukses${lastSuccessfulAt == null ? '' : ' pukul ${formatClock(lastSuccessfulAt!)}'}${stale ? '. Data lama: ${staleNames.join(', ')}' : ''}',
          child: Semantics(
            label: label,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (failed)
                    InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.refresh, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animates [ConnectionStatusBanner] in and out without collapsing the list.
class ConnectionStatusBannerSwitcher extends StatelessWidget {
  const ConnectionStatusBannerSwitcher({
    super.key,
    required this.visible,
    required this.builder,
  });

  final bool visible;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axis: Axis.vertical,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: visible
          ? KeyedSubtree(
              key: const ValueKey('connection-status-visible'),
              child: builder(),
            )
          : const SizedBox(
              key: ValueKey('connection-status-hidden'),
              width: double.infinity,
              height: 0,
            ),
    );
  }
}
