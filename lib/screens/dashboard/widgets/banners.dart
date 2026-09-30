import 'package:flutter/material.dart';

import '../../../services/connection_health_service.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import '../utils/telemetry_helpers.dart';

/// The energy alert banner's accent.
///
/// This is a one-off literal with no dark-mode variant, and it sits next to the
/// banner in `banners.dart` that now uses `statusWarn`. Left alone it would be
/// the third amber in the same file. It is a warning that is not a measurement,
/// so it is the alert tone rather than the measured one.
const Color _alertAccent = Color(0xFFC2603C);

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
    // Was `Colors.orange.shade700`, which is `0xFFF57C00` — the same value the
    // alarm history used for a warning, and 2.44:1 on the page at 12dp. The
    // offline banner is a warning, so it uses the measured one.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = statusWarn(isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(AppRadius.inset),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline - showing the last data from ${describeCacheAge(cacheTime)}',
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
///
/// It draws no animation of its own. [CollapsibleBanner] wraps it so that it
/// arrives and leaves by growing and shrinking, which is what stops the whole
/// Overview jumping down a card-height the instant a reading returns to range.
class EnergyAlertBanner extends StatelessWidget {
  const EnergyAlertBanner({super.key, required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _alertAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _alertAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, color: _alertAccent),
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
    );
  }
}

/// Grows a banner in and collapses it away instead of popping it.
///
/// A plain conditional render is the obvious implementation and it is what this
/// replaced, and on a dashboard it is genuinely bad: an alarm clearing made the
/// entire page below it jump up by the banner's full height in a single frame.
/// Nothing indicates that anything happened, so it reads as a glitch rather than
/// as a condition ending.
///
/// Three properties together make the disappearance legible:
///
/// - the outgoing child is kept alive for the length of the exit and stacked
///   under the incoming one, so the height shrinks continuously instead of the
///   whole strip vanishing on one frame;
/// - the opacity fades, drawing the eye to the thing that is leaving;
/// - the banner lifts slightly as it goes, which is the direction a dismissed
///   thing is expected to move in.
///
/// The exit is longer than the entrance. An alarm appearing is worth noticing
/// quickly; one clearing is information too, but it does not need to interrupt.
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
      duration: const Duration(milliseconds: 320),
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
            // This is what makes the banner actually collapse. The Stack in
            // `layoutBuilder` takes the largest of its children, so a banner
            // that only faded would keep the full card height reserved for the
            // whole exit and then snap to zero on the final frame — worse than
            // no animation. An AnimatedSwitcher runs its transition animation
            // forwards for the incoming child and backwards for the outgoing
            // one, so the same SizeTransition shrinks as it leaves.
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
        ? statusBad(isDark)
        : stale
        ? statusWarn(isDark)
        : statusOk(isDark);
    final label = failed
        ? 'ThingsBoard unreachable'
        : stale
        ? 'Connected - stale data: ${staleNames.join(', ')}'
        : health.statusMessage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
    );
  }
}

/// Wraps a tooltip around [ConnectionStatusBanner] and animates it in and out.
///
/// The banner draws itself; this exists because a connection state change and a
/// banner appearing are the same event and should look the same way.
class ConnectionStatusBannerSwitcher extends StatelessWidget {
  const ConnectionStatusBannerSwitcher({
    super.key,
    required this.failed,
    required this.staleNames,
    required this.health,
    required this.lastSuccessfulAt,
    required this.errorMessage,
    required this.isDark,
    required this.visible,
    this.onRetry,
  });

  final bool failed;
  final List<String> staleNames;
  final ConnectionHealth health;
  final DateTime? lastSuccessfulAt;
  final String? errorMessage;
  final bool isDark;
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
            isDark: isDark,
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
