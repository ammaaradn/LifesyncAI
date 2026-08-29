import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

/// Thrown by [WeatherService] with a message that's safe to show directly
/// in the UI.
class WeatherException implements Exception {
  final String message;
  const WeatherException(this.message);

  @override
  String toString() => message;
}

/// Fetches current + today's forecast weather from the free, keyless
/// Open-Meteo API (https://open-meteo.com) for a given coordinate.
class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<WeatherModel> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m,weather_code,is_day',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
    });

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw WeatherException(
          'Weather service returned an error (${response.statusCode}).',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return WeatherModel.fromJson(json);
    } on WeatherException {
      rethrow;
    } on TimeoutException {
      throw const WeatherException(
        'Weather request timed out. Check your internet connection.',
      );
    } catch (_) {
      throw const WeatherException(
        'Could not fetch weather right now. Check your internet connection.',
      );
    }
  }
}
