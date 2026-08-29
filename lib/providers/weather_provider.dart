import 'package:flutter/foundation.dart';

import '../models/weather_model.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Holds the app's one weather fetch (current location -> Open-Meteo),
/// shared by the Dashboard and Smart Suggestions screens so both reflect
/// the same result instead of each triggering its own location + network
/// request.
class WeatherProvider extends ChangeNotifier {
  final LocationService _locationService;
  final WeatherService _weatherService;

  WeatherProvider({
    required LocationService locationService,
    required WeatherService weatherService,
  }) : _locationService = locationService,
       _weatherService = weatherService;

  WeatherModel? weather;
  String? error;
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      error =
          'Location unavailable. Enable location permission to get '
          'weather-based suggestions.';
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      weather = await _weatherService.fetchWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on WeatherException catch (e) {
      error = e.message;
    }

    isLoading = false;
    notifyListeners();
  }
}
