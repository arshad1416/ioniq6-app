import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_state.dart';
import 'package:ioniq6_companion/ha/entities.dart';
import 'package:ioniq6_companion/ha/ha_client.dart';

CarState state(String id, String value, [Map<String, dynamic> attrs = const {}]) =>
    CarState({id: EntityState(id, value, attrs, DateTime(2026))});

void main() {
  test('non-finite telemetry is unknown rather than a rounding exception', () {
    for (final value in ['NaN', 'Infinity', '-Infinity', '1e999', '-1e999']) {
      expect(state(E.soc, value).soc, isNull, reason: value);
      expect(state(E.chargePower, value).chargeKw, isNull, reason: value);
    }
  });

  test('unrecognized binary values are not reported healthy or closed', () {
    for (final value in ['', 'none', 'error', 'false', '0', 'restored']) {
      expect(state(E.hood, value).hoodOpen, isNull, reason: value);
      expect(state(E.brakeFluid, value).brakeFluidOk, isNull, reason: value);
    }
    expect(state(E.hood, 'off').hoodOpen, isFalse);
    expect(state(E.hood, 'on').hoodOpen, isTrue);
  });

  test('bounded malformed-attribute fuzz cannot break the view model', () {
    final random = Random(6013);
    final values = <Object?>[null, '', 'unknown', 'bad', true, false, [], {}, 5, 5.5, double.nan, double.infinity];
    for (var i = 0; i < 256; i++) {
      final value = values[random.nextInt(values.length)];
      final car = CarState({
        E.chargerVehicle: EntityState(E.chargerVehicle, 'ioniq_6', {'session_kwh': value}, DateTime(2026)),
        E.climate: EntityState(E.climate, 'off', {'current_temperature': value}, DateTime(2026)),
        E.weather: EntityState(E.weather, 'cloudy', {'temperature': value}, DateTime(2026)),
        E.valet: EntityState(E.valet, 'off', {'maxSpeed': value}, DateTime(2026)),
        E.camera('front'): EntityState(E.camera('front'), 'unknown', {'entity_picture': value}, DateTime(2026)),
        E.dailyStats: EntityState(E.dailyStats, 'ok', {
          '2026-11-12': {
            'distance': value,
            'total_consumed': value,
            'regenerated_energy': value,
            'climate_consumption': value,
          },
        }, DateTime(2026)),
      });
      expect(
        () => [
          car.sessionKwh,
          car.cabinTempC,
          car.homeWeatherC,
          car.valetMaxSpeed,
          car.cameraPicture('front'),
          car.dailyStats,
        ],
        returnsNormally,
        reason: 'seed 6013 case $i ($value)',
      );
      for (final number in [
        car.sessionKwh,
        car.cabinTempC,
        car.homeWeatherC,
        ...car.dailyStats.map((d) => d.distanceKm),
      ]) {
        expect(number == null || number.isFinite, isTrue, reason: 'case $i');
      }
    }
  });

  test('invalid coordinates do not become a map target', () {
    for (final coordinates in [(double.nan, 80.0), (43.0, double.infinity), (91.0, 0.0), (0.0, -181.0)]) {
      expect(state(E.parked, 'home', {'latitude': coordinates.$1, 'longitude': coordinates.$2}).location, isNull);
    }
  });
}
