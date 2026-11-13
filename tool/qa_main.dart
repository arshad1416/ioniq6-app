// Isolated device QA: in-memory demo data, no saved credentials and no network.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ioniq6_companion/car/car_store.dart';
import 'package:ioniq6_companion/car/settings.dart';
import 'package:ioniq6_companion/main.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Network disabled in isolated device QA');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _NoNetwork();
  final store = CarStore(Settings(MemorySettingsBackend()));
  await store.start();
  runApp(CompanionApp(store: store));
}
