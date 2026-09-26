# EnerGrow 1.3.1 (build 9) Release Notes

## Overview
This release introduces the **Weather Monitoring** feature with OpenWeatherMap API integration, along with significant codebase refactoring and improvements.

## Version
- **Version Name**: 1.3.1
- **Version Code**: 9
- **Release Date**: 2026-09-26
- **Git Tag**: v1.3.1

## Major Features

### 🌤️ Weather Monitoring
- **OpenWeatherMap API Integration**: Real-time weather data and forecasts
- **WeatherService Class**: Complete weather data fetching with caching (30-minute cache)
- **Weather Data Models**: `WeatherData` and `WeatherForecast` with solar irradiance estimation
- **Dashboard Weather Card**: Compact card showing temperature, humidity, wind speed, and cloud cover
- **Settings Integration**: Dedicated Weather section with API key configuration and city selection
- **Test Connection**: Verify API key and location before saving
- **GPS Support**: Automatic location-based weather fetching when city is not specified
- **Theme Integration**: Weather card uses app theme colors (primary, secondary, tertiary, outline) that adapt to accent color from Settings

### 🏗️ Codebase Refactoring
- **Energy Report Screen**: Modularized from 809 to 251 lines (-69%) with extracted widgets and utilities
- **Dashboard Screen**: Modularized from 3,072 to 2,550 lines (-17%) with ~500 lines extracted to reusable utilities
- **Settings Screen**: Modularized from 816 to 470 lines (-42%) with consolidated validation and builder patterns
- **Total Reduction**: ~1,000 lines removed while preserving all functionality

### 🎨 UI/UX Improvements
- **Weather Card Redesign**: Single compact card with all 4 metrics (temperature, humidity, wind, cloud cover) in one row
- **Removed Solar Irradiance Section**: For space efficiency
- **Fixed Humidity Text Overflow**: Smaller fonts (12/9), ellipsis handling, optimized padding
- **Theme Color Integration**: Weather card uses theme colors (primary, secondary, tertiary, outline) that adapt to accent color from Settings
- **Energi Analytics**: Renamed Energy Report screen from "Laporan energi"

## Technical Changes

### Android Platform
- **compileSdk**: Updated to 36 for latest plugin compatibility
- **geocoding**: Updated from ^2.1.1 to ^5.0.0 for Android 14+ support
- **GPS Permissions**: Added ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION

### Dependencies
- `geocoding`: ^2.1.1 → ^5.0.0
- `flutter_local_notifications`: ^19.4.1
- `android_alarm_manager_plus`: ^5.0.0
- `geolocator`: ^10.1.0

### Code Quality
- Fixed all Dart analyze errors
- Fixed async context issues in Dashboard `_loadPreferences`
- Resolved merge conflicts in settings and energy report screens
- Fixed import paths in all extracted utility/widget files
- Better error handling in WeatherService with descriptive messages (401, 404, etc.)
- Weather service properly throws exceptions for GPS permission issues

## Bug Fixes
- Fixed weather data not updating on dashboard after saving API key in settings
- Fixed weather card refresh button and settings button in no-data state
- Fixed humidity text overflow with smaller fonts and ellipsis handling
- Fixed async context error in Dashboard `_loadPreferences`
- Resolved merge conflicts in settings_screen.dart and energy_report_screen.dart
- Fixed import paths in all extracted utility/widget files

## Validation
- ✅ `flutter analyze` passes with no issues
- ✅ `flutter test` passes
- ✅ `flutter build apk --release` successful
- ✅ APK signature verification with apksigner
- ✅ All functionality preserved: Settings (8 categories), Dashboard (5 tabs + realtime), Energy Report (period selection, chart, CSV export)
- ✅ Zero breaking changes

## Installation
1. Download `EnerGrow-v1.3.1.apk` from the release assets
2. Enable "Install from unknown sources" in Android settings
3. Install the APK
4. Open app and configure Weather API key in Settings → Weather

## Known Limitations
- Weather API key activation may take 10-30 minutes after creation on OpenWeatherMap
- GPS permission required for automatic location-based weather
- Free tier OpenWeatherMap API has rate limits (60 calls/minute)

## Verification
- **SHA-256 Fingerprint**: 504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5
- **Version Name**: 1.3.1
- **Version Code**: 9
- **Build Type**: Release (signed with project keystore)

## Files Included
- `EnerGrow-v1.3.1.apk` — Signed release APK
- `CHANGELOG.md` — Complete changelog history