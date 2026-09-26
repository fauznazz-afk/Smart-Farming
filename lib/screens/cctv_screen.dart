import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/cctv_url.dart';
import 'cctv/utils/cctv_status.dart';
import 'cctv/widgets/cctv_viewport.dart';

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
  static const _pageBackground = Color(0xFF080D0A);

  WebViewController? _controller;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  CctvStatus get _status =>
      cctvStatusOf(playing: _playing, loading: _loading, failed: _failed);

  @override
  void initState() {
    super.initState();
    if (!widget.fullScreen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enterImmersiveMode();
      _startStream();
    });
  }

  @override
  void dispose() {
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
              parseAllowedCctvUrl(request.url) == null
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
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
              tooltip: 'Tutup layar penuh',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: CctvStatusPill(status: _status),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbedded(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                      borderRadius: BorderRadius.circular(14),
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
                  'Pantau area secara langsung',
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
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
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
                            tooltip: 'Layar penuh',
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
        const SizedBox(height: 12),
        _InfoBar(
          isDark: isDark,
          primary: primary,
          isPlaying: _playing,
          showReload: _playing && !_loading,
          onReload: _controller?.reload,
        ),
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

/// Explanatory text below the player, with a reload action while live.
class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.isDark,
    required this.primary,
    required this.isPlaying,
    required this.showReload,
    required this.onReload,
  });

  final bool isDark;
  final Color primary;
  final bool isPlaying;
  final bool showReload;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B211E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
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
              isPlaying
                  ? 'Stream aktif menggunakan koneksi internet.'
                  : 'Tekan Play saat Anda siap melihat kamera.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (showReload && onReload != null)
            IconButton(
              tooltip: 'Muat ulang kamera',
              visualDensity: VisualDensity.compact,
              onPressed: onReload,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}
