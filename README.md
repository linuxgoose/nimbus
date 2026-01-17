<div align='center'>
    <h1>Nimbus</h1>
</div>

<p align='center'>
    <p align='center'>
        <a href='https://github.com/linuxgoose/nimbus/stargazers'><img alt='Stars' src='https://img.shields.io/github/stars/linuxgoose/nimbus?color=abc0d3'/></a>
        <a href='https://github.com/linuxgoose/nimbus/forks'><img alt='Forks' src='https://img.shields.io/github/forks/linuxgoose/nimbus?color=abc0d3'/></a>
        <a href='https://github.com/linuxgoose/nimbus/releases'><img alt='GitHub release' src='https://img.shields.io/github/v/release/linuxgoose/nimbus?color=abc0d3'/></a>
        <a href='https://github.com/linuxgoose/nimbus/blob/refactor/LICENSE'><img alt='License' src='https://img.shields.io/github/license/linuxgoose/nimbus?color=abc0d3'/></a>
    </p>
</p>

<p align='center'> Your comprehensive weather companion. Stay informed with accurate forecasts and elegant design. </p>

### Complete Weather Information

With Nimbus, you can explore detailed weather data for your location and beyond. We offer comprehensive features to keep you informed and prepared:

- **Current Weather Conditions:** Stay up-to-date with real-time weather in your area.
- **Hourly Forecasts:** Plan your day with detailed hourly weather predictions.
- **7-Day Outlook:** Get a complete week-long weather forecast at your fingertips.
- **6-Hour Rain Forecast:** High-resolution precipitation predictions using Open-Meteo's specialized minutely/15-minute data:
  - Interactive chart with precipitation intensity over time
  - 15-minute resolution data when available (hourly fallback)
  - Touch tooltips showing exact precipitation values
  - 30-minute offline caching for improved performance
  - Always uses Open-Meteo regardless of weather provider setting
  - Toggleable in Settings → Weather Provider
- **Live Weather Radar:** Interactive radar map with animated precipitation overlays powered by RainViewer:
  - Real-time precipitation visualization
  - Animated playback with timeline controls
  - 9 customizable color schemes (TITAN, NEXRAD, Weather Channel, Dark Sky, and more)
  - Dynamic legend showing precipitation intensity
  - Location centering and interactive map controls
- **Tide Predictions:** Comprehensive tide information with:
  - Interactive 24-hour tide chart with axis labels
  - Current tide level and status (rising/falling)
  - Upcoming high and low tide times
  - Multiple saved locations with geocoding search
  - Optional real-time data via Stormglass API (10 requests/day free)
  - 24-hour offline caching to conserve API quota
  - Toggle between real and dummy data for testing
- **Detailed Weather Data:** Access comprehensive weather statistics including temperature, humidity, wind speed, precipitation probability, UV index, and more.
- **Weather Alerts:** Receive timely notifications about significant weather changes and conditions, including:
  - Official government weather warnings via MET Norway MetAlerts (Nordic region)
  - Global weather alerts via Open-Meteo
  - Location-based filtering (150km radius)
  - Alert history tracking with severity levels
- **Air Quality Index (AQI):** Monitor air quality with:
  - Real-time AQI data for your location
  - Multiple AQI standards (US EPA and European CAQI)
  - Pollutant breakdowns (PM2.5, PM10, O₃, NO₂, SO₂, CO)
  - Color-coded health recommendations
  - 1-hour caching to reduce API calls
  - Manual cache inspection and clearing
- **Aurora Watch:** Track northern lights activity with:
  - Real-time Kp-index from NOAA Space Weather Prediction Center
  - AuroraWatch UK alerts for the United Kingdom
  - 3-day aurora forecast with hourly predictions
  - Activity levels and visibility indicators
  - Color-coded alerts based on geomagnetic activity
  - 30-minute caching for optimal performance
- **Moon Phases:** Comprehensive lunar information with:
  - Current moon phase with emoji visualization
  - Phase name and illumination percentage
  - Progress indicator through lunar cycle
  - Predictions for next full and new moon
  - Educational information about moon phases
  - Astronomical calculations using Julian Date method
- **UK Flood Monitoring:** Real-time flood and river data across the UK with:
  - Active flood warnings and alerts from regional agencies
  - England: Environment Agency flood warnings and river monitoring stations
  - Scotland: SEPA (Scottish Environment Protection Agency) warnings and river stations
  - Wales: Natural Resources Wales flood alerts and river monitoring stations
  - Northern Ireland: Limited data availability (no public API)
  - Interactive map showing flood areas and monitoring stations
  - Severity levels (Severe Warning, Warning, Alert)
  - River level monitoring stations across England, Scotland, and Wales
  - Configurable search radius (25-200km, default 100km)
  - Location-based filtering with distance calculations
  - Color-coded warning indicators
  - Detailed warning information and updates
  - Toggle visibility and notifications in settings
