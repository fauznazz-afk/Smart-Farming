import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import 'telemetry_card.dart';

/// Snapshot values shown on the battery half of the status pair.
typedef BatteryStatus = ({double soc, double voltage, double current});

/// Snapshot values shown on the AC half of the status pair.
typedef AcStatus = ({
  double voltage,
  double current,
  double power,
  double frequency,
});

/// Side-by-side battery and AC summary cards on the overview page.
class DualStatusCards extends StatelessWidget {
  const DualStatusCards({
    super.key,
    required this.battery,
    required this.ac,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
    required this.onNavigate,
  });

  final BatteryStatus battery;
  final AcStatus ac;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final isStable = (ac.frequency - 50).abs() < 2 &&
        ac.voltage > 200 &&
        ac.voltage < 240;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Shortcut(
              pageIndex: 3,
              onNavigate: onNavigate,
              child: _BatteryCard(
                status: battery,
                isDark: isDark,
                seedColor: seedColor,
                performanceMode: performanceMode,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Shortcut(
              pageIndex: 2,
              onNavigate: onNavigate,
              child: _AcCard(
                status: ac,
                isStable: isStable,
                isDark: isDark,
                seedColor: seedColor,
                performanceMode: performanceMode,
              ),
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

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({
    required this.status,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
  });

  final BatteryStatus status;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CardTitle(
            icon: Icons.battery_charging_full,
            label: 'Battery',
            color: metricColor(seedColor: seedColor, index: 0, isDark: isDark),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          GlassCircularGauge(
            progress: status.soc / 100,
            centerLabel: '${status.soc.toStringAsFixed(0)}%',
            centerSubLabel: 'SOC',
            trackColor: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.07),
            progressColor: seedColor,
            size: 100,
            strokeWidth: 10,
            semanticLabel:
                'Battery State of Charge: ${status.soc.toStringAsFixed(0)} percent',
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              MiniMetric(
                value: '${status.voltage.toStringAsFixed(1)} V',
                label: 'Voltage',
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 28,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12),
              ),
              MiniMetric(
                value: '${status.current.toStringAsFixed(2)} A',
                label: 'Current',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcCard extends StatelessWidget {
  const _AcCard({
    required this.status,
    required this.isStable,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
  });

  final AcStatus status;
  final bool isStable;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.power,
            label: 'AC Grid',
            color: metricColor(seedColor: seedColor, index: 2, isDark: isDark),
            isDark: isDark,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isStable ? Colors.green : Colors.red).withValues(
                  alpha: 0.18,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isStable ? 'Stable' : 'Unstable',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isStable ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GlassMetricRow(
            label: 'Voltage',
            value: '${status.voltage.toStringAsFixed(1)} V',
            isDark: isDark,
          ),
          GlassDivider(color: glassDividerColor(isDark: isDark)),
          GlassMetricRow(
            label: 'Current',
            value: '${status.current.toStringAsFixed(2)} A',
            isDark: isDark,
          ),
          GlassDivider(color: glassDividerColor(isDark: isDark)),
          GlassMetricRow(
            label: 'Power',
            value: '${status.power.toStringAsFixed(0)} W',
            isDark: isDark,
          ),
          GlassDivider(color: glassDividerColor(isDark: isDark)),
          GlassMetricRow(
            label: 'Frequency',
            value: '${status.frequency.toStringAsFixed(1)} Hz',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}
