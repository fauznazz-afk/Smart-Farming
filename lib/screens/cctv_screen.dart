import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/cctv_url.dart';
import '../services/secure_window.dart';
import '../theme/app_theme_of.dart';
import 'cctv/utils/cctv_status.dart';
import 'cctv/widgets/cctv_viewport.dart';
import 'dashboard/utils/design_tokens.dart';

/// The matte the video is seen against. **Not a themed surface, and never to
/// become one.**
///
/// This is the most-argued-about colour in the app, and `FEATURE.md` §18.0
/// item 4 records it as undecided. It is decided, and the decision is that the
/// *frame* changes and the *matte* does not.
///
/// **Why the fill cannot be `AppSurfaces.page(isDark)`.** A dim image against a
/// light surround reads brighter and loses shadow detail, which is why
/// broadcast and cinema put video on black. Measured rather than assumed, with
/// a representative dim greenhouse frame as the content:
///
/// | content            | on this ground | on the light page |
/// |--------------------|----------------|-------------------|
/// | `#202824`          | **1.30:1**     | 12.05:1           |
/// | `#404844`          | 2.08:1         | 7.52:1            |
/// | `#141816` (payload)| **1.09:1**     | 14.29:1           |
///
/// On a light panel the surround is 12x brighter than the frame and 14x
/// brighter than the dark detail inside it. The eye adapts to the surround, the
/// surround becomes the reference, and the image flattens into it. Daylight
/// does not rescue this: ambient light changes neither number, because the ratio
/// that matters is internal to the panel.
///
/// The last row is the one that settles it. What a user opens this screen for
/// is *is the equipment box open, is there water on the floor, did anything
/// move* — a judgement about dark regions. Putting the brightest thing in the
/// panel immediately outside the darkest thing the user is looking for is the
/// wrong way round, and it is the same failure `AppElevation.inset` has
/// documented all along: a well needs an interior darker than its surround, and
/// this interior is already at the bottom of the range.
///
/// **A light bezel was rejected for the same reason, more expensively.** Putting
/// a themed band between the page and the video would make the panel a card
/// *and* keep a bright surround hard against the frame — the naive fix's whole
/// defect in a smaller footprint. Costed on the 381dp content column recorded
/// in `FEATURE.md` §18.0 item 5: a 6dp bezel is 6.2 % less video, 8dp is
/// 8.2 %, 12dp is 12.2 %. Paying real image area to make the camera look worse
/// is the trade this comment exists to prevent.
///
/// **What was actually wrong, then.** The fill was never the defect; the
/// absence of a shadow was. This panel was the only surface in the app painted
/// with no `boxShadow` at all, and in a style where depth is carried *entirely*
/// by the dual shadow pair, a shape with no shadow whose fill is 15.62:1 from
/// the page is a hole by definition. Adding [AppElevation.raised] costs no
/// video area and puts the panel on the same footing as every card around it.
///
/// **Dark mode: nothing to fix, and the same call is still correct.** Measured
/// against `AppSurfaces.pageDark`, this ground is **1.19:1** — the panel is
/// already effectively the page, so there is no hole and no cliff. The raised
/// pair still applies, and does much less, because a black shadow on a near-black
/// surface is a small relative move. Stated rather than left implicit, because
/// "the dark-mode fix is the absence of a fix" is the kind of thing that gets
/// read as an oversight.
///
/// **No border.** WCAG 1.4.11 is already satisfied by the fill at 15.62:1,
/// five times the 3:1 it asks for, and `AppElevation.hairline` cannot be reused
/// here even if it were needed: that constant is `0x99FFFFFF`, tuned to be a
/// 1.25:1 whisper on the page, and it measures **19.58:1** on this matte. The
/// same constant means opposite things on the two fills, and the wrong one of
/// those meanings is a drawn white rim, which is the failure
/// `design_tokens.dart` says soft UI exists to remove.
///
/// The value is already a very dark neutral carrying the page's own green
/// cast — `g-r` is 5/255 here against 6/255 on `pageLight` — so "a very dark
/// neutral derived from the page's hue" was, in effect, already what shipped.
/// Lifting it would cost the perceived contrast above and buy nothing.
///
/// The same colour is the WebView's own background, and has to stay identical
/// to it: that is what the go2rtc page paints as its letterbox, so a mismatch
/// would put a second rectangle inside this one.
const Color cctvVideoGround = Color(0xFF080D0A);

