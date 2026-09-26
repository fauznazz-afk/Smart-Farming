import 'package:flutter/material.dart';

import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';

/// A single environment reading card.
class _EnvSpec {
  const _EnvSpec(this.key, this.label, this.unit, this.icon);

  final String key;
  final String label;
  final String unit;
  final IconData icon;
}

const _envSpecs = [
  _EnvSpec('temp_dht', 'Ambient Temp', '°C', Icons.thermostat),
  _EnvSpec('humidity_dht', 'Humidity', '%', Icons.water_drop),
  _EnvSpec('temp_ds18b20', 'PV Temp', '°C', Icons.device_thermostat),
  _EnvSpec('lux', 'Illuminance', 'lx', Icons.light_mode),
  _EnvSpec('tds_ppm', 'TDS', 'ppm', Icons.science),
];

/// Grid of environment sensor readings (temperature, humidity, lux, TDS).
class EnvironmentGrid extends StatelessWidget {
  const EnvironmentGrid({
    super.key,
    required this.values,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
  });

  final Map<String, double>? values;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    Widget card(_EnvSpec spec) => Expanded(
      child: _EnvCard(
        spec: spec,
        value: values?[spec.key],
        isDark: isDark,
        seedColor: seedColor,
        performanceMode: performanceMode,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Environment',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            card(_envSpecs[0]),
            const SizedBox(width: 10),
            card(_envSpecs[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            card(_envSpecs[2]),
            const SizedBox(width: 10),
            card(_envSpecs[3]),
          ],
        ),
        const SizedBox(height: 10),
        _EnvCard(
          spec: _envSpecs[4],
          value: values?[_envSpecs[4].key],
          isDark: isDark,
          seedColor: seedColor,
          performanceMode: performanceMode,
        ),
      ],
    );
  }
}

class _EnvCard extends StatelessWidget {
  const _EnvCard({
    required this.spec,
    required this.value,
    required this.isDark,
    required this.seedColor,
    required this.performanceMode,
  });

  final _EnvSpec spec;
  final double? value;
  final bool isDark;
  final Color seedColor;
  final bool performanceMode;

  @override
  Widget build(BuildContext context) {
    final faint = isDark ? Colors.white54 : Colors.black45;
    return LiquidGlassCard(
      isDark: isDark,
      performanceMode: performanceMode,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                spec.icon,
                size: 16,
                color: metricColor(
                  seedColor: seedColor,
                  index: 3,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  spec.label,
                  style: TextStyle(fontSize: 11, color: faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value == null ? '--' : value!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(spec.unit, style: TextStyle(fontSize: 12, color: faint)),
            ],
          ),
        ],
      ),
    );
  }
}
