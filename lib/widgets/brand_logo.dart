import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final Color? accentColor;
  final Color? secondaryColor;

  const BrandLogo({
    super.key,
    this.size = 52,
    this.showName = false,
    this.accentColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = accentColor ?? const Color(0xFFEFA13E);
    final secondary = secondaryColor ?? const Color(0xFF35A968);
    final mark = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/energrow_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Logo EnerGrow',
      ),
    );

    if (!showName) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            children: [
              TextSpan(
                text: 'Ener',
                style: TextStyle(color: primary),
              ),
              TextSpan(
                text: 'Grow',
                style: TextStyle(color: secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
