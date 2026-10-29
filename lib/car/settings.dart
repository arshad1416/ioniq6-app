import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'commands.dart';
import 'units.dart';

/// Where settings live. Swapped for an in-memory version in tests.
abstract class SettingsBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class DeviceSettingsBackend implements SettingsBackend {
  static const _secret = {'token'};
  final _secure = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async =>
      _secret.contains(key) ? _secure.read(key: key) : (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String? value) async {
    if (_secret.contains(key)) {
      value == null ? await _secure.delete(key: key) : await _secure.write(key: key, value: value);
      return;
    }
    final p = await SharedPreferences.getInstance();
    value == null ? await p.remove(key) : await p.setString(key, value);
  }
}

class MemorySettingsBackend implements SettingsBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async => value == null ? values.remove(key) : values[key] = value;
}

class ValetPrefs {
  const ValetPrefs({this.speedLimitKmh = 80, this.pinSet = true, this.hideNavigation = true, this.hidePhone = true});
  final int speedLimitKmh;
  final bool pinSet, hideNavigation, hidePhone;
}

class Settings {
  Settings(this._backend);
  final SettingsBackend _backend;

  String haUrl = '';
  String token = '';
  bool demo = true;

  /// Off until Arshad turns it on: holding a control then only shows a note.
  bool commandsEnabled = false;
  bool liveUpdates = true;
  ClimateRequest climate = const ClimateRequest();

  bool miles = false;
  bool fahrenheit = false;
  String language = 'en';

  /// Off: the Home Assistant token is kept only until the app closes.
  bool keepLoggedIn = true;

  /// Ask for a fingerprint or face when the app opens.
  bool biometricLogin = false;

  /// Ask for a fingerprint or face before a held control acts on the car.
  bool biometricCommands = false;

  /// Valet preferences as shown in the app. Nothing here reaches the car yet.
  ValetPrefs valet = const ValetPrefs();

  Units get units => Units(miles: miles, fahrenheit: fahrenheit);

  bool get isConfigured => haUrl.isNotEmpty && token.isNotEmpty;

  Future<void> load() async {
    haUrl = await _backend.read('haUrl') ?? '';
    token = await _backend.read('token') ?? '';
    demo = (await _backend.read('demo') ?? 'true') == 'true';
    commandsEnabled = await _backend.read('commandsEnabled') == 'true';
    liveUpdates = (await _backend.read('liveUpdates') ?? 'true') == 'true';
    climate = ClimateRequest(tempC: double.tryParse(await _backend.read('climateTemp') ?? '') ?? 21);
    miles = await _backend.read('miles') == 'true';
    fahrenheit = await _backend.read('fahrenheit') == 'true';
    language = await _backend.read('language') ?? 'en';
    keepLoggedIn = (await _backend.read('keepLoggedIn') ?? 'true') == 'true';
    biometricLogin = await _backend.read('biometricLogin') == 'true';
    biometricCommands = await _backend.read('biometricCommands') == 'true';
  }

  Future<void> save() async {
    await _backend.write('haUrl', haUrl);
    await _backend.write('token', token.isEmpty || !keepLoggedIn ? null : token);
    await _backend.write('demo', '$demo');
    await _backend.write('commandsEnabled', '$commandsEnabled');
    await _backend.write('liveUpdates', '$liveUpdates');
    await _backend.write('climateTemp', '${climate.tempC}');
    await _backend.write('miles', '$miles');
    await _backend.write('fahrenheit', '$fahrenheit');
    await _backend.write('language', language);
    await _backend.write('keepLoggedIn', '$keepLoggedIn');
    await _backend.write('biometricLogin', '$biometricLogin');
    await _backend.write('biometricCommands', '$biometricCommands');
  }
}
