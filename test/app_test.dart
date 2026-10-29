import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/main.dart';
import 'package:ioniq6_companion/screens/home.dart';
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

  testWidgets('dragging turns the car, then it settles back', (tester) async {
    await pumpApp(tester);
    String shown() =>
        (tester.widget<Image>(find.descendant(of: find.byType(Turntable), matching: find.byType(Image))).image
                as AssetImage)
            .assetName;
    expect(shown(), Turntable.frame(Turntable.rest));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Turntable)));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(shown(), isNot(Turntable.frame(Turntable.rest)));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(shown(), Turntable.frame(Turntable.rest));
  });

  testWidgets('every screen opens from home', (tester) async {
    await pumpApp(tester);
    for (final (row, title) in [('Stats', 'Stats'), ('Health', 'Health'), ('Activity', 'Activity')]) {
      await tester.tap(find.text(row).last);
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      await tester.tap(find.text('‹ IONIQ 6'));
      await tester.pumpAndSettle();
    }
  });

  for (final route in ['/controls', '/climate', '/charging', '/settings', '/camera']) {
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
