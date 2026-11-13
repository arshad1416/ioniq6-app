// Renders each screen with the real fonts and images to PNG files in
// test/screenshots/out/. Run: flutter test test/screenshots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_state.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/demo_data.dart';
import 'package:ioniq6_companion/ha/entities.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/main.dart';
import 'package:ioniq6_companion/widgets/rive_view.dart';

Future<void> loadFonts() async {
  for (final (family, file) in [
    ('Outfit', 'Outfit'),
    ('InstrumentSans', 'InstrumentSans'),
    ('JetBrainsMono', 'JetBrainsMono'),
  ]) {
    final loader = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$file.ttf'));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File(_materialIcons()).readAsBytesSync())));
  await icons.load();
}

String _materialIcons() {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/root/sdk/flutter';
  return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
}

/// Example events so the Next trip row and screen show something.
void mockCalendar() {
  final today = DateTime.now();
  int at(int day, int hour, [int minute = 0]) =>
      DateTime(today.year, today.month, today.day + day, hour, minute).millisecondsSinceEpoch;
  final events = [
    {
      'begin': at(1, 8, 30),
      'end': at(1, 9, 30),
      'title': 'Office',
      'location': '100 Queen St W, Toronto',
      'calendar': 'Work',
    },
    {'begin': at(1, 12), 'end': at(1, 13), 'title': 'Team lunch', 'location': null, 'calendar': 'Work'},
    {
      'begin': at(2, 17, 15),
      'end': at(2, 18),
      'title': 'Swimming',
      'location': 'Pan Am Sports Centre',
      'calendar': 'Family',
    },
  ];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('ioniq6/calendar'),
    (call) async => call.method == 'events' ? events : true,
  );
}

void main() {
  setUpAll(loadFonts);
  setUp(mockCalendar);

  for (final route in [
    '/',
    '/controls',
    '/climate',
    '/charging',
    '/stats',
    '/health',
    '/activity',
    '/settings',
    '/camera',
    '/emergency',
    '/valet',
    '/trip',
  ]) {
    testWidgets('screenshot $route', (tester) async {
      RiveView.enabled = false;
      tester.view.physicalSize = const Size(1236, 2745); // OnePlus 13 at 3x
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = CarStore(Settings(MemorySettingsBackend()));
      await store.start();
      await tester.pumpWidget(CompanionApp(store: store));
      if (route != '/') tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final img in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(img.image, tester.element(find.byType(Navigator)));
        }
      });
      await tester.pumpAndSettle();
      final name = route == '/' ? 'home' : route.substring(1);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    });
  }

  // Animations repeat while charging, so pump a fixed time instead of settling.
  testWidgets('screenshot /charging while charging', (tester) async {
    RiveView.enabled = false;
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = CarStore(Settings(MemorySettingsBackend()));
    await store.start();
    final states = demoStates();
    for (final (id, v) in [(E.plugged, 'on'), (E.charging, 'on'), (E.chargePower, '7.2'), (E.chargeMinutes, '95')]) {
      states[id] = states[id]!.copyWith(state: v);
    }
    store.car = CarState(states);
    await tester.pumpWidget(CompanionApp(store: store));
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/charging');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() async {
      for (final img in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(img.image, tester.element(find.byType(Navigator)));
      }
    });
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/charging_live.png'));
  });

  testWidgets('screenshot the charge schedule sheet', (tester) async {
    RiveView.enabled = false;
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = CarStore(Settings(MemorySettingsBackend()));
    await store.start();
    await tester.pumpWidget(CompanionApp(store: store));
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off-peak charging'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/charge_schedule.png'));
  });
}
