import 'package:flutter/material.dart';

import '../../../services/connection_health_service.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import '../utils/telemetry_helpers.dart';

/// The outline a status banner wears: the status hue at 1px, nothing more.
///
/// **Why a hairline and not a wash.** These banners were built on `AppSurface`
/// with `AppBorders.categoricalWash(status)` as the *fill* — a 20%-alpha block of
/// the status colour the full width of the page, with a 20%-alpha border of the
/// same hue stacked on top of it. That is the brief's badge-chip recipe applied
/// to a banner, and it is the wrong size for it: the brief sanctions a 20% tint
/// "behind small uppercase badges", and this repo has three previous design
/// systems that lost caption contrast to a wash behind text.
///
/// A status colour here is now **ink and one hairline**. The brief is explicit
/// that a status colour is "ink, a dot, or a hairline" and never a large fill,
/// and the three banners becoming one component instead of three tints is the
/// other half of that: the difference between them is now the hue and the word,
/// which is the information, rather than the size of a coloured block.
Border _statusBannerEdge(Color color) =>
    Border.fromBorderSide(BorderSide(color: color, width: 1));

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
            // [statusBad] as ink, on the rule [_statusBannerEdge] documents: a
            // condition is a glyph and a word, never a block of colour. It was
            // inheriting the ambient default, which is not a colour the app
            // chose.
            const Icon(Icons.cloud_off, size: 42, color: statusBad),
            const SizedBox(height: 12),
            Text(
              'Failed to fetch telemetry from ThingsBoard.',
              textAlign: TextAlign.center,
              style: AppType.headlineLg.copyWith(color: appPrimaryText),
            ),
            const SizedBox(height: 8),
            // The one lowercase line on the screen, and the brief's `body-sm`
            // is for exactly this: descriptive print under a headline.
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: faintColor),
            ),
            const SizedBox(height: 16),
            // **The brief's `button-primary`, and the only large lime fill
            // allowed anywhere in the app.** Acid lime fill, black ink,
            // `button-label` type, 8px radius, 56dp tall, with the tinted
            // displacement `4px 4px 0 rgba(198,255,0,0.2)` in place of the
            // black one.
            //
            // The shadow sits on a wrapping `DecoratedBox` rather than on the
            // button's own style, because a `BoxShadow` in a `BoxDecoration`
            // follows that decoration's `borderRadius` — the same trick
            // `AppCard` uses, and what stops the lime displacement poking out
            // of the button's rounded corners as a rectangle.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.all(AppRadius.card),
                boxShadow: AppShadows.stampedIn(AppPalette.primary),
              ),
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppPalette.onHue,
                ),
                label: Text(
                  'Try again',
                  style: AppType.buttonLabel.copyWith(color: AppPalette.onHue),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: AppPalette.onHue,
                  disabledBackgroundColor: AppSurfaces.surfaceAlt,
                  disabledForegroundColor: faintColor,
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.all(AppRadius.card),
                  ),
                  elevation: 0,
                ),
              ),
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
      // **The stamped tier.** A banner is a card that happens to be transient,
      // so it takes the brief's `4px 4px 0 rgba(0,0,0,0.3)` like any other —
      // it was the one flat surface on the page that had no reason to be flat.
      // `AppCard` rather than `AppSurface`, because `AppSurface` has no shadow
      // parameter and adding one there is another agent's file.
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: _statusBannerEdge(color),
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

  /// The banner's own status hue, drawn on the glyph.
  ///
  /// **This field was passed by every call site and read by none** — the icon
  /// was rendered with no colour at all, so it took whatever the ambient
  /// `DefaultTextStyle` happened to be, and two banners showed two different
  /// retry glyphs. It is ink now, on the same rule as [_statusBannerEdge].
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
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.refresh, size: 18, color: color),
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
    return AppCard(
      padding: const EdgeInsets.all(12),
      border: _statusBannerEdge(statusAlert),
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
                      child: Text(
                        message,
                        style: AppType.bodySm.copyWith(color: appPrimaryText),
                      ),
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
      // **The radius, and why there is none left to name.** This used to be an
      // `AppSurface(radius: 10, ...)` — a literal 10 in a system whose
      // rectilinear radius is 8, which is 2px away from being right in a way
      // nothing can see and nothing can catch. `AppCard` draws its own
      // [AppRadius.card], so the second radius is simply gone rather than
      // corrected.
      //
      // On `AppCard` rather than `AppSurface` for the stamped shadow; the hue
      // goes through [_statusBannerEdge], on the rule that documents.
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: _statusBannerEdge(color),
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
            if (failed) RetryButton(onRetry: onRetry, color: color),
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
