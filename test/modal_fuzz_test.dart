import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ioniq6_companion/bluelink/bluelink_client.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/charge_schedule.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/screens/bluelink_setup.dart';
import 'package:ioniq6_companion/screens/charge_schedule_sheet.dart';
import 'package:ioniq6_companion/theme.dart';
import 'package:ioniq6_companion/widgets/common.dart';

const schedule = ChargeSchedule(
  mode: OffPeakMode.prefer,
  start: 1380,
  end: 420,
  scheduledCharging: true,
  departures: [
    Departure(enabled: true, days: [1, 3, 5], minutes: 450, climateOn: true, defrost: false, tempC: 22),
  ],
);

class SignInStore extends CarStore {
  SignInStore({List<http.Request>? requests})
    : super(
        Settings(MemorySettingsBackend()),
        bluelinkHttp: MockClient((request) async {
          requests?.add(request);
          // Only the OTP send path is permitted, always an in-memory response.
          expect(request.url.path, endsWith('/mfa/sendotp'));
          return http.Response(
            jsonEncode({
              'result': {'otpKey': 'test-key'},
            }),
            200,
          );
        }),
      );
  Completer<OtpChallenge?>? waiting;
  int signIns = 0, verifications = 0;
  @override
  Future<OtpChallenge?> directSignIn() async {
    signIns++;
    return waiting?.future ?? OtpChallenge(userInfoUuid: 'test-user', email: 'long-test-address@example.invalid');
  }

  @override
  Future<void> directVerify(OtpChallenge challenge, String code) async => verifications++;
}

void viewport(WidgetTester tester, Size size, double scale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> showLogin(WidgetTester tester, SignInStore store) async {
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: ListView(children: const [BluelinkSetup()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (final (index, value) in [(0, 'test@example.invalid'), (1, 'fake-password'), (2, '0000')]) {
    final field = find.byType(TextField).at(index);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }
  tester.testTextInput.hide();
  final signIn = find.widgetWithText(FilledButton, 'Sign in');
  await tester.ensureVisible(signIn);
  await tester.tap(signIn);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(320, 568), const Size(800, 360)]) {
    for (final scale in [1.0, 1.5]) {
      for (final editable in [false, true]) {
        testWidgets('schedule $size scale $scale editable $editable opens and cancels', (tester) async {
          viewport(tester, size, scale);
          final store = CarStore(Settings(MemorySettingsBackend())..commandsEnabled = editable);
          addTearDown(store.dispose);
          await tester.pumpWidget(
            AppScope(
              store: store,
              child: MaterialApp(
                theme: buildTheme(),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const ChargeScheduleSheet(schedule: schedule),
                      ),
                      child: const Text('Open schedule'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open schedule'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (editable) {
            final start = find.text('Off-peak starts');
            await tester.ensureVisible(start);
            await tester.tap(start);
            await tester.pumpAndSettle();
            expect(find.byType(TimePickerDialog), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            expect(find.text('23:00'), findsOneWidget);
          }
          final ctx = tester.element(find.byType(ChargeScheduleSheet));
          Navigator.of(ctx).pop();
          await tester.pumpAndSettle();
          expect(find.byType(ChargeScheduleSheet), findsNothing);
          expect(store.pending, isNull);
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets('Bluelink OTP $size scale $scale cancels without verification', (tester) async {
        viewport(tester, size, scale);
        final store = SignInStore();
        addTearDown(store.dispose);
        await showLogin(tester, store);
        expect(find.text('Enter the code'), findsOneWidget);
        // The keyboard must not make the dialog content overflow.
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(store.verifications, 0);
        expect(store.signIns, 1);
        expect(find.text('Sign-in not finished: no code entered.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('leaving Bluelink setup while sign-in is pending does not open a dialog', (tester) async {
    final requests = <http.Request>[];
    final store = SignInStore(requests: requests)..waiting = Completer<OtpChallenge?>();
    addTearDown(store.dispose);
    await showLogin(tester, store);
    await tester.pumpWidget(const MaterialApp(home: Text('Elsewhere')));
    store.waiting!.complete(OtpChallenge(userInfoUuid: 'test-user', email: 'test@example.invalid'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code'), findsNothing);
    expect(requests, isEmpty, reason: 'Leaving setup must not send a new OTP email');
    expect(store.verifications, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('removing schedule while time picker is open does not update disposed sheet', (tester) async {
    final store = CarStore(Settings(MemorySettingsBackend())..commandsEnabled = true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const ChargeScheduleSheet(schedule: schedule),
                ),
                child: const Text('Open schedule'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open schedule'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ChargeScheduleSheet));
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    await tester.tap(find.text('Off-peak starts'));
    await tester.pumpAndSettle();
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ChargeScheduleSheet), findsNothing);
    expect(store.pending, isNull);
  });
}
