import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'car/car_store.dart';
import 'car/settings.dart';
import 'platform/bridge.dart';
import 'screens/camera.dart';
import 'screens/charging.dart';
import 'screens/climate.dart';
import 'screens/controls.dart';
import 'screens/home.dart';
import 'screens/info_screens.dart';
import 'screens/settings.dart';
import 'motion.dart';
import 'theme.dart';
import 'update/update_prompt.dart';
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
  // Look for a new release on GitHub once the app has settled.
  Future.delayed(const Duration(seconds: 3), () {
    final context = CompanionApp.navigator.currentState?.overlay?.context;
    if (context != null && context.mounted) checkForUpdate(context);
  });
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, required this.store});
  final CarStore store;
  static final navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => AppScope(
    store: store,
    child: MaterialApp(
      title: 'IONIQ 6',
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      onGenerateRoute: (settings) {
        final page = _pages[settings.name];
        return page == null ? null : FadeRiseRoute(builder: page, settings: settings);
      },
    ),
  );

  static final Map<String, WidgetBuilder> _pages = {
    '/': (_) => const HomeScreen(),
    '/controls': (_) => const ControlsScreen(),
    '/climate': (_) => const ClimateScreen(),
    '/charging': (_) => const ChargingScreen(),
    '/stats': (_) => const StatsScreen(),
    '/health': (_) => const HealthScreen(),
    '/activity': (_) => const ActivityScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/camera': (_) => const CameraScreen(),
  };
}
