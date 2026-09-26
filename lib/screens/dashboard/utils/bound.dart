import 'package:flutter/material.dart';

/// A widget that rebuilds when a [Listenable] notifies, with token-based
/// rebuild control to avoid unnecessary rebuilds when the visual theme changes.
class Bound extends StatefulWidget {
  const Bound({
    super.key,
    required this.listenable,
    required this.token,
    required this.builder,
  });

  final Listenable listenable;
  final Object token;
  final Widget Function() builder;

  @override
  State<Bound> createState() => _BoundState();
}

class _BoundState extends State<Bound> {
  late Widget _child;

  @override
  void initState() {
    super.initState();
    _child = widget.builder();
    widget.listenable.addListener(_refresh);
  }

  @override
  void didUpdateWidget(Bound oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_refresh);
      widget.listenable.addListener(_refresh);
      _child = widget.builder();
    } else if (oldWidget.token != widget.token) {
      _child = widget.builder();
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    _child = widget.builder();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => _child;
}