import '../ha/entities.dart';

/// Seat setting codes used by `kia_uvo.start_climate`.
enum SeatLevel {
  off(0, ''),
  low(6, '1'),
  medium(7, '2'),
  high(8, '3');

  const SeatLevel(this.code, this.badge);
  final int code;
  final String badge;

  SeatLevel get next => SeatLevel.values[(index + 1) % SeatLevel.values.length];
}

class ClimateRequest {
  const ClimateRequest({
    this.tempC = 21,
    this.defrost = false,
    this.wheel = false,
    this.driverSeat = SeatLevel.off,
    this.passengerSeat = SeatLevel.off,
    this.minutes = 10,
  });

  final double tempC;
  final bool defrost, wheel;
  final SeatLevel driverSeat, passengerSeat;
  final int minutes;

  ClimateRequest copyWith({
    double? tempC,
    bool? defrost,
    bool? wheel,
    SeatLevel? driverSeat,
    SeatLevel? passengerSeat,
  }) => ClimateRequest(
    tempC: tempC ?? this.tempC,
    defrost: defrost ?? this.defrost,
    wheel: wheel ?? this.wheel,
    driverSeat: driverSeat ?? this.driverSeat,
    passengerSeat: passengerSeat ?? this.passengerSeat,
    minutes: minutes,
  );
}

/// Every action that physically does something to the car. Each one is
/// triggered from a press-and-hold control and only when commands are on.
sealed class CarCommand {
  const CarCommand();

  String get label;
  String get domain => 'kia_uvo';
  String get service;
  Map<String, dynamic> get data => {'device_id': E.deviceId};
}

class LockCommand extends CarCommand {
  const LockCommand();
  @override
  String get label => 'Lock';
  @override
  String get service => 'lock';
}

class UnlockCommand extends CarCommand {
  const UnlockCommand();
  @override
  String get label => 'Unlock';
  @override
  String get service => 'unlock';
}

class StartClimateCommand extends CarCommand {
  const StartClimateCommand(this.request);
  final ClimateRequest request;
  @override
  String get label => 'Start climate';
  @override
  String get service => 'start_climate';
  @override
  Map<String, dynamic> get data => {
    ...super.data,
    'climate': true,
    'temperature': request.tempC,
    'defrost': request.defrost,
    'heating': request.wheel ? '4' : '0',
    'steering_wheel': request.wheel ? '1' : '0',
    'duration': request.minutes,
    'flseat': '${request.driverSeat.code}',
    'frseat': '${request.passengerSeat.code}',
  };
}

class StopClimateCommand extends CarCommand {
  const StopClimateCommand();
  @override
  String get label => 'Stop climate';
  @override
  String get service => 'stop_climate';
}

class StartChargeCommand extends CarCommand {
  const StartChargeCommand();
  @override
  String get label => 'Start charging';
  @override
  String get service => 'start_charge';
}

class StopChargeCommand extends CarCommand {
  const StopChargeCommand();
  @override
  String get label => 'Stop charging';
  @override
  String get service => 'stop_charge';
}

class SetChargeLimitsCommand extends CarCommand {
  const SetChargeLimitsCommand(this.ac, this.dc);
  final int ac, dc;
  @override
  String get label => 'Set charge limit to $ac%';
  @override
  String get service => 'set_charge_limits';
  @override
  Map<String, dynamic> get data => {...super.data, 'ac_limit': ac, 'dc_limit': dc};
}

class OpenChargePortCommand extends CarCommand {
  const OpenChargePortCommand();
  @override
  String get label => 'Open charge port';
  @override
  String get service => 'open_charge_port';
}

class FlashCommand extends CarCommand {
  const FlashCommand();
  @override
  String get label => 'Flash lights';
  @override
  String get service => 'start_hazard_lights';
}

class HonkCommand extends CarCommand {
  const HonkCommand();
  @override
  String get label => 'Honk and flash';
  @override
  String get service => 'start_hazard_lights_and_horn';
}

/// Valet mode through the ioniq6_extras add-on (Bluelink valet/activate and
/// valet/deactivate with the PIN).
class ValetCommand extends CarCommand {
  const ValetCommand({required this.on});
  final bool on;
  @override
  String get label => on ? 'Turn on valet mode' : 'Turn off valet mode';
  @override
  String get domain => 'switch';
  @override
  String get service => on ? 'turn_on' : 'turn_off';
  @override
  Map<String, dynamic> get data => {'entity_id': E.valet};
}

/// Asks the car for new 360 shots. Wakes the car and counts against
/// Bluelink's daily and monthly limits.
class TakeCameraShotsCommand extends CarCommand {
  const TakeCameraShotsCommand();
  @override
  String get label => 'Take new 360 shots';
  @override
  String get domain => 'ioniq6_extras';
  @override
  String get service => 'take_360_shots';
  @override
  Map<String, dynamic> get data => {};
}

/// Warms the battery for fast charging, or stops (Bluelink evc/prcndtngon,
/// evc/prcndtngoff through the ioniq6_extras add-on).
class PreconditionCommand extends CarCommand {
  const PreconditionCommand({required this.on});
  final bool on;
  @override
  String get label => on ? 'Warm battery' : 'Stop warming battery';
  @override
  String get domain => 'switch';
  @override
  String get service => on ? 'turn_on' : 'turn_off';
  @override
  Map<String, dynamic> get data => {'entity_id': E.preconditioning};
}
