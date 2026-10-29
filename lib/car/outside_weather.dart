import 'dart:convert';

import 'package:http/http.dart' as http;

/// Outside temperature where the car is. The car doesn't report one over
/// Bluelink, so this asks Open-Meteo (free, no key) for the weather at the
/// car's position, rounded to about 1 km so only a coarse location leaves the
/// phone. Results are kept for 15 minutes per spot.
class OutsideWeather {
  OutsideWeather({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  final _cache = <(double, double), (DateTime, double)>{};
  static const _fresh = Duration(minutes: 15);

  static (double, double) round((double, double) at) =>
      ((at.$1 * 100).roundToDouble() / 100, (at.$2 * 100).roundToDouble() / 100);

  /// °C at [at], or null when the lookup fails.
  Future<double?> tempC((double, double) at) async {
    final spot = round(at);
    final hit = _cache[spot];
    if (hit != null && DateTime.now().difference(hit.$1) < _fresh) return hit.$2;
    try {
      final r = await _http
          .get(
            Uri.https('api.open-meteo.com', '/v1/forecast', {
              'latitude': '${spot.$1}',
              'longitude': '${spot.$2}',
              'current': 'temperature_2m',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return hit?.$2;
      final t = ((jsonDecode(r.body) as Map)['current'] as Map?)?['temperature_2m'];
      if (t is! num) return hit?.$2;
      _cache[spot] = (DateTime.now(), t.toDouble());
      return t.toDouble();
    } catch (_) {
      return hit?.$2;
    }
  }
}