/// Web view player for the go2rtc stream page.
///
/// The stream is never started automatically unless [fullScreen] is set, so
/// the embedded view does not consume bandwidth while the user browses other
/// dashboard tabs.
class CctvScreen extends StatefulWidget {
  const CctvScreen({super.key, required this.streamUrl, this.fullScreen = false});

  final String streamUrl;

  /// Locks to landscape and hides system bars, starting playback immediately.
  final bool fullScreen;

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  /// The WebView's own background. See [cctvVideoGround]: the video's matte and
  /// the panel's fill have to be the same colour, because this is what the
  /// go2rtc page paints its letterbox in, and a mismatch would put a second
  /// rectangle inside this one.
  static const _pageBackground = cctvVideoGround;

  WebViewController? _controller;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  CctvStatus get _status =>
      cctvStatusOf(playing: _playing, loading: _loading, failed: _failed);

  @override
  void initState() {
    super.initState();
    // **Set in `initState`, not `build`.** A camera feed that the user can
    // screenshot, screen-record, or find in the Recents thumbnail is the whole
    // finding: this screen exists to answer "is the equipment box open, is
    // there water on the floor", and the thumbnail alone answers it to anyone
    // who can see the launcher. Applying it in `build` would also mean the flag
    // is reasserted on every frame, which hides a failure to set it at all.
    unawaited(SecureWindow.acquire());
    if (!widget.fullScreen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enterImmersiveMode();
      _startStream();
    });
  }

  @override
  void dispose() {
    // Released, or the rest of the app inherits it: a flag left set is an app
    // the user cannot screenshot anywhere, including screens where that is the
    // wrong answer.
    unawaited(SecureWindow.release());
    if (widget.fullScreen) _exitImmersiveMode();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CctvScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl && _playing) {
      _startStream();
    }
  }

  static void _enterImmersiveMode() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void _exitImmersiveMode() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _startStream() {
    final streamUri = parseAllowedCctvUrl(widget.streamUrl);
    if (streamUri == null) {
      setState(() {
        _playing = true;
        _loading = false;
        _failed = true;
        _controller = null;
      });
      return;
    }

    setState(() {
      _playing = true;
      _loading = true;
      _failed = false;
    });
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_pageBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          // The stream page is the only host we allow, so the web view cannot
          // be navigated off the official camera origin.
          onNavigationRequest: (request) =>
                  // The *loose* guard, not `parseAllowedCctvUrl`. These are the
                  // page's own navigations, not the user's stored setting, and
                  // go2rtc navigates internally -- pinning the path here refused
                  // the player itself, which is what a strict guard on this
                  // callback is for. Same origin, nothing else.
                  isAllowedCctvNavigation(Uri.parse(request.url))
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      );
    setState(() => _controller = controller);
    controller.loadRequest(streamUri);
  }

  void _stopStream() {
    setState(() {
      _controller = null;
      _playing = false;
      _loading = false;
      _failed = false;
    });
  }

  void _openFullScreen() {
    // Release the embedded player first; the full screen route opens its own.
    _stopStream();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CctvScreen(streamUrl: widget.streamUrl, fullScreen: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) return _buildFullScreen(context);
    return _buildEmbedded(context);
  }

  Widget _buildFullScreen(BuildContext context) {
    return Scaffold(
      // Pure black, and `Colors.black` rather than `cctvVideoGround` on
      // purpose. This route is the strongest case for a dark surround rather
      // than the weakest: there is no page behind it, the system bars are
      // hidden, and no app chrome is visible at all, so there is nothing for the
      // panel to belong to and nothing to integrate with. It is also the one
      // place the perceived-contrast argument costs nothing to honour, because
      // honouring it is what the user came here for.
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildViewport(context),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: CctvRoundControl(
              icon: Icons.close_rounded,
              tooltip: 'Exit full screen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            // Over the video, so the dark set regardless of the app's theme.
            // `AppTheme.dark` rather than the resolved theme: what matters to a
            // pill floating over camera frames is that it is on the dark half of
            // the ramp, and the frames have nothing to do with Dracula's palette.
            child: CctvStatusPill(status: _status, theme: AppTheme.dark),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbedded(BuildContext context) {
    final theme = Theme.of(context);
    // `appThemeOf` rather than a brightness comparison. The panel's shadow and
    // the info bar's fill are both ramp-dependent, and Dracula hands
    // `MaterialApp` [ThemeMode.dark], so `isDark` here would be identical for
    // Dracula and for the app's own dark theme and the panel would be lit by
    // the wrong shadow pair. This screen has no controller, so the context is
    // what it has.
    final appTheme = appThemeOf(context);
    final primary = theme.colorScheme.primary;
    final status = _status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.all(AppRadius.tile),
                    ),
                    child: Icon(Icons.videocam_rounded, color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'CCTV Monitoring',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  CctvStatusPill(status: status),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 54, top: 4),
                child: Text(
                  'Watch the area live',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.66,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // The panel's frame, and the whole of the fix.
        //
        // It was a bare `ClipRRect` around a `ColoredBox` with **no shadow at
        // all**, which made it the only surface in the app that carried no depth
        // cue. On the light page that reads as a hole rather than as an object,
        // and the reason is the missing shadow rather than the fill: this app
        // expresses depth exclusively through the dual shadow pair, so a shape
        // with no shadow is by definition a cut in the page and not a block on
        // it. `cctvVideoGround` documents why the fill stays what it is and why
        // the naive alternative (make the panel the page colour) was rejected
        // with measurements — the short version is that a light surround puts
        // the page 12x brighter than the frame and 14x brighter than the dark
        // detail the user opened this screen to look at.
        //
        // `raised`, not `inset`, and the choice is forced by the fill rather than
        // preferred: an inset well is expressed by darkening its interior below
        // its surround, and there is nothing left to give — the strongest value
        // the light inset pair can put on this matte measures 1.20:1. A well here
        // would collapse, so the panel is a block standing on the page, which is
        // also what a monitor on a desk is.
        //
        // The shadow is painted on the *page*, outside this rect, which is the
        // only part of it the matte does not swallow: light mode drops the page
        // from luminance 0.788 to 0.381 at the contact shadow, and dark mode
        // gets the same pair over `#1A211F`.
        //
        // `AppRadius.pill`, not a literal `22`. The value is unchanged — 22 is
        // what shipped, and it is also the pill radius — so this is a
        // de-duplication rather than a restyle, and the panel keeps the one
        // radius in the scale meant to read as a separate physical object.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.all(AppRadius.pill),
            boxShadow: AppElevation.raised(appTheme),
          ),
          // The clip stays *inside* the decorated box rather than outside it.
          // `ClipRRect` would cut the shadow off at the rect it clips, so a
          // single outer `ClipRRect` — which is what this used to be — cannot
          // carry a `boxShadow` at all. Nesting is the only arrangement where
          // both survive.
          //
          // The platform view is untouched by this: the same `ClipRRect` ->
          // `AspectRatio` -> `ColoredBox` -> `Stack` chain still wraps
          // `CctvViewport`, and `CctvViewport` still owns the `RepaintBoundary`
          // around the `WebViewWidget`. Nothing here is animated, blended or
          // clipped per frame, so video frames continue to re-rasterise only
          // the boundary that already isolated them.
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.pill),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: _pageBackground,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildViewport(context),
                    if (status == CctvStatus.live)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          children: [
                            CctvRoundControl(
                              icon: Icons.fullscreen_rounded,
                              tooltip: 'Full screen',
                              onPressed: _openFullScreen,
                            ),
                            const SizedBox(width: 8),
                            CctvRoundControl(
                              icon: Icons.stop_rounded,
                              tooltip: 'Stop stream',
                              onPressed: _stopStream,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // **Only while the stream is running, and this bar was on screen in every
        // state until an emulator screenshot showed what it looks like.**
        //
        // In the idle state the viewport already says "Camera ready", "The stream
        // does not run until you press Play" and offers a "Play camera" button.
        // Directly beneath that, this bar said "Press Play when you are ready to
        // watch the camera." Three renderings of one fact, stacked, with the
        // redundant one in a bordered box that reads as a notice.
        //
        // That is the same failure `AGENTS.md` records twice already: a permanent
        // element asserting a condition that is boring when true, permanently
        // occupying the space where a real warning needs to go. A user who has not
        // pressed Play has not done anything wrong, and the bar framed it as
        // something they needed to be told.
        //
        // While playing it earns its place for two reasons that are not its text:
        // it is the Reload button's home, and a dropped HLS stream is the one
        // failure on this screen with no other recovery control.
        if (_playing) ...[
          const SizedBox(height: 12),
          _InfoBar(
            theme: appTheme,
            primary: primary,
            showReload: !_loading,
            onReload: _controller?.reload,
          ),
        ],
      ],
    );
  }

  Widget _buildViewport(BuildContext context) {
    return CctvViewport(
      controller: _controller,
      status: _status,
      primary: Theme.of(context).colorScheme.primary,
      onStart: _startStream,
      onStop: _stopStream,
    );
  }
}

