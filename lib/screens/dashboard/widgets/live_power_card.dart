import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';

/// Hero card: live PV power, battery SOC gauge, and three quick shortcuts.
class LivePowerCard extends StatelessWidget {
  const LivePowerCard({
    super.key,
    required this.pvPower,
    required this.acPower,
    required this.soc,
    required this.pzemStale,
    required this.pzemAgeLabel,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
    required this.onNavigate,
  });

  final double? pvPower;
  final double acPower;
  final double soc;
  final bool pzemStale;
  final String? pzemAgeLabel;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(pzemStale: pzemStale, ageLabel: pzemAgeLabel, isDark: isDark, seedColor: seedColor),
          const SizedBox(height: 12),
          _ValueRow(
            pvPower: pvPower,
            soc: soc,
            isDark: isDark,
            seedColor: seedColor,
          ),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Shortcut(
                    pageIndex: 1,
                    onNavigate: onNavigate,
                    child: GlassCapsule(
                      label: 'PV Output',
                      value: pvPower?.toStringAsFixed(0) ?? '--',
                      unit: 'W',
                      accentColor: themeColor(
                        seedColor: seedColor,
                        lightness: isDark ? 0.72 : 0.42,
                      ),
                      progress: ((pvPower ?? 0) / 300).clamp(0.0, 1.0),
                      isDark: isDark,
                      performanceMode: performanceMode,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Shortcut(
                    pageIndex: 2,
                    onNavigate: onNavigate,
                    child: GlassCapsule(
                      label: 'AC Load',
                      value: acPower.toStringAsFixed(0),
                      unit: 'W',
                      accentColor: themeColor(
                        seedColor: seedColor,
                        lightness: isDark ? 0.64 : 0.36,
                        saturation: 0.48,
                      ),
                      progress: (acPower / 2000).clamp(0.0, 1.0),
                      isDark: isDark,
                      performanceMode: performanceMode,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Shortcut(
                    pageIndex: 3,
                    onNavigate: onNavigate,
                    child: GlassCapsule(
                      label: 'Battery',
                      value: soc.toStringAsFixed(0),
                      unit: '%',
                      accentColor: seedColor,
                      progress: soc / 100,
                      isDark: isDark,
                      performanceMode: performanceMode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.pageIndex,
    required this.onNavigate,
    required this.child,
  });

  final int pageIndex;
  final ValueChanged<int> onNavigate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onNavigate(pageIndex),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pzemStale,
    required this.ageLabel,
    required this.isDark,
    required this.seedColor,
  });

  final bool pzemStale;
  final String? ageLabel;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.wb_sunny_rounded,
          size: 18,
          color: metricColor(seedColor: seedColor, index: 2, isDark: isDark),
        ),
        const SizedBox(width: 6),
        Text(
          'Live Active Power',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const Spacer(),
        if (pzemStale)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 4),
              Text(
                ageLabel ?? 'No update',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.pvPower,
    required this.soc,
    required this.isDark,
    required this.seedColor,
  });

  final double? pvPower;
  final double soc;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final faint = isDark ? Colors.white54 : Colors.black45;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Semantics(
                    label: pvPower == null
                        ? 'PV output power unavailable'
                        : 'PV output: ${pvPower!.toStringAsFixed(0)} watts',
                    child: Text(
                      pvPower == null ? '--' : pvPower!.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Text('W', style: TextStyle(fontSize: 20, color: faint)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('PV Output', style: TextStyle(fontSize: 12, color: faint)),
            ],
          ),
        ),
        GlassCircularGauge(
          progress: soc / 100,
          centerLabel: '${soc.toStringAsFixed(0)}%',
          centerSubLabel: 'SOC',
          trackColor: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          progressColor: seedColor,
          size: 90,
          strokeWidth: 9,
          semanticLabel:
              'Battery State of Charge: ${soc.toStringAsFixed(0)} percent',
        ),
      ],
    );
  }
}
