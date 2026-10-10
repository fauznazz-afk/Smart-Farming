import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../widgets/liquid_glass.dart';
import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../utils/cctv_status.dart';

/// Small status badge shown next to the CCTV header and in full screen.
class CctvStatusPill extends StatelessWidget {
  const CctvStatusPill({
    super.key,
    required this.status,
  });

  final CctvStatus status;

  @override
  Widget build(BuildContext context) {
    // The dot keeps the status hue; the label uses the measured text colour.
    final dotColor = status.color;
    final textColor = status.textColor;
    final label = status.label;
    return Semantics(
      label: 'CCTV status: ${label.toLowerCase()}',
      liveRegion: true,
      child: AppBadge(
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
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Solid primary circle with onHue ink (FAB-circle style)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  shape: BoxShape.circle,
                  border: AppBorders.boundaryBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onStart,
                    child: const Center(
                      child: Icon(
                        Icons.videocam_outlined,
                        size: 30,
                        color: AppPalette.onHue,
                      ),
                    ),
                  ),
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
                  foregroundColor: onPrimaryInk(primary),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.7,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0.55),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: Colors.white,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
