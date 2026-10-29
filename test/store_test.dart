import 'dart:async';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_state.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/commands.dart';
import 'package:ioniq6_companion/car/demo_data.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/ha/entities.dart';
import 'package:ioniq6_companion/ha/ha_client.dart';

/// Stands in for Home Assistant: records service calls, never touches a car.
class FakeHa extends HaClient {
  FakeHa() : super(baseUrl: Uri.parse('http://ha.test:8123'), token: 't');

  final calls = <(String, String, Map<String, dynamic>)>[];
  final updates = StreamController<EntityState>();

  @override
  Future<List<EntityState>> states(Iterable<String> ids) async => demoStates().values.toList();

  @override
  Stream<EntityState> subscribe(List<String> ids) => updates.stream;

  @override
  Future<void> callService(String domain, String service, Map<String, dynamic> data) async =>
      calls.add((domain, service, data));

  @override
  Future<List<EntityState>> history(List<String> ids, DateTime start) async => [];

  @override
  Future<void> close() async {}
}

Future<(CarStore, FakeHa)> liveStore({bool commands = false}) async {
  final backend = MemorySettingsBackend()
    ..values.addAll({'haUrl': 'http://ha.test:8123', 'token': 't', 'demo': 'false', 'commandsEnabled': '$commands'});
  final fake = FakeHa();
  final store = CarStore(Settings(backend), clientFactory: (_, _) => fake);
  await store.start();
  return (store, fake);
}

void main() {
  test('reads the car from entity states', () {
    final car = CarState(demoStates());
    expect(car.soc, 74);
    expect(car.rangeKm, 328);
    expect(car.lock, DoorLock.locked);
    expect(car.allClosed, isTrue);
    expect(car.healthOk, isTrue);
    expect(car.dailyStats, hasLength(3));
  });

  test('starts in demo mode until Home Assistant is set up', () async {
    final store = CarStore(Settings(MemorySettingsBackend()));
    await store.start();
    expect(store.connection, Connection.demo);
    await store.send(const UnlockCommand());
    expect(store.car.lock, DoorLock.unlocked);
  });

  test('refuses car commands while they are switched off', () async {
    final (store, fake) = await liveStore();
    expect(store.connection, Connection.live);
    await expectLater(store.send(const LockCommand()), throwsA(isA<CommandsDisabled>()));
    expect(fake.calls, isEmpty);
  });

  test('sends commands to kia_uvo and waits for the entity to confirm', () async {
    final (store, fake) = await liveStore(commands: true);
    await store.send(const UnlockCommand());
    expect(fake.calls.single.$2, 'unlock');
    expect(fake.calls.single.$3['device_id'], E.deviceId);
    expect(store.lockState, DoorLock.unlocking);

    fake.updates.add(demoStates()[E.lock]!.copyWith(state: 'unlocked'));
    await Future<void>.delayed(Duration.zero);
    expect(store.pending, isNull);
    expect(store.lockState, DoorLock.unlocked);
  });

  test('climate request maps seats and wheel to service fields', () {
    final data = const StartClimateCommand(ClimateRequest(tempC: 22.5, wheel: true, driverSeat: SeatLevel.high)).data;
    expect(data['temperature'], 22.5);
    expect(data['flseat'], '8');
    expect(data['frseat'], '0');
    expect(data['steering_wheel'], '1');
  });

  test('retries quietly before showing a connection error', () {
    fakeAsync((time) {
      final backend = MemorySettingsBackend()
        ..values.addAll({'haUrl': 'http://ha.test:8123', 'token': 't', 'demo': 'false'});
      var attempts = 0;
      final store = CarStore(
        Settings(backend),
        clientFactory: (_, _) {
          attempts++;
          if (attempts <= 2) throw Exception('Failed host lookup');
          return FakeHa();
        },
      );
      final seen = <Connection>[];
      store.addListener(() => seen.add(store.connection));
      store.start();
      time.elapse(const Duration(seconds: 10));
      expect(store.connection, Connection.live);
      expect(seen, isNot(contains(Connection.error)));
    });
  });
}
