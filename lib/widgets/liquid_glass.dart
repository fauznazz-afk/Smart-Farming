import '../screens/dashboard/utils/color_helpers.dart';
import 'dart:ui';

import 'package:flutter/material.dart';

// ── AmbientBackground ────────────────────────────────────────────────────────

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    required this.isDark,
  });

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: isDark
                    ? const Color(0xFF0D1410)
                    : const Color(0xFFF2F5F3),
              ),
              CustomPaint(painter: _AmbientOrbsPainter.of(isDark)),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientOrbsPainter extends CustomPainter {
  const _AmbientOrbsPainter({required this.isDark});

  final bool isDark;

  // One instance per brightness, reused for the lifetime of the app.
  //
  // This cannot be a `const` at the call site: `isDark` is a runtime field, and
  // a const constructor invocation requires compile-time constant arguments.
  // Caching the two instances instead means a dashboard rebuild — of which
  // there are seven distinct `setState` sites — stops allocating a painter it
  // will immediately discard. `shouldRepaint` compares `isDark` only, so
  // handing back the same instance for the same brightness is correct.
  static const _dark = _AmbientOrbsPainter(isDark: true);
  static const _light = _AmbientOrbsPainter(isDark: false);

  static _AmbientOrbsPainter of(bool isDark) => isDark ? _dark : _light;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      _drawOrb(
        canvas,
        size,
        center: Offset(size.width * 0.12, size.height * 0.10),
        radius: size.width * 0.60,
        color: const Color(0xFF66706B),
        centerAlpha: 0.70,
      );
      _drawOrb(
        canvas,
        size,
        center: Offset(size.width * 0.88, size.height * 0.28),
        radius: size.width * 0.50,
        color: const Color(0xFF7A827E),
        centerAlpha: 0.60,
      );
      _drawOrb(
        canvas,
        size,
        center: Offset(size.width * 0.55, size.height * 0.78),
        radius: size.width * 0.55,
        color: const Color(0xFF4F5954),
        centerAlpha: 0.50,
      );
    } else {
      _drawOrb(
        canvas,
        size,
        center: Offset(size.width * 0.08, size.height * 0.08),
        radius: size.width * 0.65,
        color: const Color(0xFFCBD2CE),
        centerAlpha: 0.65,
      );
      _drawOrb(
        canvas,
        size,
        center: Offset(size.width * 0.92, size.height * 0.22),
        radius: size.width * 0.52,
        color: const Color(0xFFDDE2DF),
        centerAlpha: 0.55,
      );
      _drawOrb(
        canvas,
        size,
        center: Offset(size.width * 0.45, size.height * 0.82),
        radius: size.width * 0.58,
        color: const Color(0xFFB8C1BC),
        centerAlpha: 0.50,
      );
    }
  }

  void _drawOrb(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
    required double centerAlpha,
  }) {
    final gradient = RadialGradient(
      colors: [
        color.withValues(alpha: centerAlpha),
        color.withValues(alpha: 0.0),
      ],
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AmbientOrbsPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

// ── LiquidGlassCard ──────────────────────────────────────────────────────────

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20.0,
    required this.isDark,
    this.performanceMode = true,
    this.tintColor,
    this.borderColor,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool isDark;
  final bool performanceMode;
  final Color? tintColor;

  /// Overrides the hairline border, used to outline a card that has crossed a
  /// limit. Null keeps the neutral border.
  final Color? borderColor;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final surface =
        tintColor ?? (isDark ? const Color(0xFF202020) : Colors.white);

    // The hairline follows the theme accent. It used to be a neutral white or
    // black, which meant a card in an amber theme had amber contents inside a
    // cold grey frame. `colorScheme.primary` is the tonal colour
    // `ColorScheme.fromSeed` derived from the user's pick, so it is guaranteed
    // to be legible on this surface — and reading it from the theme means no
    // call site has to pass a colour that could disagree with the one in use.
    final border = Border.all(
      width: 1.2,
      color:
          borderColor ??
          glassBorderColor(
            accent: Theme.of(context).colorScheme.primary,
            isDark: isDark,
          ),
    );

    final shadows = [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.38)
            : Colors.black.withValues(alpha: 0.07),
        blurRadius: 24,
        spreadRadius: -2,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.70),
        blurRadius: 1,
        offset: const Offset(0, -0.5),
      ),
    ];

    final radius = BorderRadius.circular(borderRadius);

    Widget result;

    if (performanceMode) {
      result = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    surface.withValues(alpha: 0.66),
                    surface.withValues(alpha: 0.46),
                  ]
                : [
                    surface.withValues(alpha: 0.64),
                    surface.withValues(alpha: 0.44),
                  ],
          ),
          borderRadius: radius,
          border: border,
          boxShadow: shadows,
        ),
        padding: padding,
        child: child,
      );
    } else {
      result = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.42),
              borderRadius: radius,
              border: border,
              boxShadow: shadows,
            ),
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    final card = RepaintBoundary(child: result);

    if (semanticLabel != null) {
      return Semantics(label: semanticLabel, container: true, child: card);
    }
    return card;
  }
}

// ── GlassDateChip ────────────────────────────────────────────────────────────

class GlassDateChip extends StatelessWidget {
  const GlassDateChip({
    super.key,
    required this.dayName,
    required this.dayNumber,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.accentColor = const Color(0xFF35A968),
    this.performanceMode = true,
    this.width = 48,
  });

  final String dayName;
  final int dayNumber;
  final bool isSelected, isDark, performanceMode;
  final Color accentColor;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final decoration = isSelected
        ? BoxDecoration(
            color: accentColor,
            border: Border.all(color: accentColor.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            borderRadius: BorderRadius.circular(14),
          )
        : BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.62),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            borderRadius: BorderRadius.circular(14),
          );

    return RepaintBoundary(
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: isSelected,
          label: '$dayName $dayNumber',
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: width,
              height: 68,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
              decoration: decoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 13,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (faintColor(isDark)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
