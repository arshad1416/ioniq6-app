import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/main.dart';
import 'package:ioniq6_companion/widgets/rive_view.dart';

Future<CarStore> pumpApp(WidgetTester tester) async {
  RiveView.enabled = false;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = CarStore(Settings(MemorySettingsBackend()));
  await store.start();
  await tester.pumpWidget(CompanionApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('home shows the car in demo mode', (tester) async {
    await pumpApp(tester);
    expect(find.text('IONIQ 6'), findsOneWidget);
    expect(find.text('328'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);
  });

  testWidgets('home shows the photo of the car', (tester) async {
    await pumpApp(tester);
    final assets = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName);
    expect(assets, contains('assets/images/hero.webp'));
  });

  testWidgets('miles and Fahrenheit change what Home shows', (tester) async {
    final store = await pumpApp(tester);
    expect(find.text('328'), findsOneWidget);
    store.settings
      ..miles = true
      ..fahrenheit = true;
    store.refreshViews();
    await tester.pumpAndSettle();
    expect(find.text('204'), findsOneWidget);
    expect(find.text(' mi'), findsOneWidget);
    expect(find.textContaining('70°'), findsOneWidget);
  });

  testWidgets('every screen opens from home', (tester) async {
    await pumpApp(tester);
    for (final (row, title) in [('Stats', 'Stats'), ('Health', 'Health'), ('Activity', 'Activity')]) {
      await tester.ensureVisible(find.text(row).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(row).last);
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      await tester.tap(find.text('‹ IONIQ 6'));
      await tester.pumpAndSettle();
    }
  });

  for (final route in ['/controls', '/climate', '/charging', '/settings', '/camera', '/emergency', '/valet']) {
    testWidgets('$route lays out without errors', (tester) async {
      await pumpApp(tester);
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a tap does not lock; a hold does', (tester) async {
    final store = await pumpApp(tester);
    final lockButton = find.text('Locked').first;

    await tester.tap(lockButton);
    await tester.pumpAndSettle();
    expect(store.pending, isNull);

    final gesture = await tester.startGesture(tester.getCenter(lockButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await gesture.up();
    expect(store.pending, isNotNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Unlocked'), findsWidgets);
  });
}
