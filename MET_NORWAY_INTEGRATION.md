# MET Norway Integration

## Overview
Nimbus now supports three weather data sources:
1. **Open-Meteo** - Global coverage, simple API (default)
2. **MET Norway** - Better Nordic forecasts, official alerts
3. **Hybrid** - Best of both worlds (intelligent source selection)

## Features Implemented

### 1. Weather Data Source Selection
- Settings dropdown allows choosing between Open-Meteo, MET Norway, or Hybrid mode
- Located in Settings → Data → Weather Data Source
- Automatically clears cache and refreshes weather when changed

### 2. MET Norway Service (`metno_service.dart`)
Comprehensive API integration with:
- **Location Forecast**: Global weather forecasts (9 days)
- **Nowcast**: 2-hour precipitation forecast (Nordic only, 5-min updates)
- **MetAlerts**: Official weather alerts from Norwegian Met Institute
- **Air Quality**: AQI forecast for Norway
- **Sunrise/Sunset**: Astronomical calculations
- **Radar Images**: Nordic radar imagery

### 3. Hybrid Weather Service (`hybrid_weather_service.dart`)
Intelligent data source selection:
- **Nordic Region Detection**: Automatically detects if location is in Nordic area (54°N-72°N, 4°W-32°E)
- **Smart Source Selection**:
  - Uses MET Norway for Nordic locations (better accuracy)
  - Uses Open-Meteo for global coverage
  - Enhances with MET Nowcast for short-term precipitation
  - Fetches official alerts from MetAlerts
- **Fallback Logic**: Automatically falls back to Open-Meteo if MET Norway fails

### 4. API Integration Updates (`api.dart`)
Modified weather API calls to:
- Check `weatherDataSource` setting before fetching
- Use hybrid service when appropriate
- Maintain backward compatibility with Open-Meteo
- Support official alerts from MET Norway

## How It Works

### OpenMeteo Mode (Default)
```dart
settings.weatherDataSource = 'openmeteo';
```
- Uses Open-Meteo API exclusively
- Global coverage
- Current implementation (no changes)

### MET Norway Mode
```dart
settings.weatherDataSource = 'metno';
```
- Uses MET Norway API exclusively
- Best for Nordic countries
- Official alerts and high-precision forecasts

### Hybrid Mode (Recommended)
```dart
settings.weatherDataSource = 'hybrid';
```
- **For Nordic locations** (Norway, Sweden, Finland, Denmark, Iceland):
  - Primary: MET Norway location forecast
  - Enhanced: MET Nowcast for next 2 hours
  - Alerts: Official MetAlerts
- **For Global locations**:
  - Primary: Open-Meteo (fallback)
  - Alerts: Open-Meteo alerts

## Data Format Conversion
MET Norway data is automatically converted to Open-Meteo format via `convertToOpenMeteoFormat()`:
- Temperature (°C)
- Precipitation (mm)
- Wind speed (m/s) and direction
- Humidity, pressure, cloud cover
- Weather codes (WMO standard)
- Visibility (km)

This ensures seamless integration with existing app logic.

## API Requirements

### MET Norway
- **User-Agent**: Required (already configured: "Nimbus Weather App github.com/linuxgoose/nimbus")
- **API Key**: Not required
- **Rate Limits**: Reasonable use policy
- **Terms**: https://api.met.no/doc/TermsOfService

### Open-Meteo
- No authentication required
- No API key needed
- Free for non-commercial use

## Nordic Region Coverage
MET Norway provides superior data for:
- 🇳🇴 Norway
- 🇸🇪 Sweden
- 🇫🇮 Finland
- 🇩🇰 Denmark
- 🇮🇸 Iceland

**Approximate bounds**: 54°N to 72°N, 4°W to 32°E

## Benefits

### For Nordic Users
- **Better Accuracy**: MET Norway specializes in Nordic forecasts
- **Official Alerts**: Authoritative weather warnings from national met service
- **Nowcast**: Minute-by-minute precipitation for next 2 hours
- **Local Radar**: High-resolution Nordic radar imagery

### For Global Users
- **Seamless Experience**: Automatic fallback to Open-Meteo
- **No Breaking Changes**: Hybrid mode works everywhere
- **Best Available Data**: Smart selection per location

## Testing

### To Test MET Norway Mode
1. Go to Settings → Data → Weather Data Source
2. Select "MET Norway"
3. Navigate to a Nordic location (e.g., Oslo, Stockholm)
4. Weather data should load from MET Norway

### To Test Hybrid Mode
1. Go to Settings → Data → Weather Data Source
2. Select "Hybrid (Best of Both)"
3. Test with both Nordic and non-Nordic locations
4. Verify appropriate source is used (check debug logs)

## Debug Output
The implementation includes extensive debug logging:
- `🌐` - Hybrid service location detection
- `🇳🇴` - MET Norway primary source
- `🌍` - Open-Meteo primary source
- `🔀` - Hybrid mode decisions
- `✨` - Nowcast enhancement
- `🚨` - Alert fetching
- `✅` - Success messages
- `⚠️` - Warnings and fallbacks
- `❌` - Errors

Check console for: "Hybrid Service", "MET Norway", "Using hybrid weather data"

## Files Modified
1. `/lib/app/data/db.dart` - Added `weatherDataSource` setting
2. `/lib/app/ui/settings/view/settings.dart` - Added dropdown UI
3. `/lib/app/api/api.dart` - Integrated hybrid service
4. `/lib/main.dart` - Initialize weatherDataSource default

## Files Created
1. `/lib/app/services/metno_service.dart` - MET Norway API wrapper
2. `/lib/app/services/hybrid_weather_service.dart` - Intelligent source selector

## Future Enhancements
- [ ] Add MET Norway tide predictions (Tidalwater API)
- [ ] Implement Nowcast UI on main weather page
- [ ] Add radar image switching (MET vs RainViewer)
- [ ] Store MetAlerts in AlertHistory
- [ ] Add alert polygon rendering on map
- [ ] Regional optimization (detect more regions)
- [ ] User preference for fallback behavior
- [ ] Cache strategy per data source

## Known Limitations
- Nowcast only works in Nordic region
- MET Norway AQI only for Norway
- Radar API requires area codes (currently using 'nordic')
- No API key means shared rate limits

## Support
For issues or questions about MET Norway integration:
1. Check debug logs for error messages
2. Verify User-Agent header is present
3. Confirm location is within expected coverage
4. Test with Open-Meteo mode to isolate issues
