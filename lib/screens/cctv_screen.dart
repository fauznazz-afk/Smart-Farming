import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/cctv_url.dart';

class CctvScreen extends StatefulWidget {
  final String streamUrl;
  final bool active;

  const CctvScreen({super.key, required this.streamUrl, this.active = true});

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _scheduleWebViewInitialization();
  }

  @override
  void didUpdateWidget(covariant CctvScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _controller == null) {
      _scheduleWebViewInitialization();
    }
  }

  void _scheduleWebViewInitialization() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && _controller == null) {
        _initializeWebView();
      }
    });
  }

  void _initializeWebView() {
    final streamUri = parseAllowedCctvUrl(widget.streamUrl);
    if (streamUri == null) {
      _failed = true;
      setState(() => _loading = false);
      return;
    }
    _failed = false;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            return parseAllowedCctvUrl(request.url) == null
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
          child: Text(
            'CCTV Monitoring',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(letterSpacing: 1.1),
          ),
        ),
        SizedBox(
          height: 300,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!)
                else
                  const Center(child: CircularProgressIndicator()),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_failed)
                  Center(
                    child: FilledButton.icon(
                      onPressed: _controller?.reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload camera'),
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
