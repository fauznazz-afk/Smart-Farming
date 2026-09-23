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
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F6),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9E0E2), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * .10,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: Icon(
                Icons.wb_sunny,
                size: size * .48,
                color: primary,
              ),
            ),
          ),
          Positioned(
            bottom: size * .08,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Icon(
                Icons.eco,
                size: size * .62,
                color: secondary,
              ),
            ),
          ),
        ],
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
