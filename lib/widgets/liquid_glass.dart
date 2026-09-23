import 'dart:math' as math;
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
        ColoredBox(
          color: isDark ? const Color(0xFF0D1410) : const Color(0xFFF2F5F3),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _AmbientOrbsPainter(isDark: isDark),
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
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool isDark;
  final bool performanceMode;
  final Color? tintColor;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final surface =
        tintColor ?? (isDark ? const Color(0xFF202020) : Colors.white);

    final border = Border.all(
      width: 1.2,
      color: isDark
          ? Colors.white.withValues(alpha: 0.13)
          : Colors.white.withValues(alpha: 0.85),
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
                    surface.withValues(alpha: 0.82),
                    surface.withValues(alpha: 0.62),
                  ]
                : [
                    surface.withValues(alpha: 0.72),
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
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.55),
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

    return RepaintBoundary(child: result);
  }
}

// ── GlassCapsule ─────────────────────────────────────────────────────────────

class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    required this.progress,
    required this.isDark,
    this.performanceMode = true,
  });

  final String label, value, unit;
  final Color accentColor;
  final double progress;
  final bool isDark, performanceMode;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3.5,
              backgroundColor: accentColor.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── GlassCircularGauge ───────────────────────────────────────────────────────

class GlassCircularGauge extends StatelessWidget {
  const GlassCircularGauge({
    super.key,
    required this.progress,
    required this.centerLabel,
    this.centerSubLabel = '',
    required this.trackColor,
    required this.progressColor,
    this.size = 80.0,
    this.strokeWidth = 8.0,
    this.centerWidget,
  });

  final double progress, size, strokeWidth;
  final String centerLabel, centerSubLabel;
  final Color trackColor, progressColor;
  final Widget? centerWidget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size(size, size),
              painter: _GaugePainter(
                progress: progress,
                trackColor: trackColor,
                progressColor: progressColor,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
          centerWidget ??
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: TextStyle(
                      fontSize: size * 0.19,
                      fontWeight: FontWeight.w800,
                      color: progressColor,
                      height: 1.1,
                    ),
                  ),
                  if (centerSubLabel.isNotEmpty)
                    Text(
                      centerSubLabel,
                      style: TextStyle(
                        fontSize: size * 0.12,
                        fontWeight: FontWeight.w600,
                        color: progressColor.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress, strokeWidth;
  final Color trackColor, progressColor;

  static const double _startAngle = -math.pi * 0.8;
  static const double _sweepAngle = math.pi * 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final clampedProgress = progress.clamp(0.0, 1.0);

    if (clampedProgress > 0) {
      // Progress arc
      canvas.drawArc(
        rect,
        _startAngle,
        _sweepAngle * clampedProgress,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      // Glow tip
      final tipAngle = _startAngle + _sweepAngle * clampedProgress;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );

      // Glow halo
      canvas.drawCircle(
        tip,
        strokeWidth * 0.65,
        Paint()
          ..color = progressColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Bright core
      canvas.drawCircle(
        tip,
        strokeWidth * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}

// ── GlassDateChip ─────────────────────────────────────────────────────────────

class GlassDateChip extends StatelessWidget {
  const GlassDateChip({
    super.key,
    required this.dayName,
    required this.dayNumber,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.performanceMode = true,
  });

  final String dayName;
  final int dayNumber;
  final bool isSelected, isDark, performanceMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.10);
    final decoration = isSelected
        ? BoxDecoration(
            color: selectedColor,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 78,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: decoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
