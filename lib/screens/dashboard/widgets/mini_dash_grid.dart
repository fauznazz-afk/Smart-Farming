/// Compact metric card for MiniDash layout.
///
/// Large bold value with trend indicator, 2-column grid layout,
/// 8px gaps, no heavy shadows, 150ms subtle fades.
library;

import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// A compact metric widget showing a large value with trend.
///
/// Used in 2-column grids on MiniDash layout.
class MiniDashMetric extends StatelessWidget {
  const MiniDashMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.alert = false,
  });

  /// The metric label (e.g., "VOLTAGE", "SOC").
  final String label;

  /// The large bold value (e.g., "48.2", "85%").
  final String value;

  /// Optional unit shown smaller beside value.
  final String? unit;

  /// Optional trend indicator: "↑", "↓", "→" or null.
  final String? trend;

  /// Whether the value is in an alert/breach state.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: AppSurfaces.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: alert
              ? AppPalette.error.withValues(alpha: 0.7)
              : AppSurfaces.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label: uppercase, muted
            Text(
              label.toUpperCase(),
              style: AppType.labelMicro.copyWith(
                color: AppSurfaces.onSurfaceVariant,
                letterSpacing: 0.08 * 10,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Value row: large bold number + optional unit + trend
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Large bold value
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: AppType.numeralLg.copyWith(
                        color: alert ? AppPalette.error : AppSurfaces.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: AppType.labelMicro.copyWith(
                      color: AppSurfaces.onSurfaceVariant,
                    ),
                  ),
                ],
                if (trend != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: switch (trend!) {
                        '↑' || '↑↑' => AppPalette.statusBad, // increasing bad for some
                        '↓' || '↓↓' => AppPalette.statusBad,
                        '→' => AppSurfaces.onSurfaceVariant,
                        _ => AppSurfaces.onSurfaceVariant,
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A 2-column grid of [MiniDashMetric] widgets.
///
/// Compact layout with 8px gap between columns and rows.
class MiniDashGrid extends StatelessWidget {
  const MiniDashGrid({
    super.key,
    required this.metrics,
    this.columnGap = 8,
    this.rowGap = 8,
  });

  /// List of metric widgets to display in 2-column grid.
  final List<Widget> metrics;

  /// Horizontal gap between columns (default 8px).
  final double columnGap;

  /// Vertical gap between rows (default 8px).
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    // Distribute metrics into pairs for 2-column layout
    final pairs = <List<Widget>>[];
    for (var i = 0; i < metrics.length; i += 2) {
      if (i + 1 < metrics.length) {
        pairs.add([metrics[i], metrics[i + 1]]);
      } else {
        pairs.add([metrics[i], const SizedBox.shrink()]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final pair in pairs)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pair[0]),
              SizedBox(width: columnGap),
              Expanded(child: pair[1]),
            ],
          ),
      ],
    );
  }
}

/// Variant with wrapped Flow layout for flexible column counts.
class MiniDashFlow extends StatelessWidget {
  const MiniDashFlow({
    super.key,
    required this.metrics,
    this.columnCount = 2,
    this.columnGap = 8,
    this.rowGap = 8,
  });

  /// List of metric widgets to display.
  final List<Widget> metrics;

  /// Number of columns (default 2).
  final int columnCount;

  /// Gap between columns.
  final double columnGap;

  /// Gap between rows.
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[];
    for (var i = 0; i < metrics.length; i += columnCount) {
      final row = <Widget>[];
      for (var j = 0; j < columnCount && i + j < metrics.length; j++) {
        row.add(Expanded(
          child: metrics[i + j],
        ));
        if (j < columnCount - 1 && i + j < metrics.length) {
          row.add(SizedBox(width: columnGap));
        }
      }
      rows.add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: row,
          ),
          if (row != rows.last) SizedBox(height: rowGap),
        ],
      ],
    );
  }
}