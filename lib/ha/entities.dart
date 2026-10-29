/// Home Assistant entities from the kia_uvo ("Hyundai Canada") integration,
/// plus the walk-away lock helpers. Ids match Arshad's instance.
abstract final class E {
  static const deviceId = '81cb37f577495ac7b13a9404b896222f';

  static const lock = 'lock.ioniq_6_door_lock';
  static const soc = 'sensor.ioniq_6_ev_battery_level';
  static const range = 'sensor.ioniq_6_ev_range';
  static const odometer = 'sensor.ioniq_6_odometer';
  static const twelveVolt = 'sensor.ioniq_6_car_battery_level';
  static const lastUpdated = 'sensor.ioniq_6_last_updated_at';
  static const nextService = 'sensor.ioniq_6_next_service';
  static const dtcCount = 'sensor.ioniq_6_dtc_count';
  static const dailyStats = 'sensor.ioniq_6_daily_driving_stats';
  static const location = 'device_tracker.ioniq_6_location';

  static const charging = 'binary_sensor.ioniq_6_ev_battery_charge';
  static const plugged = 'binary_sensor.ioniq_6_ev_battery_plug';
  static const chargePower = 'sensor.ioniq_6_ev_charging_power';
  static const chargeMinutes = 'sensor.ioniq_6_estimated_charge_duration';
  static const fastChargeMinutes = 'sensor.ioniq_6_estimated_fast_charge_duration';
  static const stationChargeMinutes = 'sensor.ioniq_6_estimated_station_charge_duration';
  static const acLimit = 'number.ioniq_6_ac_charging_limit';
  static const dcLimit = 'number.ioniq_6_dc_charging_limit';

  /// The Ioniq's charging energy and cost, tracked in Home Assistant.
  static const energyMonth = 'sensor.ioniq_6_energy_monthly';
  static const costMonth = 'sensor.ioniq_6_cost_monthly';

  /// The Grizzl-E home charger, shared with the VF9. [chargerVehicle] says
  /// which car it is charging, with the session's kWh as an attribute.
  static const chargerPower = 'sensor.grizzl_e_power';
  static const chargerCharging = 'binary_sensor.grizzl_e_charging';
  static const chargerSessionCost = 'sensor.grizzl_e_session_cost';
  static const chargerVehicle = 'sensor.ev_charging_vehicle_detected';

  static const climateSwitch = 'switch.ioniq_6_climate';
  static const climate = 'climate.ioniq_6_climate_control';

  /// Home Assistant's own weather at home, for the outside temperature when the car is at home or its location is unknown.
  static const weather = 'weather.forecast_home';
  static const setTemp = 'sensor.ioniq_6_set_temperature';
  static const defrost = 'binary_sensor.ioniq_6_defrost';
  static const wheelHeat = 'binary_sensor.ioniq_6_steering_wheel_heater';

  static const engine = 'binary_sensor.ioniq_6_engine';
  static const hood = 'binary_sensor.ioniq_6_hood';
  static const trunk = 'binary_sensor.ioniq_6_trunk';
  static const doors = {
    'Front left': 'binary_sensor.ioniq_6_front_left_door',
    'Front right': 'binary_sensor.ioniq_6_front_right_door',
    'Rear left': 'binary_sensor.ioniq_6_back_left_door',
    'Rear right': 'binary_sensor.ioniq_6_back_right_door',
  };
  static const tires = {
    'FL': 'binary_sensor.ioniq_6_tire_pressure_front_left',
    'FR': 'binary_sensor.ioniq_6_tire_pressure_front_right',
    'RL': 'binary_sensor.ioniq_6_tire_pressure_rear_left',
    'RR': 'binary_sensor.ioniq_6_tire_pressure_rear_right',
  };
  static const tiresAll = 'binary_sensor.ioniq_6_tire_pressure_all';
  static const brakeFluid = 'binary_sensor.ioniq_6_brake_fluid_warning';
  static const washerFluid = 'binary_sensor.ioniq_6_washer_fluid_warning';
  static const lampFaults = [
    'binary_sensor.ioniq_6_front_left_lamp_fault',
    'binary_sensor.ioniq_6_front_right_lamp_fault',
    'binary_sensor.ioniq_6_headlamp_left_high_fault',
    'binary_sensor.ioniq_6_headlamp_right_high_fault',
    'binary_sensor.ioniq_6_headlamp_left_bifunctional_fault',
    'binary_sensor.ioniq_6_headlamp_right_bifunctional_fault',
    'binary_sensor.ioniq_6_rear_left_lamp_fault',
    'binary_sensor.ioniq_6_rear_right_lamp_fault',
    'binary_sensor.ioniq_6_turn_signal_left_front',
    'binary_sensor.ioniq_6_turn_signal_right_front',
    'binary_sensor.ioniq_6_turn_signal_left_rear',
    'binary_sensor.ioniq_6_turn_signal_right_rear',
  ];

  static const phoneConnected = 'binary_sensor.phone_connected_to_ioniq_6';
  static const walkAwayDryRun = 'input_boolean.walk_away_lock_dry_run';

  /// Everything the app subscribes to.
  static List<String> get all => [
    lock,
    soc,
    range,
    odometer,
    twelveVolt,
    lastUpdated,
    nextService,
    dtcCount,
    dailyStats,
    location,
    charging,
    plugged,
    chargePower,
    chargeMinutes,
    fastChargeMinutes,
    stationChargeMinutes,
    acLimit,
    dcLimit,
    energyMonth,
    costMonth,
    chargerPower,
    chargerCharging,
    chargerSessionCost,
    chargerVehicle,
    climateSwitch,
    climate,
    weather,
    setTemp,
    defrost,
    wheelHeat,
    engine,
    hood,
    trunk,
    ...doors.values,
    ...tires.values,
    tiresAll,
    brakeFluid,
    washerFluid,
    ...lampFaults,
    phoneConnected,
    walkAwayDryRun,
  ];

  /// Entities whose changes show up on the Activity screen.
  static const activity = [lock, charging, plugged, climateSwitch, phoneConnected, engine, trunk];
}
