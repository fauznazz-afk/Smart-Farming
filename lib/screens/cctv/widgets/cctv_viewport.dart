import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../widgets/liquid_glass.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../utils/cctv_status.dart';

/// Small status badge shown next to the CCTV header and in full screen.
class CctvStatusPill extends StatelessWidget {
  const CctvStatusPill({
    super.key,
    required this.status,
    this.isDark,
  });

  final CctvStatus status;

  /// Which side of the page the pill is drawn on.
  ///
  /// Null reads the app's theme, which is right for the embedded pill. The
  /// full-screen pill passes `true` explicitly, because it floats over the
  /// video, which is dark whatever the app's theme is doing — the contrast that
  /// matters here is against what is *behind* the text, not against the
  /// settings. Same null-means-read-from-context shape as `AppCard.isDark`.
  final bool? isDark;

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    // The dot keeps the status hue; the label uses the measured text colour.
    final dotColor = status.color;
    final textColor = status.textColor(dark);
    final label = status.label;
    return Semantics(
      label: 'CCTV status: ${label.toLowerCase()}',
      liveRegion: true,
      child: AppBadge(
        isDark: dark,
        color: textColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark 16:9 surface that stacks the web view under its state overlays.
///
/// Shared by the embedded and full screen layouts so the two can never drift.
class CctvViewport extends StatelessWidget {
  const CctvViewport({
    super.key,
    required this.controller,
    required this.status,
    required this.primary,
    required this.onStart,
    required this.onStop,
  });

  final WebViewController? controller;
  final CctvStatus status;
  final Color primary;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final webView = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (webView != null && status.showsVideo)
          // Isolated so a video frame only re-rasterises the video surface and
          // not the page display list around it. The overlays stay outside the
          // boundary: they change a handful of times per session but blend over
          // the video, so re-rasterising them on every frame would cost more
          // than the repaints this boundary avoids.
          RepaintBoundary(child: WebViewWidget(controller: webView)),
        if (status == CctvStatus.standby)
          CctvStandbyOverlay(primary: primary, onStart: onStart),
        if (status == CctvStatus.connecting) const CctvLoadingOverlay(),
        if (status == CctvStatus.offline)
          CctvErrorOverlay(onRetry: onStart, onBack: onStop),
      ],
    );
  }
}

/// Shown before playback starts, with the play button.
class CctvStandbyOverlay extends StatelessWidget {
  const CctvStandbyOverlay({
    super.key,
    required this.primary,
    required this.onStart,
  });

  final Color primary;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: -70,
          top: -110,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Decorative only — it sits behind the scrim and carries no
              // information, so it keeps its own low-alpha wash of the accent.
              color: primary.withValues(alpha: 0.09),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                  // `boundaryEdge` rather than `controlEdge`. An accent tint
                  // cannot be measured against a video frame of unknown
                  // luminance at all, and this circle is the one control the
                  // user has to find before anything is playing — it is the play
                  // button. So it takes the neutral edge that clears 3:1
                  // against the standby scrim it is drawn on, rather than the
                  // themed one that would be invisible on a bright frame.
                  border: Border.all(
                    color: AppElevation.boundaryEdge(isDark: true),
                  ),
                ),
                child: const Icon(
                  Icons.videocam_outlined,
                  size: 30,
                  // Over a `white @ 0.09` scrim on video, so this is a graphic
                  // and 3:1 is the requirement rather than 4.5:1. `white @ 0.70`
                  // over that scrim clears it comfortably; the value is left
                  // literal because it is compositing against an unknown
                  // backdrop, which is the one case a theme token cannot
                  // describe.
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Camera ready',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The stream does not run until you press Play',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play camera'),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dimmed spinner while the stream page loads.
class CctvLoadingOverlay extends StatelessWidget {
  const CctvLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // A `CircularProgressIndicator` is a repainting animation, and this overlay
    // sits on top of the `WebViewWidget`, which is itself inside its own
    // `RepaintBoundary`. That boundary keeps video frames off the page display
    // list but it does nothing for this overlay, so every frame of the spinner
    // invalidated the whole page's raster. Its own boundary means only this
    // 1x1 indicator re-rasters per frame.
    return const RepaintBoundary(
      child: ColoredBox(
        // Opaque rather than `black54`, because this scrim covers video: a
        // translucent dim over a bright frame leaves the spinner competing with
        // whatever is behind it, and this is the state where the user is waiting
        // and looking for the only sign that anything is happening.
        color: Color(0xCC0B100E),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

/// Shown when the stream page could not be loaded.
class CctvErrorOverlay extends StatelessWidget {
  const CctvErrorOverlay({
    super.key,
    required this.onRetry,
    required this.onBack,
  });

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Opaque, like the loading scrim above. This one carries text — the
      // failure message and two buttons — and a translucent scrim over video
      // means the text's contrast depends on the frame underneath it, which is
      // the one backdrop nobody can measure against.
      color: const Color(0xFF0B100E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white70,
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera could not be loaded',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
                TextButton(onPressed: onBack, child: const Text('Back')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular translucent icon button used for full screen and stop.
class CctvRoundControl extends StatelessWidget {
  const CctvRoundControl({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: Colors.white,
          icon: Icon(icon),
        ),
      ),
    );
  }
}
