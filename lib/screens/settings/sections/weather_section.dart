import 'package:flutter/material.dart';

import '../settings_controller.dart';

/// OpenWeatherMap API key, optional city override, and a connection test.
class WeatherSection extends StatelessWidget {
  const WeatherSection({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationName = settings.weatherLocationName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: settings.weatherApiKey,
          decoration: const InputDecoration(
            labelText: 'OpenWeatherMap API Key',
            prefixIcon: Icon(Icons.key),
            helperText: 'Get your free API key from openweathermap.org/api',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: settings.weatherCity,
          decoration: const InputDecoration(
            labelText: 'City name (optional)',
            prefixIcon: Icon(Icons.location_city),
            helperText: 'Leave blank to use GPS location',
          ),
        ),
        const SizedBox(height: 16),
        if (locationName != null) ...[
          Text(
            'Current location: $locationName',
            style: theme.textTheme.bodyMedium,
          ),
          if (_hasCoordinates) ...[
            Text(
              'Coordinates: '
              '${settings.weatherLatitude!.toStringAsFixed(4)}, '
              '${settings.weatherLongitude!.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: settings.weatherLoading
              ? null
              : settings.testWeatherConnection,
          icon: settings.weatherLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync),
          label: Text(
            settings.weatherLoading ? 'Testing...' : 'Test Connection',
          ),
        ),
        if (settings.weatherError case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  bool get _hasCoordinates =>
      settings.weatherLatitude != null && settings.weatherLongitude != null;
}
