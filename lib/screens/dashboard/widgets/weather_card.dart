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
    // Handle loading state
    if (isLoading) {
      return LiquidGlassCard(
        isDark: isDark,
        performanceMode: performanceMode,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 32,
              color: isDark ? Colors.orange : Colors.deepOrange,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuaca tidak tersedia',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (weather == null) {
      return _buildNoDataCard();
    }

    final weatherData = weather!;
    final isGoodForSolar = weatherData.isGoodForSolar;

    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Image.network(
                WeatherService.getIconUrl(weather!.icon),
                width: 40,
                height: 40,
                errorBuilder: (_, _, _) => Icon(
                  Icons.wb_sunny,
                  size: 32,
                  color: isDark ? Colors.amber : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather!.locationName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${weather!.condition} - ${weather!.description}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGoodForSolar
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGoodForSolar ? 'Bagus untuk Solar' : 'Kurang Optimal',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isGoodForSolar ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                tooltip: 'Refresh weather',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Main metrics
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Suhu',
                  value: '${weather!.temperature.toStringAsFixed(1)}°C',
                  icon: Icons.thermostat,
                  color: isDark ? Colors.red : Colors.redAccent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeatherMetric(
                  label: 'Kelembapan',
                  value: '${weather!.humidity.toStringAsFixed(0)}%',
                  icon: Icons.water_drop,
                  color: isDark ? Colors.blue : Colors.blueAccent,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WeatherMetric(
                  label: 'Angin',
                  value: '${weather!.windSpeed.toStringAsFixed(1)} m/s',
                  icon: Icons.air,
                  color: isDark ? Colors.cyan : Colors.cyanAccent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeatherMetric(
                  label: 'Awan',
                  value: '${weather!.cloudCover.toStringAsFixed(0)}%',
                  icon: Icons.cloud,
                  color: isDark ? Colors.grey : Colors.grey,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Solar irradiance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.amber : Colors.amber).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark ? Colors.amber : Colors.amber).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wb_sunny,
                  color: isDark ? Colors.amber : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Iradiansi Matahari',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${weather!.solarIrradiance.toStringAsFixed(0)} W/m²',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.amber : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            value: weather!.solarProductionFactor,
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.amber : Colors.orange,
                            ),
                            backgroundColor: (isDark ? Colors.amber : Colors.amber)
                                .withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${(weather!.solarProductionFactor * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.amber : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Forecast summary
          // TODO: Add forecast when available
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            size: 32,
            color: isDark ? Colors.amber : Colors.orange,
          ),
          const SizedBox(height: 8),
          Text(
            'Data Cuaca',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan API Key OpenWeatherMap di pengaturan untuk melihat data cuaca',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Buka Pengaturan'),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}