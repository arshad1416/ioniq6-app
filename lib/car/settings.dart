import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'commands.dart';

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

  bool get isConfigured => haUrl.isNotEmpty && token.isNotEmpty;

  Future<void> load() async {
    haUrl = await _backend.read('haUrl') ?? '';
    token = await _backend.read('token') ?? '';
    demo = (await _backend.read('demo') ?? 'true') == 'true';
    commandsEnabled = await _backend.read('commandsEnabled') == 'true';
    liveUpdates = (await _backend.read('liveUpdates') ?? 'true') == 'true';
    climate = ClimateRequest(tempC: double.tryParse(await _backend.read('climateTemp') ?? '') ?? 21);
  }

  Future<void> save() async {
    await _backend.write('haUrl', haUrl);
    await _backend.write('token', token.isEmpty ? null : token);
    await _backend.write('demo', '$demo');
    await _backend.write('commandsEnabled', '$commandsEnabled');
    await _backend.write('liveUpdates', '$liveUpdates');
    await _backend.write('climateTemp', '${climate.tempC}');
  }
}
