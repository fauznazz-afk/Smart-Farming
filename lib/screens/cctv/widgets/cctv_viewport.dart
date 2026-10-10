import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../widgets/liquid_glass.dart';
import '../../dashboard/utils/color_helpers.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../utils/cctv_status.dart';

/// Small status badge shown next to the CCTV header and in full screen.
class CctvStatusPill extends StatelessWidget {
  const CctvStatusPill({super.key, required this.status});

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
        // `AppBadge`'s own default padding *is* the brief's `badge-pill`
        // padding (8 x 4) and its default text style *is*
        // `label-uppercase-sm`, so neither is restated here. The label used to
        // carry a hand-written 9px/800/0.7 style that overrode both — a third
        // and fourth place choosing a size and a tracking.
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
            ExcludeSemantics(child: Text(label)),
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
        // `FittedBox` on the way down, because this column is taller than the
        // viewport at the largest text scales and a `Center` inside a `Stack`
        // reports the overflow as a yellow stripe over the video. `scaleDown`
        // shrinks it to fit rather than growing the box.
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Solid primary circle with onHue ink (FAB-circle style).
                //
                // **Flat, and the two blurred shadows are gone.** They were a
                // black 10px-blur offset plus a white 4px-blur highlight — the
                // soft-UI vocabulary the brief bans outright ("don't apply
                // blurred/soft shadows; the shadow language is hard, offset,
                // no-blur"). What gives this control its edge over arbitrary
                // camera pixels is `AppBorders.boundary`, which is the one edge
                // in the system that carries a 3:1 claim and the reason it is
                // kept here rather than swapped for a hairline.
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppPalette.primary,
                    shape: BoxShape.circle,
                    border: AppBorders.boundaryBorder,
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
                // The state headline, in the brief's `headline-md` slot — the
                // same treatment the error overlay's title takes, so the two
                // overlays read as one component rather than as two ad-hoc
                // captions. The hand-written 15px/700 it replaces was a fifth
                // size chosen in a widget.
                //
                // 20px inside a 16:9 panel is tight, and that is exactly what
                // the `FittedBox` guard is for: the overlay scales into the
                // panel rather than overflowing it.
                Text(
                  'Camera ready',
                  style: AppType.headlineMd.copyWith(
                    color: AppSurfaces.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The stream does not run until you press Play',
                  textAlign: TextAlign.center,
                  // 70% of white rather than the `0xB3FFFFFF` literal it was —
                  // the same colour, expressed through the token it is made of.
                  style: AppType.labelMicro.copyWith(
                    color: AppSurfaces.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                // The brief's `button-primary`, with `primary` taken from the
                // theme rather than from the palette so a test host can still
                // drive this widget with a colour of its own.
                // `onPrimaryInk(primary)` rather than a hard-coded ink.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.all(AppRadius.card),
                    boxShadow: AppShadows.stampedIn(primary),
                  ),
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Play camera'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: onPrimaryInk(primary),
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
              ],
            ),
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
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
              color: AppSurfaces.onSurface,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'Camera could not be loaded',
              // `headline-md`, the same slot the standby overlay's title takes.
              // The bare `TextStyle(color: white)` it replaces inherited the
              // framework's 14px body default, which is a label size for what
              // is the whole point of this state.
              style: AppType.headlineMd.copyWith(color: AppSurfaces.onSurface),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                // The brief's `button-secondary`. Over video the page fill is
                // still the right one — it is darker than the surrounding
                // chrome and it reads as a control rather than as a second
                // panel.
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppSurfaces.page,
                    foregroundColor: AppSurfaces.onSurface,
                    side: AppBorders.hairline,
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
                // The brief's `button-text`: transparent, primary ink,
                // `label-uppercase-sm`. Inlined rather than shared, because
                // reaching into `settings/widgets/settings_fields.dart` for a
                // button style would make the CCTV module depend on the
                // settings one, and the two have nothing to do with each other.
                TextButton(
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.primary,
                    textStyle: AppType.labelMicro,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.all(AppRadius.card),
                    ),
                  ),
                  child: const Text('Back'),
                ),
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
          // A scrim, not a shadow: this control floats over arbitrary camera
          // pixels, so the gradient is there to give the white glyph a floor to
          // sit on regardless of what is behind it.
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.7,
            colors: [
              AppSurfaces.onSurface.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0.55),
            ],
          ),
          // **`AppBorders.boundary`, not white at 15%.** A 1.5px near-white
          // edge is the one border in the system that carries WCAG 1.4.11's 3:1
          // for a UI component boundary, and this is exactly the case it exists
          // for: nothing tonal can promise a visible edge over a bright frame.
          // The 15% white it replaced measured nowhere near that, so this is
          // strengthening the claim rather than changing it.
          border: AppBorders.boundaryBorder,
          // The blurred 8px drop shadow is gone with the brief's ban on blur.
          // What separates the control from the video is the radial gradient
          // plus this boundary; a soft halo over a live feed reads as a smudge.
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: AppSurfaces.onSurface,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
