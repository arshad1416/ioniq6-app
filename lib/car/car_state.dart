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

  Iterable<EntityState> get entities => _s.values;

  /// The Hyundai integration's core entities exist.
  bool get hasCar => _s.containsKey(E.soc) || _s.containsKey(E.lock);

  String? _str(String id) {
    final v = _s[id]?.state;
    return (v == null || v == 'unknown' || v == 'unavailable') ? null : v;
  }

  static double? _finite(Object? value) {
    if (value is! num) return null;
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }

  double? _num(String id) => _finite(double.tryParse(_str(id) ?? ''));
  bool _on(String id) => _str(id) == 'on';

  /// On, off, or null when Home Assistant doesn't know.
  bool? _flag(String id) => switch (_str(id)) {
    'on' => true,
    'off' => false,
    _ => null,
  };

  /// True when all are known off, false when any is on, else null.
  bool? _noneOn(Iterable<String> ids) {
    final flags = ids.map(_flag);
    if (flags.contains(true)) return false;
    return flags.contains(null) ? null : true;
  }

  static bool? _all(Iterable<bool?> parts) {
    if (parts.contains(false)) return false;
    return parts.contains(null) ? null : true;
  }

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
  int? get dtcCount => _num(E.dtcCount)?.round();
  DateTime? get lastUpdated => DateTime.tryParse(_str(E.lastUpdated) ?? '')?.toLocal();

  bool get charging => _on(E.charging);
  bool get plugged => _on(E.plugged);
  double? get chargeKw => _num(E.chargePower);
  int? get chargeMinutesLeft => _num(E.chargeMinutes)?.round();
  int? get fastChargeMinutes => _num(E.fastChargeMinutes)?.round();
  int? get stationChargeMinutes => _num(E.stationChargeMinutes)?.round();
  int? get acLimit => _num(E.acLimit)?.round();
  int? get dcLimit => _num(E.dcLimit)?.round();

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

  double? get sessionKwh => onHomeCharger ? _finite(_attrs(E.chargerVehicle)['session_kwh']) : null;
  double? get sessionCost => onHomeCharger ? _num(E.chargerSessionCost) : null;
  double? get energyMonthKwh => _num(E.energyMonth);
  double? get costMonth => _num(E.costMonth);

  bool get climateOn => _on(E.climateSwitch) || (_str(E.climate) != null && _str(E.climate) != 'off');
  double? get setTempC => _num(E.setTemp);
  double? get cabinTempC => _finite(_attrs(E.climate)['current_temperature']);

  /// Home Assistant's weather, which is for home, not necessarily where the car is.
  double? get homeWeatherC => _finite(_attrs(E.weather)['temperature']);
  bool get atHome => parkedAt == 'home';
  bool get defrostOn => _on(E.defrost);
  bool get wheelHeatOn => _on(E.wheelHeat);

  bool get engineOn => _on(E.engine);
  bool? get hoodOpen => _flag(E.hood);
  bool? get trunkOpen => _flag(E.trunk);
  List<String> get openDoors => [
    for (final MapEntry(:key, :value) in E.doors.entries)
      if (_on(value)) key,
  ];

  /// Null when a door's state isn't known.
  bool? get doorsClosed => _noneOn(E.doors.values);
  bool? get allClosed => _noneOn([...E.doors.values, E.hood, E.trunk]);

  Map<String, bool> get tireWarnings => {for (final MapEntry(:key, :value) in E.tires.entries) key: _on(value)};
  // Each is null when Home Assistant doesn't know, so a broken integration
  // never reads as a healthy car.
  bool? get tiresOk => _noneOn([E.tiresAll, ...E.tires.values]);
  bool? get lampsOk => _noneOn(E.lampFaults);
  bool? get brakeFluidOk => _noneOn([E.brakeFluid]);
  bool? get washerFluidOk => _noneOn([E.washerFluid]);
  bool? get healthOk => _all([tiresOk, lampsOk, brakeFluidOk, washerFluidOk, dtcCount == null ? null : dtcCount == 0]);

  bool get phoneConnected => _on(E.phoneConnected);
  bool? get walkAwayDryRun => _flag(E.walkAwayDryRun);

  /// Where the car is: the add-on's parked fix when it has one, else the
  /// integration's (which it rarely fetches).
  (double, double)? get location {
    for (final id in [E.parked, E.location]) {
      final a = _attrs(id);
      final lat = a['latitude'], lon = a['longitude'];
      final latitude = _finite(lat), longitude = _finite(lon);
      if (latitude != null && longitude != null && latitude.abs() <= 90 && longitude.abs() <= 180) {
        return (latitude, longitude);
      }
    }
    return null;
  }

  /// "home", a zone's name, or the street, for "Parked at …".
  String? get parkedAt {
    final zone = _str(E.parked) ?? _str(E.location);
    if (zone == 'home') return 'home';
    if (zone != null && zone != 'not_home') return zone;
    final address = _attrs(E.parked)['address'];
    return address is String && address.isNotEmpty ? address : null;
  }

  /// Valet mode as the car reports it; null until the add-on is installed.
  bool? get valetOn => switch (_str(E.valet)) {
    'on' => true,
    'off' => false,
    _ => null,
  };

  /// Battery warming for fast charging; null until the add-on is installed.
  bool? get preconditioningOn => switch (_str(E.preconditioning)) {
    'on' => true,
    'off' => false,
    _ => null,
  };

  int? get valetMaxSpeed => _finite(_attrs(E.valet)['maxSpeed'])?.round();

  /// The image entity's own URL (path plus access token) for a 360 view.
  String? cameraPicture(String view) {
    final value = _attrs(E.camera(view))['entity_picture'];
    return value is String && value.isNotEmpty ? value : null;
  }

  DateTime? get cameraTakenAt => DateTime.tryParse(_str(E.camera('front')) ?? '')?.toLocal();
  bool get hasCamera => _s.containsKey(E.camera('front'));

  DateTime? get locatedAt => DateTime.tryParse('${_attrs(E.parked)['located_at']}')?.toLocal();

  List<DailyStat> get dailyStats {
    final out = <DailyStat>[];
    for (final MapEntry(:key, :value) in _attrs(E.dailyStats).entries) {
      final day = DateTime.tryParse(key);
      if (day == null || value is! Map) continue;
      out.add(
        DailyStat(
          day,
          _finite(value['distance']) ?? 0,
          _finite(value['total_consumed']) ?? 0,
          _finite(value['regenerated_energy']) ?? 0,
          _finite(value['climate_consumption']) ?? 0,
        ),
      );
    }
    return out..sort((a, b) => b.day.compareTo(a.day));
  }

  CarState withEntity(EntityState e) => CarState({..._s, e.entityId: e});

  CarState withEntities(Iterable<EntityState> changed) => CarState({..._s, for (final e in changed) e.entityId: e});
}
