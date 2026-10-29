// Renders each screen with the real fonts and images to PNG files in
// test/screenshots/out/. Run: flutter test test/screenshots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/car_store.dart';
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

void main() {
  setUpAll(loadFonts);

  for (final route in ['/', '/controls', '/climate', '/charging', '/stats', '/health', '/activity', '/settings']) {
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
}
