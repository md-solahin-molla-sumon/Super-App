
class WeatherModel {
  final String cityName;
  final String country;
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final int pressure;
  final double windSpeed;
  final String weatherCondition;
  final String weatherDescription;
  final String weatherIcon;

  const WeatherModel({
    required this.cityName,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.weatherCondition,
    required this.weatherDescription,
    required this.weatherIcon,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;
    final weatherList = json['weather'] as List<dynamic>;
    final weather = weatherList.first as Map<String, dynamic>;
    final sys = json['sys'] as Map<String, dynamic>;

    return WeatherModel(
      cityName: json['name']?.toString() ?? 'Unknown',
      country: sys['country']?.toString() ?? '',
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      tempMin: (main['temp_min'] as num).toDouble(),
      tempMax: (main['temp_max'] as num).toDouble(),
      humidity: (main['humidity'] as num).toInt(),
      pressure: (main['pressure'] as num).toInt(),
      windSpeed: (wind['speed'] as num).toDouble(),
      weatherCondition: weather['main']?.toString() ?? '',
      weatherDescription:
          weather['description']?.toString() ?? '',
      weatherIcon: weather['icon']?.toString() ?? '01d',
    );
  }

  String get iconUrl =>
      'https://openweathermap.org/img/wn/$weatherIcon@4x.png';
}
