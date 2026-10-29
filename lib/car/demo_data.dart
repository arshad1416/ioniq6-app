import '../ha/entities.dart';
import '../ha/ha_client.dart';

/// A snapshot of the real car on 2026-10-29, used in demo mode and tests.
Map<String, EntityState> demoStates() {
  final now = DateTime.now();
  EntityState s(String id, String state, [Map<String, dynamic> attrs = const {}]) =>
      EntityState(id, state, attrs, now.subtract(const Duration(hours: 2)));
  final today = DateTime(now.year, now.month, now.day);
  String day(int ago) => today.subtract(Duration(days: ago)).toIso8601String().substring(0, 10);
  return {
    for (final e in [
      s(E.lock, 'locked'),
      s(E.soc, '74'),
      s(E.range, '328.0'),
      s(E.odometer, '76744.0'),
      s(E.twelveVolt, '81'),
      s(E.lastUpdated, now.subtract(const Duration(minutes: 38)).toUtc().toIso8601String()),
      s(E.nextService, '43800.0'),
      s(E.dtcCount, '0'),
      s(E.dailyStats, '3', {
        day(2): {'total_consumed': 791, 'climate_consumption': 243, 'regenerated_energy': 1815, 'distance': 8},
        day(3): {'total_consumed': 34, 'climate_consumption': 6, 'regenerated_energy': 0, 'distance': 1},
        day(4): {'total_consumed': 775, 'climate_consumption': 51, 'regenerated_energy': 1214, 'distance': 8},
      }),
      s(E.location, 'home'),
      s(E.charging, 'off'),
      s(E.plugged, 'off'),
      s(E.chargePower, 'unknown'),
      s(E.energyMonth, '131.52'),
      s(E.costMonth, '8.94'),
      s(E.chargerPower, '0.0'),
      s(E.chargerCharging, 'off'),
      s(E.chargerSessionCost, '3.28'),
      s(E.chargerVehicle, 'ioniq_6', {'session_kwh': 48.35}),
      s(E.chargeMinutes, '0'),
      s(E.fastChargeMinutes, '22'),
      s(E.stationChargeMinutes, '90'),
      s(E.acLimit, '90'),
      s(E.dcLimit, '90'),
      s(E.climateSwitch, 'off'),
      s(E.climate, 'off', {'current_temperature': 14, 'temperature': 21}),
      s(E.weather, 'cloudy', {'temperature': 3}),
      s(E.setTemp, '21.0'),
      s(E.defrost, 'off'),
      s(E.wheelHeat, 'off'),
      s(E.engine, 'off'),
      s(E.hood, 'off'),
      s(E.trunk, 'off'),
      for (final id in E.doors.values) s(id, 'off'),
      for (final id in E.tires.values) s(id, 'off'),
      s(E.tiresAll, 'off'),
      s(E.brakeFluid, 'off'),
      s(E.washerFluid, 'off'),
      for (final id in E.lampFaults) s(id, 'off'),
      s(E.phoneConnected, 'off'),
      s(E.walkAwayDryRun, 'on'),
    ])
      e.entityId: e,
  };
}
