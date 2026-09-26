import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

/// Weather data model
class WeatherData {
  final double temperature; // Celsius
  final double humidity; // Percentage
  final double pressure; // hPa
  final double windSpeed; // m/s
  final double windDirection; // degrees
  final double cloudCover; // Percentage
  final double solarIrradiance; // W/m² (estimated)
  final String condition; // Weather condition
  final String description; // Weather description
  final String icon; // Weather icon code
  final DateTime timestamp;
  final String locationName;
  final double latitude;
  final double longitude;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudCover,
    required this.solarIrradiance,
    required this.condition,
    required this.description,
    required this.icon,
    required this.timestamp,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      humidity: (json['main']['humidity'] as num).toDouble(),
      pressure: (json['main']['pressure'] as num).toDouble(),
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      windDirection: (json['wind']['deg'] as num?)?.toDouble() ?? 0.0,
      cloudCover: (json['clouds']['all'] as num).toDouble(),
      solarIrradiance: _estimateSolarIrradiance(json),
      condition: json['weather'][0]['main'] as String,
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000),
      locationName: json['name'] as String,
      latitude: (json['coord']['lat'] as num).toDouble(),
      longitude: (json['coord']['lon'] as num).toDouble(),
    );
  }

  static double _estimateSolarIrradiance(Map<String, dynamic> json) {
    // Estimate solar irradiance based on cloud cover and time of day
    final clouds = (json['clouds']['all'] as num).toDouble();
    final dt = DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000);
    final hour = dt.hour + dt.minute / 60.0;
    
    // Simple estimation: clear sky ~1000 W/m² at solar noon, reduced by clouds
    double maxIrradiance = 0;
    if (hour >= 6 && hour <= 18) {
      // Simple solar elevation model
      final solarNoon = 12.0;
      final hourAngle = (hour - solarNoon) * 15.0; // degrees
      final elevation = 90 - hourAngle.abs(); // simplified
      if (elevation > 0) {
        maxIrradiance = 1000 * (elevation / 90);
      }
    }
    
    // Reduce by cloud cover
    return maxIrradiance * (1 - clouds / 100);
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'cloudCover': cloudCover,
      'solarIrradiance': solarIrradiance,
      'condition': condition,
      'description': description,
      'icon': icon,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory WeatherData.fromCache(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      pressure: (json['pressure'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      windDirection: (json['windDirection'] as num).toDouble(),
      cloudCover: (json['cloudCover'] as num).toDouble(),
      solarIrradiance: (json['solarIrradiance'] as num).toDouble(),
      condition: json['condition'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      locationName: json['locationName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// Get weather icon URL
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  /// Check if weather is good for solar production
  bool get isGoodForSolar => cloudCover < 30 && solarIrradiance > 500;

  /// Get solar production estimate factor (0.0 to 1.0)
  double get solarProductionFactor {
    if (solarIrradiance <= 0) return 0.0;
    // Normalize to 0-1 based on typical max irradiance
    return (solarIrradiance / 1000).clamp(0.0, 1.0);
  }
}

/// Weather forecast data
class WeatherForecast {
  final List<WeatherData> hourly;
  final List<WeatherData> daily;
  final String locationName;
  final double latitude;
  final double longitude;

  WeatherForecast({
    required this.hourly,
    required this.daily,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      hourly: (json['hourly'] as List)
          .map((e) => WeatherData.fromJson(e))
          .toList(),
      daily: (json['daily'] as List)
          .map((e) => WeatherData.fromJson(e))
          .toList(),
      locationName: json['timezone'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
    );
  }
}

/// Weather service for fetching weather data
class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _apiKeyKey = 'weather_api_key';
  static const String _locationKey = 'weather_location';
  static const String _cacheKey = 'weather_cache';
  static const String _forecastCacheKey = 'weather_forecast_cache';
  static const Duration _cacheDuration = Duration(minutes: 30);

  String? _apiKey;
  Position? _currentPosition;
  String? _cachedLocationName;
  double? _cachedLatitude;
  double? _cachedLongitude;

  /// Initialize the weather service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyKey);
    
    // Try to get cached location
    _cachedLocationName = prefs.getString('${_locationKey}_name');
    _cachedLatitude = prefs.getDouble('${_locationKey}_lat');
    _cachedLongitude = prefs.getDouble('${_locationKey}_lon');
    
    // Try to get current position
    await _getCurrentPosition();
  }

  /// Set API key
  Future<void> setApiKey(String apiKey) async {
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  /// Get API key
  String? get apiKey => _apiKey;

  /// Check if API key is set
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Get current position
  Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS in settings.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please grant location permission in settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable it in app settings.');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      rethrow;
    }
  }

  /// Get current weather
  Future<WeatherData?> getCurrentWeather() async {
    if (!hasApiKey) return null;

    // Try to get cached data first
    final cached = await _getCachedWeather();
    if (cached != null) return cached;

    // Get current position
    Position? position;
    try {
      position = _currentPosition ?? await _getCurrentPosition();
    } catch (e) {
      // Return cached data if available
      return await _getCachedWeather();
    }
    
    if (position == null) return null;

    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric&lang=id',
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weather = WeatherData.fromJson(data);
        
        // Cache the result
        await _cacheWeather(weather);
        
        // Cache location
        await _cacheLocation(
          weather.locationName,
          weather.latitude,
          weather.longitude,
        );
        
        return weather;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your OpenWeatherMap API key.');
      } else if (response.statusCode == 404) {
        throw Exception('Location not found.');
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      // Return cached data if available
      return await _getCachedWeather();
    }
  }

  /// Get weather forecast
  Future<WeatherForecast?> getForecast() async {
    if (!hasApiKey) return null;

    // Try to get cached data first
    final cached = await _getCachedForecast();
    if (cached != null) return cached;

    // Get current position
    Position? position;
    try {
      position = _currentPosition ?? await _getCurrentPosition();
    } catch (e) {
      // Return cached data if available
      return await _getCachedForecast();
    }
    
    if (position == null) return null;

    try {
      final url = Uri.parse(
        '$_baseUrl/onecall?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric&lang=id&exclude=minutely,alerts',
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final forecast = WeatherForecast.fromJson(data);
        
        // Cache the result
        await _cacheForecast(forecast);
        
        return forecast;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your OpenWeatherMap API key.');
      } else if (response.statusCode == 404) {
        throw Exception('Location not found.');
      } else {
        throw Exception('Failed to fetch forecast: ${response.statusCode}');
      }
    } catch (e) {
      // Return cached data if available
      return await _getCachedForecast();
    }
  }

  /// Get weather by city name
  Future<WeatherData?> getWeatherByCity(String cityName) async {
    if (!hasApiKey) return null;

    try {
      final url = Uri.parse(
        '$_baseUrl/weather?q=$cityName&appid=$_apiKey&units=metric&lang=id',
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weather = WeatherData.fromJson(data);
        
        // Cache location
        await _cacheLocation(
          weather.locationName,
          weather.latitude,
          weather.longitude,
        );
        
        return weather;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key. Please check your OpenWeatherMap API key.');
      } else if (response.statusCode == 404) {
        throw Exception('City not found. Please check the city name.');
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Search cities
  Future<List<Map<String, dynamic>>> searchCities(String query) async {
    if (!hasApiKey) return [];

    try {
      final url = Uri.parse(
        'http://api.openweathermap.org/geo/1.0/direct?q=$query&limit=5&appid=$_apiKey',
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((e) => {
          'name': e['name'] as String,
          'country': e['country'] as String,
          'lat': (e['lat'] as num).toDouble(),
          'lon': (e['lon'] as num).toDouble(),
        }).toList();
      }
    } catch (e) {
      return [];
    }
    
    return [];
  }

  /// Get cached weather
  Future<WeatherData?> _getCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt('${_cacheKey}_time');
    final cacheData = prefs.getString(_cacheKey);
    
    if (cacheTime != null && cacheData != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (age < _cacheDuration.inMilliseconds) {
        return WeatherData.fromCache(jsonDecode(cacheData));
      }
    }
    return null;
  }

  /// Cache weather data
  Future<void> _cacheWeather(WeatherData weather) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(weather.toJson()));
    await prefs.setInt('${_cacheKey}_time', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached forecast
  Future<WeatherForecast?> _getCachedForecast() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt('${_forecastCacheKey}_time');
    final cacheData = prefs.getString(_forecastCacheKey);
    
    if (cacheTime != null && cacheData != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (age < _cacheDuration.inMilliseconds) {
        return WeatherForecast.fromJson(jsonDecode(cacheData));
      }
    }
    return null;
  }

  /// Cache forecast data
  Future<void> _cacheForecast(WeatherForecast forecast) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_forecastCacheKey, jsonEncode({
      'hourly': forecast.hourly.map((e) => e.toJson()).toList(),
      'daily': forecast.daily.map((e) => e.toJson()).toList(),
      'timezone': forecast.locationName,
      'lat': forecast.latitude,
      'lon': forecast.longitude,
    }));
    await prefs.setInt('${_forecastCacheKey}_time', DateTime.now().millisecondsSinceEpoch);
  }

  /// Cache location
  Future<void> _cacheLocation(String name, double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_locationKey}_name', name);
    await prefs.setDouble('${_locationKey}_lat', lat);
    await prefs.setDouble('${_locationKey}_lon', lon);
    _cachedLocationName = name;
    _cachedLatitude = lat;
    _cachedLongitude = lon;
  }

  /// Get cached location
  String? get cachedLocationName => _cachedLocationName;
  double? get cachedLatitude => _cachedLatitude;
  double? get cachedLongitude => _cachedLongitude;

  /// Clear cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove('${_cacheKey}_time');
    await prefs.remove(_forecastCacheKey);
    await prefs.remove('${_forecastCacheKey}_time');
  }

  /// Get weather icon URL
  static String getIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
}