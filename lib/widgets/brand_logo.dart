import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showName;

  const BrandLogo({super.key, this.size = 52, this.showName = false});

  @override
  Widget build(BuildContext context) {
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
            top: size * .14,
            child: Icon(
              Icons.wb_sunny,
              size: size * .48,
              color: const Color(0xFFEFA13E),
            ),
          ),
          Positioned(
            bottom: size * .1,
            right: size * .12,
            child: Icon(
              Icons.eco,
              size: size * .62,
              color: const Color(0xFF35A968),
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
          text: const TextSpan(
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            children: [
              TextSpan(
                text: 'Ener',
                style: TextStyle(color: Color(0xFFEFA13E)),
              ),
              TextSpan(
                text: 'Grow',
                style: TextStyle(color: Color(0xFF35A968)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
