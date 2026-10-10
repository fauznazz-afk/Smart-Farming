import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

/// Icon + title row used at the top of each detail page.
class GlassPageHeader extends StatelessWidget {
  const GlassPageHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppBorders.categoricalWash(accent),
            border: AppBorders.categoricalBorder(accent),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppType.numeralLg.copyWith(color: appPrimaryText),
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
    required this.staleMinutes,
  });

  final DeviceTelemetry? data;
  final List<MetricDef> metrics;
  final int staleMinutes;

  @override
  Widget build(BuildContext context) {
    final stale = data?.isStale(minutes: staleMinutes) ?? true;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          if (stale) _StaleNotice(ageLabel: data?.ageLabel),
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricRow(
              metric: metrics[index],
              value: data?.latestValues[metrics[index].key],
              accent: categoryColorForKey(metrics[index].key) ?? AppPalette.primary,
            ),
            if (index < metrics.length - 1) const AppDivider(),
          ],
        ],
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.ageLabel});

  final String? ageLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 15,
            color: faintColor,
          ),
          const SizedBox(width: 6),
          Text(
            ageLabel ?? 'No update received',
            style: AppType.labelMicro.copyWith(color: faintColor),
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
  });

  final MetricDef metric;
  final double? value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final unit = metric.unit;
    final decimals = metric.decimals;
    final displayValue = value == null
        ? (unit.isEmpty ? '--' : '-- $unit')
        : (unit.isEmpty
              ? value!.toStringAsFixed(decimals)
              : '${value!.toStringAsFixed(decimals)} $unit');
    return MergeSemantics(
      child: Semantics(
        label: '${metric.label}: $displayValue',
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
                  style: AppType.labelUppercase.copyWith(color: appPrimaryText),
                ),
              ),
              Text(
                displayValue,
                style: AppType.numeralLg.copyWith(color: appPrimaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}