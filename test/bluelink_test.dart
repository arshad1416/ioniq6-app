import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ioniq6_companion/bluelink/bluelink_client.dart';
import 'package:ioniq6_companion/bluelink/bluelink_states.dart';
import 'package:ioniq6_companion/car/car_state.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/commands.dart';
import 'package:ioniq6_companion/car/health.dart';
import 'package:ioniq6_companion/car/settings.dart';

const ok = {'responseCode': 0};
Map<String, dynamic> fail(String code) => {
  'responseHeader': {'responseCode': 1},
  'error': {'errorCode': code, 'errorDesc': 'error $code'},
};

const status = {
  'lastStatusDate': '20261112093000',
  'doorLock': false,
  'engine': false,
  'hoodOpen': false,
  'trunkOpen': true,
  'doorOpen': {'frontLeft': 0, 'frontRight': 0, 'backLeft': 0, 'backRight': 0},
  'airCtrlOn': false,
  'airTemp': {'value': '0EH', 'unit': 0},
  'battery': {'batSoc': 81},
  'evStatus': {
    'batteryStatus': 62,
    'batteryCharge': false,
    'batteryPlugin': 0,
    'drvDistance': [
      {
        'rangeByFuel': {
          'evModeRange': {'value': 270, 'unit': 1},
        },
      },
    ],
  },
};

/// Stands in for Bluelink: records every request, never touches a car.
class FakeBluelink {
  final requests = <(String, Map<String, String>, Map<String, dynamic>?)>[];
  bool wantOtp = false;
  int expiredAnswers = 0;
  int pending = 0;

  late final client = MockClient((request) async {
    final path = request.url.path.replaceFirst('/tods/api/', '');
    final body = request.body.isEmpty ? null : jsonDecode(request.body) as Map<String, dynamic>;
    requests.add((path, request.headers, body));
    Map<String, dynamic> result(Object? value) => {'responseHeader': ok, 'result': value};
    final token = {'accessToken': 'access-${requests.length}', 'refreshToken': 'refresh', 'expireIn': '3600'};
    final (Map<String, dynamic> json, Map<String, String> headers) = switch (path) {
      'v2/login' when wantOtp => (fail('7110'), const {}),
      'v2/login' => (result({'token': token}), const {}),
      'mfa/selverifmeth' => (
        result({
          'userInfoUuid': 'uuid',
          'emailList': ['me@example.com'],
        }),
        const {},
      ),
      'mfa/sendotp' => (result({'otpKey': 'key'}), const {}),
      'mfa/validateotp' => (result({'verifiedOtp': true, 'otpValidationKey': 'valid'}), const {}),
      'mfa/genmfatkn' => (result({'token': token}), const {}),
      'gtothbyrftkn' => (result(token), const {}),
      'vhcllst' => (
        result({
          'vehicles': [
            {'vehicleId': 'car-1'},
          ],
        }),
        const {},
      ),
      'lstvhclsts' || 'rltmvhclsts' when expiredAnswers > 0 => () {
        expiredAnswers--;
        return (fail('7403'), const <String, String>{});
      }(),
      'lstvhclsts' || 'rltmvhclsts' => (result({'status': status}), const {}),
      'evc/selsoc' => (
        {
          'responseHeader': ok,
          'result': [
            {'plugType': 0, 'level': 80},
            {'plugType': 1, 'level': 90},
          ],
        },
        const {},
      ),
      'vrfypin' => (result({'pAuth': 'pauth'}), const {}),
      'rmtsts' => (
        result({
          'transaction': {'apiResult': pending-- > 0 ? 'P' : 'C'},
        }),
        const {},
      ),
      _ => (result(const {}), {'transactionid': 'tx-1'}),
    };
    return http.Response(jsonEncode(json), 200, headers: headers);
  });

  List<String> get paths => [for (final r in requests) r.$1];
}

BluelinkClient clientFor(FakeBluelink fake, {BluelinkSession? session}) => BluelinkClient(
  credentials: () => const BluelinkCredentials(user: 'me@example.com', password: 'pw', pin: '1234'),
  session: session ?? BluelinkSession.create(),
  onSession: (_) async {},
  client: fake.client,
  pollEvery: Duration.zero,
);