/// The bar under a **running** stream: what it is, and the Reload action.
///
/// Only built while playing. In the idle and error states the viewport above says
/// the same thing better and offers its own control, so a second copy here was
/// three renderings of one fact stacked vertically.
class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.theme,
    required this.primary,
    required this.showReload,
    required this.onReload,
  });

  /// The appearance to paint. An [AppTheme] rather than a `bool` because the
  /// bar's fill is [AppSurfaces.chrome], which has a Dracula step of its own —
  /// Dracula's "current line" is a *lighter* surface than the app's dark chrome,
  /// and it is the bar that is supposed to separate from the page by fill, so
  /// taking the dark one there would have flattened exactly the edge this bar
  /// exists to draw.
  final AppTheme theme;
  final Color primary;

  /// Reload is hidden while the stream page is loading, so the action cannot
  /// appear for a stream that is not up yet.
  final bool showReload;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    // `textTheme`, not `theme`: the field named `theme` is the [AppTheme] this
    // bar paints with, and a local `theme` for the Material `ThemeData` would
    // shadow it — which is a silent, type-checked-nothing bug rather than a
    // compile error only because the two names are different types.
    final textTheme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Was a hand-picked `0xFF1B211E` in dark and pure `Colors.white` in
        // light. `AppSurfaces.chrome` is the surface that has to separate from
        // the page by fill rather than by shadow, which is what this is: a bar
        // under the player, with a Reload button in it.
        color: AppSurfaces.chrome(theme),
        borderRadius: AppRadius.all(AppRadius.card),
        // Was `white | black @ 0.06`, which measures 1.14:1 on the fill. The bar
        // sits under a viewport-sized video and holds a Reload button, so its
        // edge is a component boundary, which WCAG 1.4.11 wants at 3:1.
        //
        // `boundaryEdge`, not `controlEdge`, and the difference is measured
        // rather than stylistic. `controlEdge` is a tint of the accent, and the
        // light accent `0xFF35A968` is only 2.70:1 at full opacity on the light
        // page — so no alpha of it can reach 3:1, and this bar would have sat at
        // 1.54:1. `boundaryEdge` is a neutral at 3.04:1, which is what WCAG
        // 1.4.11 asks for, and it is worth a grey line on this one control: the
        // bar is the only thing separating the video panel above it from the
        // Reload button, and it abuts a matte rather than a themed card, so the
        // boundary has to hold on its own rather than being carried by a shared
        // fill.
        border: Border.all(color: AppElevation.boundaryEdge(theme: theme)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // **Unconditional, and the bar is only built while playing.** The
              // idle wording this replaced lived here permanently, under a viewport
              // that was already saying the same thing; the whole fix was to stop
              // building the bar, and the branch went with it. Leaving a dead
              // branch behind would invite someone to restore the bar and the
              // message together.
              'The stream is running on an internet connection.',
              style: textTheme.textTheme.bodySmall,
            ),
          ),
          if (showReload && onReload != null)
            IconButton(
              tooltip: 'Reload camera',
              visualDensity: VisualDensity.compact,
              onPressed: onReload,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}


