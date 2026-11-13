// Isolated device QA: in-memory demo data, no saved credentials and no network.
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/main.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = ((_, _, _) =>
            Future.error(StateError('Network disabled in isolated device QA')));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _NoNetwork();
  final store = CarStore(Settings(MemorySettingsBackend()));
  await store.start();
  var errors = 0;
  final originalError = FlutterError.onError;
  FlutterError.onError = (details) { errors++; originalError?.call(details); };
  runApp(CompanionApp(store: store));
  if (const bool.fromEnvironment('QA_FUZZ')) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final random = Random(6013);
    const routes = ['/controls', '/climate', '/charging', '/stats', '/health', '/activity', '/settings', '/camera', '/emergency', '/valet', '/trip'];
    var cycles = 0;
    for (var pass = 0; pass < 3; pass++) {
      final order = routes.toList()..shuffle(random);
      for (final route in order) {
        CompanionApp.navigator.currentState!.pushNamed(route);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        CompanionApp.navigator.currentState!.pop();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        cycles++;
        debugPrint('QA_ROUTE $cycles $route errors=$errors');
      }
    }
    debugPrint('QA_COMPLETE cycles=$cycles errors=$errors demo=${store.isDemo}');
  }
}
