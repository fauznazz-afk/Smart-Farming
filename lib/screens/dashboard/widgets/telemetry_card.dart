import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/color_helpers.dart';

/// Icon + title row used at the top of each detail page.
class GlassPageHeader extends StatelessWidget {
  const GlassPageHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Vertical list of key/value metrics for a single device, with a stale
/// telemetry notice when the device has not reported recently.
class TelemetryCard extends StatelessWidget {
  const TelemetryCard({
    super.key,
    required this.data,
    required this.metrics,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
    required this.staleMinutes,
  });

  final DeviceTelemetry? data;
  final List<MetricDef> metrics;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;
  final int staleMinutes;

  @override
  Widget build(BuildContext context) {
    final stale = data?.isStale(minutes: staleMinutes) ?? true;
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          if (stale) _StaleNotice(ageLabel: data?.ageLabel, isDark: isDark),
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricRow(
              metric: metrics[index],
              value: data?.latestValues[metrics[index].key],
              accent: metricColor(
                seedColor: seedColor,
                index: index,
                isDark: isDark,
              ),
              isDark: isDark,
            ),
            if (index < metrics.length - 1)
              GlassDivider(
                color: glassDividerColor(
                  isDark: isDark,
                  opacity: isDark ? 0.07 : 0.05,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.ageLabel, required this.isDark});

  final String? ageLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 15,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(width: 6),
          Text(
            ageLabel ?? 'No update received',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.value,
    required this.accent,
    required this.isDark,
  });

  final MetricDef metric;
  final double? value;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final unit = metric.unit;
    final displayValue = value == null
        ? (unit.isEmpty ? '--' : '-- $unit')
        : (unit.isEmpty ? value!.toStringAsFixed(2) : '${value!.toStringAsFixed(2)} $unit');
    return MergeSemantics(
      child: Semantics(
        label: '$metric: $displayValue',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(metric.icon, size: 19, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.label,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.87)
                        : Colors.black87,
                  ),
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline separator used between rows inside glass cards.
class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: color);
  }
}

/// Compact label/value pair used inside summary cards.
class GlassMetricRow extends StatelessWidget {
  const GlassMetricRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: '$label: $value',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large value over a caption, used under circular gauges.
class MiniMetric extends StatelessWidget {
  const MiniMetric({
    super.key,
    required this.value,
    required this.label,
    required this.isDark,
  });

  final String value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: '$label: $value',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
