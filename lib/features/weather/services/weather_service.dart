
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

class WeatherService {
  static const String _apiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
  );

  static const String _baseUrl =
      'api.openweathermap.org';

  Future<WeatherModel> getCurrentWeather(String city) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'API Key missing. Please provide OPENWEATHER_API_KEY.',
      );
    }

    final uri = Uri.https(
      _baseUrl,
      '/data/2.5/weather',
      {
        'q': city.trim(),
        'appid': _apiKey,
        'units': 'metric',
      },
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return WeatherModel.fromJson(data);
      }

      final message =
          data['message']?.toString() ?? 'Unknown API error';

      if (response.statusCode == 404) {
        throw Exception('City not found. Please try another city.');
      }

      if (response.statusCode == 401) {
        throw Exception(
          'Invalid API Key or API Key is not activated yet.',
        );
      }

      if (response.statusCode == 429) {
        throw Exception('API request limit exceeded.');
      }

      throw Exception('Weather API Error: $message');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to connect to Weather API. Check your internet connection.',
      );
    }
  }
}
