import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'car/car_store.dart';
import 'car/settings.dart';
import 'platform/bridge.dart';
import 'screens/charging.dart';
import 'screens/climate.dart';
import 'screens/controls.dart';
import 'screens/home.dart';
import 'screens/info_screens.dart';
import 'screens/settings.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Palette.glass,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  final store = CarStore(Settings(DeviceSettingsBackend()))..start();
  PlatformBridge(store).attach();
  runApp(CompanionApp(store: store));
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, required this.store});
  final CarStore store;

  @override
  Widget build(BuildContext context) => AppScope(
    store: store,
    child: MaterialApp(
      title: 'IONIQ 6',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routes: {
        '/': (_) => const HomeScreen(),
        '/controls': (_) => const ControlsScreen(),
        '/climate': (_) => const ClimateScreen(),
        '/charging': (_) => const ChargingScreen(),
        '/stats': (_) => const StatsScreen(),
        '/health': (_) => const HealthScreen(),
        '/activity': (_) => const ActivityScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    ),
  );
}
