import '../ha/entities.dart';
import '../ha/ha_client.dart';
import 'bluelink_client.dart';

/// Turns a Bluelink status into the same entity states Home Assistant would
/// give, so the rest of the app reads the car the same way from either path.
/// Anything Bluelink leaves out is left out here too, and keeps its last value.
List<EntityState> statesFromBluelink(Map<String, dynamic> status, {({int? ac, int? dc})? limits, DateTime? now}) {
  final at = now ?? DateTime.now();
  final out = <EntityState>[];
  void put(String id, Object? value) {
    if (value != null) out.add(EntityState(id, '$value', const {}, at));
  }

  void flag(String id, Object? value) {
    if (value is bool) put(id, value ? 'on' : 'off');
    if (value is num) put(id, value > 0 ? 'on' : 'off');
  }

  Object? at_(List<Object> path) {
    Object? node = status;
    for (final key in path) {
      node = switch (node) {
        final Map m => m[key],
        final List l when key is int && key < l.length => l[key],
        _ => null,
      };
    }
    return node;
  }

  final locked = status['doorLock'];
  if (locked is bool) put(E.lock, locked ? 'locked' : 'unlocked');
  put(E.lastUpdated, _reported(status['lastStatusDate'])?.toUtc().toIso8601String());
  flag(E.engine, status['engine']);
  flag(E.hood, status['hoodOpen']);
  flag(E.trunk, status['trunkOpen']);
  const doors = {
    'Front left': 'frontLeft',
    'Front right': 'frontRight',
    'Rear left': 'backLeft',
    'Rear right': 'backRight',
  };
  for (final MapEntry(:key, :value) in doors.entries) {
    flag(E.doors[key]!, at_(['doorOpen', value]));
  }
  const tires = {
    'FL': 'tirePressureLampFL',
    'FR': 'tirePressureLampFR',
    'RL': 'tirePressureLampRL',
    'RR': 'tirePressureLampRR',
  };
  for (final MapEntry(:key, :value) in tires.entries) {
    flag(E.tires[key]!, at_(['tirePressureLamp', value]));
  }
  flag(E.tiresAll, at_(['tirePressureLamp', 'tirePressureLampAll']));
  flag(E.washerFluid, status['washerFluidStatus']);
  flag(E.brakeFluid, status['breakOilStatus']);

  final twelveVolt = at_(['battery', 'batSoc']);
  if (twelveVolt is num && twelveVolt >= 0 && twelveVolt <= 100) put(E.twelveVolt, twelveVolt);

  flag(E.climateSwitch, status['airCtrlOn']);
  flag(E.defrost, status['defrost']);
  flag(E.wheelHeat, status['steerWheelHeat']);
  put(E.setTemp, BluelinkClient.tempFromCode(at_(['airTemp', 'value'])));

  put(E.soc, at_(['evStatus', 'batteryStatus']));
  flag(E.charging, at_(['evStatus', 'batteryCharge']));
  flag(E.plugged, at_(['evStatus', 'batteryPlugin']));
  flag(E.preconditioning, at_(['evStatus', 'batteryPreconditiong']));
  final range = at_(['evStatus', 'drvDistance', 0, 'rangeByFuel', 'evModeRange', 'value']);
  final unit = at_(['evStatus', 'drvDistance', 0, 'rangeByFuel', 'evModeRange', 'unit']);
  // Unit 1 is kilometres; 2 and 3 are miles.
  if (range is num) put(E.range, unit == 2 || unit == 3 ? range * 1.609344 : range);
  put(E.chargeMinutes, at_(['evStatus', 'remainTime2', 'atc', 'value']));
  put(E.fastChargeMinutes, at_(['evStatus', 'remainTime2', 'etc1', 'value']));
  put(E.stationChargeMinutes, at_(['evStatus', 'remainTime2', 'etc3', 'value']));

  put(E.acLimit, limits?.ac);
  put(E.dcLimit, limits?.dc);
  return out;
}

/// lastStatusDate is "yyyyMMddHHmmss" in the car's own clock, which is taken
/// to be the phone's time zone.
DateTime? _reported(Object? value) {
  if (value is! String || value.length != 14) return null;
  final n = [0, 4, 6, 8, 10, 12, 14];
  final parts = [for (var i = 0; i < 6; i++) int.tryParse(value.substring(n[i], n[i + 1]))];
  if (parts.contains(null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!, parts[3]!, parts[4]!, parts[5]!);
}
