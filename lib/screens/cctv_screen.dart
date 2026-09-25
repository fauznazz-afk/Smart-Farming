import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/cctv_url.dart';

class CctvScreen extends StatefulWidget {
  final String streamUrl;
  final bool active;
  final bool fullScreen;

  const CctvScreen({
    super.key,
    required this.streamUrl,
    this.active = true,
    this.fullScreen = false,
  });

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  WebViewController? _controller;
  bool _playing = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.fullScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _startStream();
      });
    }
  }

  @override
  void dispose() {
    if (widget.fullScreen) {
      SystemChrome.setPreferredOrientations(const []);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CctvScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl && _playing) {
      _startStream();
    }
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
      ..setBackgroundColor(const Color(0xFF080D0A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    if (widget.fullScreen) return _fullScreenView();

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
                  _statusPill(isDark),
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
            child: Container(
              width: double.infinity,
              color: const Color(0xFF080D0A),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_controller != null && _playing)
                    WebViewWidget(controller: _controller!),
                  if (!_playing) _standby(primary),
                  if (_loading && _playing)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.56),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  if (_failed) _errorOverlay(),
                  if (_playing && !_loading && !_failed)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        children: [
                          _roundControl(
                            icon: Icons.fullscreen_rounded,
                            tooltip: 'Layar penuh',
                            onPressed: _openFullScreen,
                          ),
                          const SizedBox(width: 8),
                          _roundControl(
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B211E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
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
                  _playing
                      ? 'Stream aktif menggunakan koneksi internet.'
                      : 'Tekan Play saat Anda siap melihat kamera.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (_playing && !_loading)
                IconButton(
                  tooltip: 'Muat ulang kamera',
                  visualDensity: VisualDensity.compact,
                  onPressed: _controller?.reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fullScreenView() => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller != null && _playing)
                  WebViewWidget(controller: _controller!),
                if (!_playing) _standby(Theme.of(context).colorScheme.primary),
                if (_loading && _playing)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                if (_failed) _errorOverlay(),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: _roundControl(
            icon: Icons.close_rounded,
            tooltip: 'Tutup layar penuh',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(top: 16, left: 16, child: _statusPill(true)),
      ],
    ),
  );

  void _openFullScreen() {
    _stopStream();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CctvScreen(streamUrl: widget.streamUrl, fullScreen: true),
      ),
    );
  }

  Widget _statusPill(bool isDark) {
    final color = _failed
        ? const Color(0xFFFF765E)
        : _playing && !_loading
        ? const Color(0xFF58D68D)
        : const Color(0xFFFFC857);
    final label = _failed
        ? 'OFFLINE'
        : _playing && !_loading
        ? 'LIVE'
        : _playing
        ? 'CONNECTING'
        : 'STANDBY';
    return Semantics(
      label: 'CCTV status: ${label.toLowerCase()}',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 6),
            ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
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

  Widget _standby(Color primary) => Stack(
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(
                Icons.videocam_outlined,
                size: 30,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kamera siap ditampilkan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stream tidak berjalan sebelum Anda menekan Play',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startStream,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play kamera'),
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

  Widget _errorOverlay() => ColoredBox(
    color: Colors.black.withValues(alpha: 0.82),
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
            'Kamera tidak dapat dimuat',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _startStream,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
              TextButton(onPressed: _stopStream, child: const Text('Kembali')),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _roundControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => Semantics(
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