void main() {
  test('signs in, picks the car and reads the cached status without waking it', () async {
    final fake = FakeBluelink();
    final client = clientFor(fake);
    expect(await client.signIn(), isNull);
    expect(client.session.vehicleId, 'car-1');
    await client.status();
    expect(fake.paths, ['v2/login', 'vhcllst', 'lstvhclsts']);
    final (_, headers, _) = fake.requests.last;
    expect(headers['from'], 'SPA');
    expect(headers['vehicleId'], 'car-1');
    expect(headers['accessToken'], 'access-1');
  });

  test('a new phone confirms with a one-time code', () async {
    final fake = FakeBluelink()..wantOtp = true;
    final client = clientFor(fake);
    final challenge = await client.signIn();
    expect(challenge!.email, 'me@example.com');
    expect(client.session.signedIn, isFalse);
    await client.sendOtp(challenge);
    await client.verifyOtp(challenge, ' 123456 ');
    expect(client.session.signedIn, isTrue);
    final validate = fake.requests.firstWhere((r) => r.$1 == 'mfa/validateotp').$3!;
    expect(validate['otpNo'], '123456');
    expect(validate['otpKey'], 'key');
  });

  test('refreshes an expired token and retries once', () async {
    final fake = FakeBluelink();
    final client = clientFor(fake);
    await client.signIn();
    fake.expiredAnswers = 1;
    final result = await client.status();
    expect(result['doorLock'], false);
    expect(fake.paths.sublist(2), ['lstvhclsts', 'gtothbyrftkn', 'lstvhclsts']);
  });

  test('a command sends the PIN token and waits for the car to confirm', () async {
    final fake = FakeBluelink()..pending = 2;
    final client = clientFor(fake);
    await client.signIn();
    await client.send(const LockCommand());
    expect(fake.paths.sublist(2), ['vrfypin', 'drlck', 'vrfypin', 'rmtsts', 'rmtsts', 'rmtsts']);
    final (_, headers, body) = fake.requests.firstWhere((r) => r.$1 == 'drlck');
    expect(headers['pAuth'], 'pauth');
    expect(body, {'pin': '1234'});
    expect(fake.requests.last.$2['transactionId'], 'tx-1');
  });

  test('climate start carries the coded temperature and seats', () {
    expect(BluelinkClient.tempCode(21), '0EH');
    expect(BluelinkClient.tempCode(14), '00H');
    expect(BluelinkClient.tempFromCode('0EH'), 21);
    expect(BluelinkClient.tempFromCode('OFF'), isNull);
    final settings = BluelinkClient.climateSettings(
      const ClimateRequest(tempC: 22.5, wheel: true, driverSeat: SeatLevel.high),
    );
    expect(settings['airTemp'], {'value': '11H', 'unit': 0, 'hvacTempType': 1});
    expect(settings['heating1'], 4);
    expect((settings['seatHeaterVentCMD'] as Map)['drvSeatOptCmd'], 8);
  });

  test('commands with unverified request shapes are not sent', () async {
    final fake = FakeBluelink();
    final client = clientFor(fake);
    await client.signIn();
    expect(BluelinkClient.supports(const HonkCommand()), isFalse);
    await expectLater(client.send(const HonkCommand()), throwsA(isA<BluelinkException>()));
    expect(fake.paths, ['v2/login', 'vhcllst']);
  });

  test('a Bluelink status reads as the same car Home Assistant would show', () {
    final car = CarState.empty.withEntities(statesFromBluelink(status, limits: (ac: 90, dc: 80)));
    expect(car.lock, DoorLock.unlocked);
    expect(car.soc, 62);
    expect(car.rangeKm, 270);
    expect(car.twelveVoltPct, 81);
    expect(car.trunkOpen, isTrue);
    expect(car.doorsClosed, isTrue);
    expect(car.setTempC, 21);
    expect(car.acLimit, 90);
    expect(car.lastUpdated, DateTime(2026, 11, 12, 9, 30));
    expect(car.tiresOk, isNull); // Bluelink didn't say, so the app doesn't guess
  });

  group('fallback in the app', () {
    Future<(CarStore, FakeBluelink)> offlineStore() async {
      final fake = FakeBluelink();
      final backend = MemorySettingsBackend()
        ..values.addAll({
          'haUrl': 'http://ha.test:8123',
          'token': 't',
          'demo': 'false',
          'commandsEnabled': 'true',
          'bluelinkUser': 'me@example.com',
          'bluelinkPassword': 'pw',
          'bluelinkPin': '1234',
        });
      final store = CarStore(
        Settings(backend),
        clientFactory: (_, _) => throw Exception('Connection refused'),
        bluelinkHttp: fake.client,
      );
      await store.settings.load();
      await store.directSignIn();
      fake.requests.clear();
      return (store, fake);
    }

    test('reads the car from Bluelink once Home Assistant has failed twice', () async {
      final (store, fake) = await offlineStore();
      await store.start();
      expect(store.usingDirect, isFalse); // one failure could be a blip
      expect(fake.requests, isEmpty);
      await Future<void>.delayed(const Duration(seconds: 3)); // the first quiet retry
      await Future<void>.delayed(Duration.zero);
      expect(store.usingDirect, isTrue);
      expect(fake.paths, ['lstvhclsts', 'evc/selsoc']);
      expect(store.car.soc, 62);
      expect(store.health.direct, isTrue);
      expect(store.health.canCommand, isTrue);
      expect(store.showingSaved, isFalse);

      await store.send(const LockCommand());
      expect(fake.paths, contains('drlck'));
      expect(store.car.lock, DoorLock.locked);
      await expectLater(store.send(const FlashCommand()), throwsA(isA<PathDown>()));
      store.dispose();
    });

    test('stays off the Bluelink account while Home Assistant works', () async {
      final fake = FakeBluelink();
      final store = CarStore(Settings(MemorySettingsBackend()), bluelinkHttp: fake.client);
      await store.start();
      expect(store.health.link, Link.demo);
      expect(store.usingDirect, isFalse);
      expect(fake.requests, isEmpty);
    });
  });
}
