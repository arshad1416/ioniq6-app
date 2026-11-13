import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/main.dart';
import 'package:ioniq6_companion/widgets/rive_view.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(320, 568), const Size(800, 360)]) {
    for (final scale in [1.0, 1.5]) {
      for (final route in ['/', '/controls', '/climate', '/charging', '/stats', '/health', '/activity', '/settings', '/camera', '/emergency', '/valet']) {
        testWidgets('$route at $size text $scale', (tester) async {
          RiveView.enabled = false;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = CarStore(Settings(MemorySettingsBackend()));
          await store.start();
          addTearDown(store.dispose);
          await tester.pumpWidget(CompanionApp(store: store));
          await tester.pumpAndSettle();
          if (route != '/') {
            CompanionApp.navigator.currentState!.pushNamed(route);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
