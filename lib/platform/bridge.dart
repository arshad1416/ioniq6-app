import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../car/car_state.dart';
import '../car/car_store.dart';

/// Pushes car state to the Android side: the home-screen widget and
/// Android 16 Live Updates (promoted ongoing notifications).
class PlatformBridge {
  PlatformBridge(this.store);
  final CarStore store;

  static const _live = MethodChannel('ioniq6/live_updates');
  String? _lastWidget, _lastCharging, _lastClimate;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void attach() {
    if (!_android) return;
    store.addListener(_sync);
  }

  Future<void> _sync() async {
    final car = store.car;
    if (!car.hasData) return;
    try {
      await _syncWidget(car, store.lockState);
      await _syncLiveUpdates(car);
    } on PlatformException catch (e) {
      debugPrint('Platform bridge: $e');
    }
  }

  Future<void> _syncWidget(CarState car, DoorLock lock) async {
    final lockText = lock == DoorLock.locked ? 'Locked' : (lock == DoorLock.unlocked ? 'Unlocked' : '…');
    final units = store.settings.units;
    final key = '${car.rangeKm}|${car.soc}|$lockText|${car.charging}|${units.miles}';
    if (key == _lastWidget) return;
    _lastWidget = key;
    await HomeWidget.saveWidgetData('range', '${units.dist(car.rangeKm) ?? '–'} ${units.distance}');
    await HomeWidget.saveWidgetData('soc', car.soc ?? 0);
    await HomeWidget.saveWidgetData('status', '${car.soc ?? '–'}% · $lockText${car.charging ? ' · Charging' : ''}');
    await HomeWidget.updateWidget(qualifiedAndroidName: 'ca.arshad.ioniq6_companion.CarWidgetProvider');
  }

  Future<void> _syncLiveUpdates(CarState car) async {
    final enabled = store.settings.liveUpdates;

    final charging = enabled && car.charging
        ? {
            'soc': car.soc ?? 0,
            'limit': car.acLimit,
            'minutesLeft': car.chargeMinutesLeft ?? 0,
            'kw': car.chargeKw ?? 0,
          }
        : null;
    final chargingKey = '$charging';
    if (chargingKey != _lastCharging) {
      _lastCharging = chargingKey;
      await (charging == null
          ? _live.invokeMethod('end', {'kind': 'charging'})
          : _live.invokeMethod('charging', charging));
    }

    final climate = enabled && car.climateOn
        ? {'target': store.settings.climate.tempC, 'cabin': car.cabinTempC, 'minutes': store.settings.climate.minutes}
        : null;
    final climateKey = '$climate';
    if (climateKey != _lastClimate) {
      _lastClimate = climateKey;
      await (climate == null ? _live.invokeMethod('end', {'kind': 'climate'}) : _live.invokeMethod('climate', climate));
    }
  }
}
