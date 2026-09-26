import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/services/weather_service.dart';

void main() {
  group('WeatherData.fromJson (current weather)', () {
    test('parses a complete current-weather payload', () {
      final json = {
        'main': {'temp': 25.5, 'humidity': 65.0, 'pressure': 1013.0},
        'wind': {'speed': 3.5, 'deg': 180.0},
        'clouds': {'all': 20.0},
        'weather': [
          {
            'main': 'Clouds',
            'description': 'few clouds',
            'icon': '02d',
          }
        ],
        'dt': 1700000000,
        'name': 'Palembang',
        'coord': {'lat': -2.99, 'lon': 104.75},
      };

      final data = WeatherData.fromJson(json);

      expect(data.temperature, 25.5);
      expect(data.humidity, 65.0);
      expect(data.pressure, 1013.0);
      expect(data.windSpeed, 3.5);
      expect(data.windDirection, 180.0);
      expect(data.cloudCover, 20.0);
      expect(data.condition, 'Clouds');
      expect(data.description, 'few clouds');
      expect(data.icon, '02d');
      expect(data.locationName, 'Palembang');
      expect(data.latitude, -2.99);
      expect(data.longitude, 104.75);
      expect(data.timestamp, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
    });

    test('handles missing wind deg', () {
      final json = {
        'main': {'temp': 20.0, 'humidity': 50.0, 'pressure': 1015.0},
        'wind': {'speed': 2.0},
        'clouds': {'all': 0.0},
        'weather': [
          {'main': 'Clear', 'description': 'clear sky', 'icon': '01d'}
        ],
        'dt': 1700000000,
        'name': 'Test',
        'coord': {'lat': 0.0, 'lon': 0.0},
      };

      final data = WeatherData.fromJson(json);
      expect(data.windDirection, 0.0);
    });

    test('solar irradiance is zero at night', () {
      final json = {
        'main': {'temp': 20.0, 'humidity': 50.0, 'pressure': 1015.0},
        'wind': {'speed': 2.0, 'deg': 0.0},
        'clouds': {'all': 0.0},
        'weather': [
          {'main': 'Clear', 'description': 'clear sky', 'icon': '01n'}
        ],
        'dt': 1699993200,
        'name': 'Test',
        'coord': {'lat': 0.0, 'lon': 0.0},
      };

      final data = WeatherData.fromJson(json);
      expect(data.solarIrradiance, 0.0);
    });

    test('solar irradiance is positive at noon with clear sky', () {
      final dt = DateTime(2026, 11, 15, 12, 0);
      final json = {
        'main': {'temp': 30.0, 'humidity': 40.0, 'pressure': 1010.0},
        'wind': {'speed': 1.0, 'deg': 90.0},
        'clouds': {'all': 0.0},
        'weather': [
          {'main': 'Clear', 'description': 'clear sky', 'icon': '01d'}
        ],
        'dt': dt.millisecondsSinceEpoch ~/ 1000,
        'name': 'Test',
        'coord': {'lat': 0.0, 'lon': 0.0},
      };

      final data = WeatherData.fromJson(json);
      expect(data.solarIrradiance, greaterThan(0));
      expect(data.isGoodForSolar, isTrue);
    });
  });

  group('WeatherData.fromOneCallJson (One Call API)', () {
    test('parses hourly entry with scalar temp', () {
      final json = {
        'dt': 1700000000,
        'temp': 22.5,
        'feels_like': 21.0,
        'pressure': 1012,
        'humidity': 70,
        'clouds': 10,
        'wind_speed': 4.0,
        'wind_deg': 200,
        'weather': [
          {'main': 'Clouds', 'description': 'few clouds', 'icon': '02d'}
        ],
      };

      final data = WeatherData.fromOneCallJson(json);

      expect(data.temperature, 22.5);
      expect(data.humidity, 70.0);
      expect(data.pressure, 1012.0);
      expect(data.windSpeed, 4.0);
      expect(data.windDirection, 200.0);
      expect(data.cloudCover, 10.0);
      expect(data.condition, 'Clouds');
      expect(data.description, 'few clouds');
      expect(data.icon, '02d');
      expect(data.timestamp, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
    });

    test('parses daily entry with temp object and uses day temperature', () {
      final json = {
        'dt': 1700000000,
        'temp': {
          'day': 26.0,
          'min': 20.0,
          'max': 30.0,
          'night': 22.0,
          'eve': 27.0,
          'morn': 21.0,
        },
        'pressure': 1013,
        'humidity': 60,
        'clouds': 5,
        'wind_speed': 3.0,
        'wind_deg': 180,
        'weather': [
          {'main': 'Clear', 'description': 'clear sky', 'icon': '01d'}
        ],
      };

      final data = WeatherData.fromOneCallJson(json);

      expect(data.temperature, 26.0);
      expect(data.humidity, 60.0);
      expect(data.pressure, 1013.0);
      expect(data.windSpeed, 3.0);
      expect(data.windDirection, 180.0);
      expect(data.cloudCover, 5.0);
    });

    test('handles missing optional fields gracefully', () {
      final json = {
        'dt': 1700000000,
        'temp': 20.0,
      };

      final data = WeatherData.fromOneCallJson(json);

      expect(data.temperature, 20.0);
      expect(data.humidity, 0.0);
      expect(data.pressure, 0.0);
      expect(data.windSpeed, 0.0);
      expect(data.windDirection, 0.0);
      expect(data.cloudCover, 0.0);
      expect(data.condition, '');
      expect(data.description, '');
      expect(data.icon, '01d');
    });

    test('handles missing weather list', () {
      final json = {
        'dt': 1700000000,
        'temp': 20.0,
        'weather': [],
      };

      final data = WeatherData.fromOneCallJson(json);
      expect(data.condition, '');
      expect(data.icon, '01d');
    });
  });

  group('WeatherForecast.fromJson', () {
    test('parses complete One Call payload', () {
      final json = {
        'lat': -2.99,
        'lon': 104.75,
        'timezone': 'Asia/Jakarta',
        'hourly': [
          {
            'dt': 1700000000,
            'temp': 25.0,
            'humidity': 65,
            'pressure': 1013,
            'clouds': 20,
            'wind_speed': 3.5,
            'wind_deg': 180,
            'weather': [
              {'main': 'Clouds', 'description': 'few clouds', 'icon': '02d'}
            ],
          },
          {
            'dt': 1700003600,
            'temp': 26.0,
            'humidity': 60,
            'pressure': 1012,
            'clouds': 10,
            'wind_speed': 4.0,
            'wind_deg': 190,
            'weather': [
              {'main': 'Clear', 'description': 'clear sky', 'icon': '01d'}
            ],
          },
        ],
        'daily': [
          {
            'dt': 1700000000,
            'temp': {
              'day': 28.0,
              'min': 22.0,
              'max': 32.0,
              'night': 24.0,
              'eve': 29.0,
              'morn': 23.0,
            },
            'humidity': 55,
            'pressure': 1011,
            'clouds': 15,
            'wind_speed': 2.5,
            'wind_deg': 170,
            'weather': [
              {'main': 'Clouds', 'description': 'scattered clouds', 'icon': '03d'}
            ],
          },
        ],
      };

      final forecast = WeatherForecast.fromJson(json);

      expect(forecast.locationName, 'Asia/Jakarta');
      expect(forecast.latitude, -2.99);
      expect(forecast.longitude, 104.75);
      expect(forecast.hourly.length, 2);
      expect(forecast.daily.length, 1);

      expect(forecast.hourly[0].temperature, 25.0);
      expect(forecast.hourly[1].temperature, 26.0);

      expect(forecast.daily[0].temperature, 28.0);
    });

    test('handles empty hourly and daily lists', () {
      final json = {
        'lat': 0.0,
        'lon': 0.0,
        'timezone': 'UTC',
        'hourly': [],
        'daily': [],
      };

      final forecast = WeatherForecast.fromJson(json);
      expect(forecast.hourly, isEmpty);
      expect(forecast.daily, isEmpty);
    });
  });

  group('WeatherData serialization', () {
    test('toJson round-trips through fromCache', () {
      final original = WeatherData(
        temperature: 25.0,
        humidity: 60.0,
        pressure: 1013.0,
        windSpeed: 3.0,
        windDirection: 180.0,
        cloudCover: 20.0,
        solarIrradiance: 500.0,
        condition: 'Clouds',
        description: 'few clouds',
        icon: '02d',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        locationName: 'Palembang',
        latitude: -2.99,
        longitude: 104.75,
      );

      final json = original.toJson();
      final restored = WeatherData.fromCache(json);

      expect(restored.temperature, original.temperature);
      expect(restored.humidity, original.humidity);
      expect(restored.pressure, original.pressure);
      expect(restored.windSpeed, original.windSpeed);
      expect(restored.windDirection, original.windDirection);
      expect(restored.cloudCover, original.cloudCover);
      expect(restored.solarIrradiance, original.solarIrradiance);
      expect(restored.condition, original.condition);
      expect(restored.description, original.description);
      expect(restored.icon, original.icon);
      expect(restored.locationName, original.locationName);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });

    test('toJson produces valid JSON encodable structure', () {
      final data = WeatherData.fromOneCallJson({
        'dt': 1700000000,
        'temp': 22.5,
        'humidity': 70,
        'pressure': 1012,
        'wind_speed': 4.0,
        'wind_deg': 200,
        'clouds': 10,
        'weather': [
          {'main': 'Clouds', 'description': 'few clouds', 'icon': '02d'}
        ],
      });

      final json = data.toJson();
      final encoded = jsonEncode(json);
      expect(encoded, contains('22.5'));
      expect(encoded, contains('Clouds'));
    });
  });

  group('WeatherData computed properties', () {
    test('iconUrl returns correct URL', () {
      final data = WeatherData.fromOneCallJson({
        'dt': 1700000000,
        'temp': 20.0,
        'weather': [
          {'main': 'Rain', 'description': 'light rain', 'icon': '10d'}
        ],
      });
      expect(data.iconUrl, 'https://openweathermap.org/img/wn/10d@2x.png');
    });

    test('solarProductionFactor is 0 when irradiance is 0', () {
      final data = WeatherData.fromOneCallJson({
        'dt': 1700000000,
        'temp': 20.0,
      });
      expect(data.solarIrradiance, 0.0);
      expect(data.solarProductionFactor, 0.0);
    });

    test('solarProductionFactor normalizes correctly', () {
      final dt = DateTime(2026, 11, 15, 12, 0);
      final data = WeatherData.fromOneCallJson({
        'dt': dt.millisecondsSinceEpoch ~/ 1000,
        'temp': 30.0,
        'clouds': 0,
      });
      expect(data.solarIrradiance, greaterThan(0));
      expect(data.solarProductionFactor, greaterThan(0));
      expect(data.solarProductionFactor, lessThanOrEqualTo(1.0));
    });
  });
}
