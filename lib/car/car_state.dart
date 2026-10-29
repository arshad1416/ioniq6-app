import '../ha/entities.dart';
import '../ha/ha_client.dart';

enum DoorLock { locked, unlocked, locking, unlocking, error, unknown }

/// One day from the integration's daily driving stats (energy in Wh).
class DailyStat {
  DailyStat(this.day, this.distanceKm, this.consumedWh, this.regenWh, this.climateWh);
  final DateTime day;
  final num distanceKm, consumedWh, regenWh, climateWh;
}

/// A read-only view of the car built from Home Assistant entity states.
class CarState {
  const CarState(this._s);
  final Map<String, EntityState> _s;

  static const empty = CarState({});

  bool get hasData => _s.containsKey(E.soc);

  String? _str(String id) {
    final v = _s[id]?.state;
    return (v == null || v == 'unknown' || v == 'unavailable') ? null : v;
  }

  double? _num(String id) => double.tryParse(_str(id) ?? '');
  bool _on(String id) => _str(id) == 'on';
  Map<String, dynamic> _attrs(String id) => _s[id]?.attributes ?? const {};

  DoorLock get lock => switch (_str(E.lock)) {
    'locked' => DoorLock.locked,
    'unlocked' => DoorLock.unlocked,
    'locking' => DoorLock.locking,
    'unlocking' => DoorLock.unlocking,
    'jammed' => DoorLock.error,
    _ => DoorLock.unknown,
  };
  bool get isLocked => lock == DoorLock.locked;

  int? get soc => _num(E.soc)?.round();
  int? get rangeKm => _num(E.range)?.round();
  int? get odometerKm => _num(E.odometer)?.round();
  int? get twelveVoltPct => _num(E.twelveVolt)?.round();
  int? get nextServiceKm => _num(E.nextService)?.round();
  int get dtcCount => _num(E.dtcCount)?.round() ?? 0;
  DateTime? get lastUpdated => DateTime.tryParse(_str(E.lastUpdated) ?? '')?.toLocal();

  bool get charging => _on(E.charging);
  bool get plugged => _on(E.plugged);
  double? get chargeKw => _num(E.chargePower);
  int? get chargeMinutesLeft => _num(E.chargeMinutes)?.round();
  int? get fastChargeMinutes => _num(E.fastChargeMinutes)?.round();
  int? get stationChargeMinutes => _num(E.stationChargeMinutes)?.round();
  int get acLimit => _num(E.acLimit)?.round() ?? 90;
  int get dcLimit => _num(E.dcLimit)?.round() ?? 90;

  /// Whether the home charger's last or current session is this car.
  bool get onHomeCharger => _str(E.chargerVehicle) == 'ioniq_6';
  bool get homeChargerCharging => onHomeCharger && _on(E.chargerCharging);

  /// Charging power: the home charger's own meter while it charges this car,
  /// otherwise what the car reports.
  double? get chargeRateKw {
    final w = _num(E.chargerPower);
    if (homeChargerCharging && w != null && w > 0) return w / 1000;
    return chargeKw;
  }

  double? get sessionKwh => onHomeCharger ? (_attrs(E.chargerVehicle)['session_kwh'] as num?)?.toDouble() : null;
  double? get sessionCost => onHomeCharger ? _num(E.chargerSessionCost) : null;
  double? get energyMonthKwh => _num(E.energyMonth);
  double? get costMonth => _num(E.costMonth);

  bool get climateOn => _on(E.climateSwitch) || (_str(E.climate) != null && _str(E.climate) != 'off');
  double? get setTempC => _num(E.setTemp);
  double? get cabinTempC => (_attrs(E.climate)['current_temperature'] as num?)?.toDouble();

  /// Home Assistant's weather, which is for home, not necessarily where the car is.
  double? get homeWeatherC => (_attrs(E.weather)['temperature'] as num?)?.toDouble();
  bool get atHome => _str(E.location) == 'home';
  bool get defrostOn => _on(E.defrost);
  bool get wheelHeatOn => _on(E.wheelHeat);

  bool get engineOn => _on(E.engine);
  bool get hoodOpen => _on(E.hood);
  bool get trunkOpen => _on(E.trunk);
  List<String> get openDoors => [
    for (final MapEntry(:key, :value) in E.doors.entries)
      if (_on(value)) key,
  ];
  bool get allClosed => openDoors.isEmpty && !hoodOpen && !trunkOpen;

  Map<String, bool> get tireWarnings => {for (final MapEntry(:key, :value) in E.tires.entries) key: _on(value)};
  bool get tiresOk => !_on(E.tiresAll) && !tireWarnings.containsValue(true);
  bool get lampsOk => !E.lampFaults.any(_on);
  bool get brakeFluidOk => !_on(E.brakeFluid);
  bool get washerFluidOk => !_on(E.washerFluid);
  bool get healthOk => tiresOk && lampsOk && brakeFluidOk && washerFluidOk && dtcCount == 0;

  bool get phoneConnected => _on(E.phoneConnected);
  bool get walkAwayDryRun => _str(E.walkAwayDryRun) != 'off';

  (double, double)? get location {
    final a = _attrs(E.location);
    final lat = a['latitude'], lon = a['longitude'];
    return (lat is num && lon is num) ? (lat.toDouble(), lon.toDouble()) : null;
  }

  List<DailyStat> get dailyStats {
    final out = <DailyStat>[];
    for (final MapEntry(:key, :value) in _attrs(E.dailyStats).entries) {
      final day = DateTime.tryParse(key);
      if (day == null || value is! Map) continue;
      out.add(
        DailyStat(
          day,
          value['distance'] as num? ?? 0,
          value['total_consumed'] as num? ?? 0,
          value['regenerated_energy'] as num? ?? 0,
          value['climate_consumption'] as num? ?? 0,
        ),
      );
    }
    return out..sort((a, b) => b.day.compareTo(a.day));
  }

  CarState withEntity(EntityState e) => CarState({..._s, e.entityId: e});
}
