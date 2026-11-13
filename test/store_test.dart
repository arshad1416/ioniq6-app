import 'dart:async';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_state.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/commands.dart';
import 'package:ioniq6_companion/car/demo_data.dart';
import 'package:ioniq6_companion/car/health.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/ha/entities.dart';
import 'package:ioniq6_companion/ha/ha_client.dart';

/// Stands in for Home Assistant: records service calls, never touches a car.
class FakeHa extends HaClient {
  FakeHa() : super(baseUrl: Uri.parse('http://ha.test:8123'), token: 't');

  final calls = <(String, String, Map<String, dynamic>)>[];
  final updates = StreamController<List<EntityState>>();
  List<Map<String, dynamic>> registry = [
    for (final id in E.all) {'entity_id': id, 'unique_id': 'u-$id', 'platform': 'kia_uvo', 'device_id': E.deviceId},
  ];
  List<String> subscribed = [];
  Object? pingError;
  List<String>? historyIds;
  String? statisticsId;
  List<EntityState> historyResult = [];

  @override
  Future<List<Map<String, dynamic>>> entityRegistry() async => registry;

  @override
  Stream<List<EntityState>> subscribe(List<String> ids) {
    subscribed = ids;
    updates.add(demoStates().values.toList());
    return updates.stream;
  }

  @override
  Future<void> ping() async {
    if (pingError != null) throw pingError!;
  }

  @override
  Future<void> callService(String domain, String service, Map<String, dynamic> data) async =>
      calls.add((domain, service, data));

  @override
  Future<List<EntityState>> history(List<String> ids, DateTime start) async {
    historyIds = ids;
    return historyResult;
  }

  @override
  Future<List<Map<String, dynamic>>> statistics(String id, DateTime start, {String period = 'month'}) async {
    statisticsId = id;
    return [];
  }

  @override
  Future<void> close() async {}
}

MemorySettingsBackend configured({bool commands = false}) =>
    MemorySettingsBackend()
      ..values.addAll({'haUrl': 'http://ha.test:8123', 'token': 't', 'demo': 'false', 'commandsEnabled': '$commands'});

