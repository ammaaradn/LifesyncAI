import 'package:flutter/material.dart';

/// Current + today's forecast weather, parsed from the Open-Meteo API.
class WeatherModel {
  final double currentTemperature;
  final int weatherCode; // WMO weather code
  final bool isDay;
  final double todayMaxTemp;
  final double todayMinTemp;
  final int todayMaxPrecipitationProbability; // 0-100
  final DateTime fetchedAt;

  const WeatherModel({
    required this.currentTemperature,
    required this.weatherCode,
    required this.isDay,
    required this.todayMaxTemp,
    required this.todayMinTemp,
    required this.todayMaxPrecipitationProbability,
    required this.fetchedAt,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    return WeatherModel(
      currentTemperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      isDay: (current['is_day'] as num).toInt() == 1,
      todayMaxTemp: ((daily['temperature_2m_max'] as List).first as num)
          .toDouble(),
      todayMinTemp: ((daily['temperature_2m_min'] as List).first as num)
          .toDouble(),
      todayMaxPrecipitationProbability:
          ((daily['precipitation_probability_max'] as List).first as num)
              .toInt(),
      fetchedAt: DateTime.now(),
    );
  }

  /// Used by the SuggestionEngine's rain rule - 50%+ chance counts as
  /// "likely to rain".
  bool get willLikelyRain => todayMaxPrecipitationProbability >= 50;

  /// Short human-readable summary of [weatherCode], based on the WMO
  /// weather interpretation codes Open-Meteo uses.
  String get description {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode == 45 || weatherCode == 48) return 'Foggy';
    if (weatherCode >= 51 && weatherCode <= 57) return 'Drizzle';
    if (weatherCode >= 61 && weatherCode <= 67) return 'Rain';
    if (weatherCode >= 71 && weatherCode <= 77) return 'Snow';
    if (weatherCode >= 80 && weatherCode <= 82) return 'Rain showers';
    if (weatherCode >= 85 && weatherCode <= 86) return 'Snow showers';
    if (weatherCode >= 95) return 'Thunderstorm';
    return 'Unknown';
  }

  IconData get icon {
    if (weatherCode == 0) return isDay ? Icons.wb_sunny : Icons.nights_stay;
    if (weatherCode <= 3) return Icons.wb_cloudy_outlined;
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.grain;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.umbrella;
    if (weatherCode >= 85 && weatherCode <= 86) return Icons.ac_unit;
    if (weatherCode >= 95) return Icons.thunderstorm;
    return Icons.cloud;
  }
}
