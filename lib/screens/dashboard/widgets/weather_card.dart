import 'package:flutter/material.dart';

import '../../../services/weather_service.dart';
import '../../../widgets/liquid_glass.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({
    super.key,
    required this.weather,
    this.forecast,
    required this.isDark,
    this.performanceMode = true,
    this.onRefresh,
    this.onSettings,
    this.isLoading = false,
    this.error,
  });

  final WeatherData? weather;
  final WeatherForecast? forecast;
  final bool isDark;
  final bool performanceMode;
  final VoidCallback? onRefresh;
  final VoidCallback? onSettings;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final seedColor = colorScheme.primary;

    // Handle loading state
    if (isLoading) {
      return LiquidGlassCard(
        isDark: isDark,
        performanceMode: performanceMode,
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Handle error state
    if (error != null) {
      return LiquidGlassCard(
        isDark: isDark,
        performanceMode: performanceMode,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 24,
              color: colorScheme.error,
            ),
            const SizedBox(height: 6),
            Text(
              'Cuaca tidak tersedia',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    if (weather == null) {
      return _buildNoDataCard(context, colorScheme);
    }

    final weatherData = weather!;
    final isGoodForSolar = weatherData.isGoodForSolar;

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with location and condition
          Row(
            children: [
              Image.network(
                WeatherService.getIconUrl(weather!.icon),
                width: 32,
                height: 32,
                errorBuilder: (_, _, _) => Icon(
                  Icons.wb_sunny,
                  size: 24,
                  color: seedColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weather!.locationName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${weather!.condition} - ${weather!.description}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isGoodForSolar
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isGoodForSolar ? 'Bagus untuk Solar' : 'Kurang Optimal',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isGoodForSolar ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Refresh weather',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // All metrics in a single compact row
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Suhu',
                  value: '${weather!.temperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat,
                  color: colorScheme.tertiary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _WeatherMetric(
                  label: 'Kelembapan',
                  value: '${weather!.humidity.toStringAsFixed(0)}%',
                  icon: Icons.water_drop,
                  color: colorScheme.secondary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _WeatherMetric(
                  label: 'Angin',
                  value: '${weather!.windSpeed.toStringAsFixed(1)} m/s',
                  icon: Icons.air,
                  color: colorScheme.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _WeatherMetric(
                  label: 'Awan',
                  value: '${weather!.cloudCover.toStringAsFixed(0)}%',
                  icon: Icons.cloud,
                  color: colorScheme.outline,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 24,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            'Data Cuaca',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tambahkan API Key OpenWeatherMap di pengaturan',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.settings, size: 14),
            label: const Text('Buka Pengaturan'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}