Future<(CarStore, FakeHa)> liveStore({bool commands = false, MemorySettingsBackend? backend}) async {
  final fake = FakeHa();
  final store = CarStore(Settings(backend ?? configured(commands: commands)), clientFactory: (_, _) => fake);
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

    fake.updates.add([demoStates()[E.lock]!.copyWith(state: 'unlocked')]);
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

  test('an empty car is unknown, not healthy', () {
    const car = CarState.empty;
    expect(car.healthOk, isNull);
    expect(car.allClosed, isNull);
    expect(car.tiresOk, isNull);
    expect(car.acLimit, isNull);
  });

  test('shows the saved snapshot when Home Assistant is unreachable at launch', () {
    fakeAsync((time) {
      final backend = configured();
      liveStore(backend: backend);
      time.elapse(const Duration(seconds: 5)); // the snapshot is written shortly after data arrives
      expect(backend.values['cache.carSnapshot'], isNotNull);

      final offline = CarStore(Settings(backend), clientFactory: (_, _) => throw Exception('Failed host lookup'));
      offline.start();
      time.elapse(const Duration(seconds: 30));
      expect(offline.connection, Connection.error);
      expect(offline.health.link, Link.noNetwork);
      expect(offline.car.soc, 74);
      expect(offline.showingSaved, isTrue);
      expect(offline.dataAt, isNotNull);
      offline.dispose();
    });
  });

  test('a rejected token is reported once and not retried', () {
    fakeAsync((time) {
      var attempts = 0;
      final store = CarStore(
        Settings(configured()),
        clientFactory: (_, _) {
          attempts++;
          throw HaAuthException();
        },
      );
      store.start();
      time.elapse(const Duration(minutes: 5));
      expect(store.health.link, Link.tokenRejected);
      expect(attempts, 1);
    });
  });

  test('keeps the last values when the Hyundai integration goes unavailable', () async {
    final (store, fake) = await liveStore(commands: true);
    expect(store.health.link, Link.ok);
    fake.updates.add([
      demoStates()[E.soc]!.copyWith(state: 'unavailable'),
      demoStates()[E.lock]!.copyWith(state: 'unavailable'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(store.health.link, Link.carUnavailable);
    expect(store.car.soc, 74);
    expect(store.showingSaved, isTrue);
    await expectLater(store.send(const LockCommand()), throwsA(isA<PathDown>()));
    expect(fake.calls, isEmpty);

    fake.updates.add([demoStates()[E.soc]!, demoStates()[E.lock]!]);
    await Future<void>.delayed(Duration.zero);
    expect(store.health.link, Link.ok);
  });

  test('says when Home Assistant has no Hyundai integration', () async {
    final fake = FakeHa()..registry = [];
    final store = CarStore(Settings(configured()), clientFactory: (_, _) => fake);
    await store.start();
    expect(store.health.link, Link.integrationMissing);
  });

  test('sends commands to the device Home Assistant has now', () async {
    final fake = FakeHa();
    fake.registry = [
      for (final e in fake.registry) {...e, 'device_id': 'dev-new'},
    ];
    final store = CarStore(Settings(configured(commands: true)), clientFactory: (_, _) => fake);
    await store.start();
    await store.send(const LockCommand());
    expect(fake.calls.single.$3['device_id'], 'dev-new');
  });

  test('reconnects on resume when the socket has died', () async {
    final fakes = <FakeHa>[];
    final store = CarStore(
      Settings(configured()),
      clientFactory: (_, _) {
        fakes.add(FakeHa());
        return fakes.last;
      },
    );
    await store.start();
    await store.onResume();
    expect(fakes, hasLength(1)); // the socket answered, nothing to do

    fakes.single.pingError = Exception('dead');
    await store.onResume();
    expect(fakes, hasLength(2));
    expect(store.connection, Connection.live);
  });

  test('tries the home-network address first and falls back to the remote one', () async {
    final backend = configured()..values['haLocalUrl'] = 'http://192.168.1.5:8123';
    final tried = <String>[];
    final store = CarStore(
      Settings(backend),
      clientFactory: (url, _) {
        tried.add(url.host);
        if (url.host == '192.168.1.5') throw Exception('Connection refused');
        return FakeHa();
      },
    );
    await store.start();
    expect(tried, ['192.168.1.5', 'ha.test']);
    expect(store.connection, Connection.live);
  });
  test('charge limits remain pending until both AC and DC are confirmed', () async {
    final (store, fake) = await liveStore(commands: true);
    addTearDown(store.dispose);
    final ac = store.car.acLimit!;
    final dc = store.car.dcLimit == 80 ? 90 : 80;
    await store.send(SetChargeLimitsCommand(ac, dc));
    expect(store.pending, isA<SetChargeLimitsCommand>());
    fake.updates.add([demoStates()[E.dcLimit]!.copyWith(state: '$dc')]);
    await Future<void>.delayed(Duration.zero);
    expect(store.pending, isNull);
  });

  test('history and statistics follow renamed entities', () async {
    final fake = FakeHa();
    fake.registry = [
      for (final e in fake.registry) {...e, 'entity_id': '${e['entity_id']}_2'},
    ];
    final then = DateTime(2026, 11, 1);
    fake.historyResult = [
      EntityState('${E.lock}_2', 'locked', {}, then),
      EntityState('${E.lock}_2', 'unlocked', {}, then.add(const Duration(minutes: 1))),
    ];
    final store = CarStore(Settings(configured()), clientFactory: (_, _) => fake);
    addTearDown(store.dispose);
    await store.start();
    await store.loadHistory();
    expect(fake.historyIds, [for (final id in E.activity) '${id}_2']);
    expect(store.activity.map((a) => a.title), contains('Unlocked'));
    await store.monthlyOdometer();
    expect(fake.statisticsId, '${E.odometer}_2');
  });
}
