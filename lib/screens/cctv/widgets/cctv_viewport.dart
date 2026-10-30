import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../widgets/liquid_glass.dart';
import '../../dashboard/utils/design_tokens.dart';
import '../utils/cctv_status.dart';

/// The opaque scrim both video overlays paint.
///
/// **Public, and shared by the two overlays, because it is the surface their
/// ink has to be measured against.** The loading scrim was `0xCC` of it and the
/// error scrim opaque; they differ only in that one alpha and a test cannot
/// assert a contrast claim against a value it has to copy out of a widget tree.
///
/// It is a very dark neutral on purpose and it never inverts with the theme:
/// the overlays cover camera pixels, and their whole job is to be independent
/// of what is behind them.
const Color cctvOverlayScrim = Color(0xFF0B100E);

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
        // **A play button and nothing else, at the user's request.** This used
        // to be a `FittedBox` around a column: a *camera* glyph in an accent
        // circle, the headline "Camera ready", the sentence "The stream does not
        // run until you press Play", and a `FilledButton` labelled "Play camera".
        // Four things saying one thing, and the glyph on the circle was a camera
        // rather than a play triangle, so the control that starts the stream did
        // not look like the control that starts the stream.
        //
        // What replaces it is that one circle, and the glyph inside is the same
        // `play_arrow_rounded` the button was drawing - so removing the button
        // removed a duplicate rather than the affordance. The `FittedBox` went
        // with it: it existed only because a heading and two sentences made the
        // column taller than a 16:9 panel, and one fixed-size circle cannot.
        //
        // The label did not disappear with the text; it moved into `Semantics`.
        // An unlabelled 68 dp circle is a button with no name.
        Center(
          child: Semantics(
            button: true,
            label: 'Play camera',
            excludeSemantics: true,
            child: Container(
              // Solid accent circle with onHue ink (FAB-circle style).
              //
              // **Flat, and the two blurred shadows are gone.** They were a
              // black blurred offset plus a white blurred highlight — depth from
              // a light source, which this system does not have. What gives this
              // control its edge over arbitrary camera pixels is
              // `AppBorders.boundary`, the one edge in the system that carries a
              // 3:1 claim.
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppPalette.accent,
                shape: BoxShape.circle,
                border: AppBorders.boundaryBorder,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onStart,
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 32,
                      color: AppPalette.onHue,
                    ),
                  ),
                ),
              ),
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
        //
        // **80% of [cctvOverlayScrim], the one place the two overlays differ.**
        // The white spinner is the same in both.
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
      color: cctvOverlayScrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_rounded,
              // **White, because the scrim under it is the one backdrop nobody
              // can measure against.** The scrim is a near-black neutral, so the
              // ink has to be the one that does not follow the palette — card ink
              // and page ink both answer the app's own surfaces, and this is not
              // one of them.
              color: AppGlass.ink,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'Camera could not be loaded',
              // `headline-md`, the same slot the standby overlay's title takes.
              // The bare `TextStyle(color: white)` it replaces inherited the
              // framework's 14px body default, which is a label size for what
              // is the whole point of this state.
              style: AppType.headlineMd.copyWith(color: AppGlass.ink),
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
                    backgroundColor: cctvOverlayScrim,
                    // The same correction as the glyph: card ink on this fill is
                    // 1.25:1, so "Retry" was an outline around nothing.
                    foregroundColor: AppGlass.ink,
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
                    // **White, not the accent.** The scrim is a near-black
                    // neutral, so the accent would sit on a ground it was never
                    // measured against. The step this system already owns for a
                    // dark ground is the hero's white ink.
                    foregroundColor: AppGlass.ink,
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
          // sit on regardless of what is behind it. The centre stop is a *white*
          // lift at 12%; a dark tint at that alpha over black would be a colour
          // with no name and no effect.
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.7,
            colors: [
              AppGlass.inkStrong.withValues(alpha: 0.12),
              Colors.black.withValues(alpha: 0.55),
            ],
          ),
          // **`AppBorders.boundary`, not white at 15%.** A 1.5px near-white
          // edge is the one border in the system that carries WCAG 1.4.11's 3:1
          // for a UI component boundary, and this is exactly the case it exists
          // for: nothing tonal can promise a visible edge over a bright frame.
          border: AppBorders.boundaryBorder,
          // **No shadow.** What separates the control from the video is the
          // radial gradient plus this boundary; a halo over a live feed reads as
          // a smudge, and a shadow that has to work over arbitrary camera pixels
          // cannot promise anything the boundary does not.
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            // **White, because the floor under it is a black radial gradient.**
            // The claim this control exists to make is WCAG 1.4.11's 3:1 over
            // arbitrary video, and card ink on that floor would be
            // near-black-on-near-black — only the boundary edge would carry it.
            color: AppGlass.inkStrong,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
