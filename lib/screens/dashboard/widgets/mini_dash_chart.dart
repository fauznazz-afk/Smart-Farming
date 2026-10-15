/// Compact chart card for MiniDash layout.
///
/// Full-width chart with subtle styling, minimal shadows,
/// 150ms transitions for data updates.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// Compact full-width chart for MiniDash dashboard.
///
/// Simplified chart with reduced padding, minimal animations,
/// and clean typography suitable for compact grids.
class MiniDashChartCard extends StatelessWidget {
  const MiniDashChartCard({
    super.key,
    required this.title,
    required this.series,
    required this.unit,
    required this.value,
    this.minValue,
    this.maxValue,
    this.trend,
    this.color,
    this.height = 120,
  });

  /// Chart title (e.g., "PV Power", "Battery SOC").
  final String title;

  /// Chart data series.
  final List<FlSpot> series;

  /// Unit for the Y-axis values.
  final String unit;

  /// Current/latest value to display.
  final String value;

  /// Optional minimum value for Y-axis.
  final double? minValue;

  /// Optional maximum value for Y-axis.
  final double? maxValue;

  /// Optional trend indicator.
  final String? trend;

  /// Chart line color (defaults to accent).
  final Color? color;

  /// Chart height (default 120dp compact).
  final double height;

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? AppPalette.error;
    final lineData = _buildLineData(series, lineColor);

    return AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: AppSurfaces.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppSurfaces.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: title + value
            Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppType.labelMicro.copyWith(
                    color: AppSurfaces.onSurfaceVariant,
                    letterSpacing: 0.08 * 10,
                  ),
                ),
                const Spacer(),
                // Large bold value
                Text(
                  value,
                  style: AppType.numeralLg.copyWith(
                    color: AppSurfaces.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: AppType.labelMicro.copyWith(
                      color: AppSurfaces.onSurfaceVariant,
                    ),
                  ),
                ],
                if (trend != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: switch (trend!) {
                        '↑' || '↑↑' => AppPalette.statusBad,
                        '↓' || '↓↓' => AppPalette.statusBad,
                        _ => AppSurfaces.onSurfaceVariant,
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Compact chart
            SizedBox(
              height: height,
              child: LineChart(lineData),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineData(List<FlSpot> spots, Color lineColor) {
    if (spots.isEmpty) {
      return LineChartData();
    }

    // Calculate bounds
    final values = spots.map((s) => s.y).toList();
    final minY = minValue ?? (values.isNotEmpty ? values.reduce((a, b) => a < b ? a : b) : 0);
    final maxY = maxValue ?? (values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 100);
    final rangeY = maxY - minY;
    final safeMinY = rangeY > 0 ? minY - rangeY * 0.1 : minY - 10;
    final safeMaxY = rangeY > 0 ? maxY + rangeY * 0.1 : maxY + 10;

    return LineChartData(
      minX: spots.first.x,
      maxX: spots.last.x,
      minY: safeMinY,
      maxY: safeMaxY,
      gridData: FlGridData(
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: (safeMaxY - safeMinY) / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppSurfaces.border.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 2,
          color: lineColor,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: lineColor.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

/// Compact multi-series chart for MiniDash.
class MiniDashMultiChartCard extends StatelessWidget {
  const MiniDashMultiChartCard({
    super.key,
    required this.title,
    required this.seriesList,
    this.height = 140,
  });

  final String title;
  final List<({String name, List<FlSpot> spots, Color color})> seriesList;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lineData = _buildMultiLineData();

    return AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: AppSurfaces.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppSurfaces.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title.toUpperCase(),
              style: AppType.labelMicro.copyWith(
                color: AppSurfaces.onSurfaceVariant,
                letterSpacing: 0.08 * 10,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Compact chart
            SizedBox(
              height: height,
              child: LineChart(lineData),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Legend row
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final series in seriesList) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: series.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                series.name,
                style: AppType.labelMicro.copyWith(
                  color: AppSurfaces.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ],
    );
  }

  LineChartData _buildMultiLineData() {
    if (seriesList.isEmpty) {
      return LineChartData();
    }

    // Calculate combined bounds
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double minX = double.infinity;
    double maxX = double.negativeInfinity;

    for (final series in seriesList) {
      for (final spot in series.spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
        if (spot.x < minX) minX = spot.x;
        if (spot.x > maxX) maxX = spot.x;
      }
    }

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 100;
    if (minX == double.infinity) minX = 0;
    if (maxX == double.negativeInfinity) maxX = 1;

    final rangeY = maxY - minY;
    final safeMinY = rangeY > 0 ? minY - rangeY * 0.1 : minY - 10;
    final safeMaxY = rangeY > 0 ? maxY + rangeY * 0.1 : maxY + 10;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: safeMinY,
      maxY: safeMaxY,
      gridData: FlGridData(
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: (safeMaxY - safeMinY) / 4,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppSurfaces.border.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        for (final series in seriesList)
          LineChartBarData(
            spots: series.spots,
            isCurved: true,
            barWidth: 2,
            color: series.color,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: series.color.withValues(alpha: 0.08),
            ),
          ),
      ],
    );
  }
}