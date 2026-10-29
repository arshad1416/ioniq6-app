/// Distance and temperature in the units chosen in Settings. Everything from
/// Home Assistant arrives in km and °C.
class Units {
  const Units({this.miles = false, this.fahrenheit = false});
  final bool miles, fahrenheit;

  static const _kmPerMile = 1.609344;

  String get distance => miles ? 'mi' : 'km';

  /// [km] converted to the chosen unit, rounded, without the unit.
  int? dist(num? km) => km == null ? null : (miles ? km / _kmPerMile : km).round();

  /// [c] in the chosen unit with a degree sign, e.g. "21°" or "70°".
  String temp(double? c) {
    if (c == null) return '–';
    final v = fahrenheit ? c * 9 / 5 + 32 : c;
    return '${v.toStringAsFixed(fahrenheit || v % 1 == 0 ? 0 : 1)}°';
  }
}