- **Agriculture Data:** Comprehensive farming and crop management information with:
  - Soil moisture monitoring at multiple depths (0-1cm, 1-3cm, 3-9cm, 9-27cm, 27-81cm)
  - Soil temperature at different levels (surface, 6cm, 18cm, 54cm)
  - ET₀ FAO Reference Evapotranspiration for irrigation planning
  - Vapour Pressure Deficit (VPD) for plant stress assessment
  - Growing Degree Days (GDD) calculations for crop development
  - 48-hour soil condition forecasts with interactive charts
  - 7-day agricultural weather forecast
  - Real-time conditions and recommendations
  - Toggle visibility in settings
- **Elevation Data:** View elevation above sea level for any location
- **Multi-Language Support:** Choose from a wide range of language options.
- **Offline Access:** View cached weather data even without an internet connection.
- **Multiple Locations:** Add and manage weather for multiple cities.
- **Flexible Units:** Switch between metric and imperial measurement systems.
- **Temperature Preferences:** Choose Celsius or Fahrenheit display.
- **Time Format Options:** Select 12-hour or 24-hour time display.
- **Weather Provider Selection:** Dedicated settings section for weather data sources:
  - Choose between Open-Meteo, MET Norway, or Hybrid mode
  - Option to prefer MET Norway in Hybrid mode (override automatic region detection)
  - Toggle 6-hour rain forecast chart visibility
  - Located in Settings → Weather Provider
- **Customisable Notifications:** Stay informed with configurable weather alerts with minimum severity filtering.
- **Home Screen Widgets:** Quick weather access with customisable widgets including:
  - Current weather widget with friendly summaries
  - Hourly forecast widget (6 hours)
  - Daily forecast widget (6 days)
- **Modern Material Design:** Beautiful, intuitive interface with dark mode support.

### Reliable Data Sources

Weather data is powered by **multiple sources** for optimal accuracy and coverage:

- **[Open-Meteo](https://open-meteo.com/en/docs)**: Primary weather data provider with global coverage, offering accurate forecasts, historical data, and weather alerts.
- **[MET Norway](https://api.met.no/)**: Official weather service from the Norwegian Meteorological Institute, providing:
  - Superior forecast accuracy for Nordic countries (Norway, Sweden, Finland, Denmark, Iceland)
  - Official weather alerts (MetAlerts) from national meteorological services
  - High-precision Nowcast with 2-hour precipitation forecasts (5-minute updates)
  - Specialized radar imagery for Nordic region
- **Hybrid Mode**: Intelligent data source selection that automatically uses:
  - MET Norway for Nordic locations (54°N-72°N, 4°W-32°E)
  - Open-Meteo for global locations
  - Enhanced short-term precipitation forecasting
  - Official government weather warnings when available

Location search utilises [Open-Meteo's Geocoding API](https://open-meteo.com/en/docs/geocoding-api) for easy city discovery. Live radar imagery is provided by [RainViewer](https://www.rainviewer.com/) with support for multiple color schemes and real-time precipitation tracking. Tide predictions are powered by [Stormglass.io](https://stormglass.io/) with optional API key integration for real-time data (10 free requests per day). Short-term rain forecasts utilize [Open-Meteo's Minutely API](https://open-meteo.com/en/docs) for high-resolution 15-minute precipitation data. UK flood monitoring data is provided by the [Environment Agency](https://environment.data.gov.uk/flood-monitoring/doc/reference) (England), [SEPA](https://www2.sepa.org.uk/fwa/) (Scotland), and [Natural Resources Wales](https://api.naturalresources.wales/) (Wales) with real-time warnings and river monitoring stations. Northern Ireland's DfI Rivers does not currently provide a public API for automated flood data access.

**Weather Provider Selection**: Choose your preferred weather data source in Settings → Weather Provider:
- **Open-Meteo**: Global coverage (default)
- **MET Norway**: Best for Nordic countries
- **Hybrid**: Automatically selects the best source for your location

### Get Nimbus

Get the latest APK from the [Releases Section](https://github.com/linuxgoose/nimbus/releases/latest).

### Licence

This project is licensed under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](./LICENSE).

### Acknowledgements

Nimbus is a fork of [Rain](https://github.com/DarkMooNight/Rain) by DarkMooNight. We extend our gratitude to the original developers and contributors.