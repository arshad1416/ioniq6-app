import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ha/entities.dart';
import '../ha/ha_client.dart';
import 'car_state.dart';
import 'commands.dart';
import 'demo_data.dart';
import 'settings.dart';

enum Connection { none, connecting, live, error, demo }

class ActivityItem {
  ActivityItem(this.time, this.title, [this.detail = '']);
  final DateTime time;
  final String title, detail;
}

class CommandsDisabled implements Exception {
  @override
  String toString() => 'Car commands are off. Turn them on in Settings.';
}

/// App state: the car as Home Assistant reports it, the connection, and any
/// command in flight. Screens listen to this and never call HA directly.
class CarStore extends ChangeNotifier {
  CarStore(this.settings, {HaClient Function(Uri, String)? clientFactory})
    : _clientFactory = clientFactory ?? ((url, token) => HaClient(baseUrl: url, token: token));

  final Settings settings;
  final HaClient Function(Uri, String) _clientFactory;

  CarState car = CarState.empty;
  Connection connection = Connection.none;
  String? error;
  CarCommand? pending;
  DoorLock? lockOverride;
  final List<ActivityItem> _localLog = [];
  List<ActivityItem> _history = [];

  HaClient? _client;
  StreamSubscription<EntityState>? _sub;
  Timer? _retry, _pendingTimeout;

  bool get isDemo => connection == Connection.demo;
  DoorLock get lockState => lockOverride ?? car.lock;

  List<ActivityItem> get activity => [..._localLog, ..._history]..sort((a, b) => b.time.compareTo(a.time));

  Future<void> start() async {
    await settings.load();
    if (settings.demo || !settings.isConfigured) {
      _startDemo();
    } else {
      await connect();
    }
  }

  void _startDemo() {
    _sub?.cancel();
    _client?.close();
    _client = null;
    car = CarState(demoStates());
    connection = Connection.demo;
    error = null;
    _history = [
      ActivityItem(DateTime.now().subtract(const Duration(minutes: 38)), 'Car status updated', 'Locked · 74% · 328 km'),
      ActivityItem(
        DateTime.now().subtract(const Duration(hours: 3)),
        'Walk-away lock, test only',
        'You walked away; it would have locked',
      ),
    ];
    notifyListeners();
  }

  Future<void> connect() async {
    _retry?.cancel();
    await _sub?.cancel();
    await _client?.close();
    connection = Connection.connecting;
    error = null;
    notifyListeners();
    try {
      final client = _clientFactory(Uri.parse(settings.haUrl), settings.token);
      _client = client;
      var states = {for (final s in await client.states(E.all)) s.entityId: s};
      car = CarState(states);
      _sub = client.subscribe(E.all).listen((s) {
        car = car.withEntity(s);
        _settlePending();
        notifyListeners();
      }, onError: (Object e) => _fail(e));
      connection = Connection.live;
      notifyListeners();
      unawaited(loadHistory());
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    connection = Connection.error;
    error = '$e';
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 20), connect);
  }

  Future<void> loadHistory() async {
    final client = _client;
    if (client == null) return;
    try {
      final changes = await client.history(E.activity, DateTime.now().subtract(const Duration(hours: 48)));
      final last = <String, String>{};
      final out = <ActivityItem>[];
      for (final c in changes) {
        final before = last[c.entityId];
        last[c.entityId] = c.state;
        if (before == null || before == c.state) continue;
        final title = _describe(c.entityId, c.state);
        if (title != null) out.add(ActivityItem(c.lastChanged, title));
      }
      _history = out;
      notifyListeners();
    } catch (_) {
      // Activity is a nice-to-have; the rest of the app keeps working.
    }
  }

  static String? _describe(String id, String state) => switch ((id, state)) {
    (E.lock, 'locked') => 'Locked',
    (E.lock, 'unlocked') => 'Unlocked',
    (E.charging, 'on') => 'Charging started',
    (E.charging, 'off') => 'Charging stopped',
    (E.plugged, 'on') => 'Plugged in',
    (E.plugged, 'off') => 'Unplugged',
    (E.climateSwitch, 'on') => 'Climate on',
    (E.climateSwitch, 'off') => 'Climate off',
    (E.phoneConnected, 'on') => 'Phone connected to the car',
    (E.phoneConnected, 'off') => 'Phone left the car',
    (E.engine, 'on') => 'Car switched on',
    (E.engine, 'off') => 'Car switched off',
    (E.trunk, 'on') => 'Trunk opened',
    (E.trunk, 'off') => 'Trunk closed',
    _ => null,
  };

  Future<List<Map<String, dynamic>>> monthlyOdometer() async {
    final client = _client;
    if (client == null) return const [];
    final now = DateTime.now();
    return client.statistics(E.odometer, DateTime(now.year, now.month - 5));
  }

  /// Sends [cmd] to the car. Callers reach this only from a press-and-hold.
  Future<void> send(CarCommand cmd) async {
    if (!settings.commandsEnabled && !isDemo) throw CommandsDisabled();
    pending = cmd;
    lockOverride = switch (cmd) {
      LockCommand() => DoorLock.locking,
      UnlockCommand() => DoorLock.unlocking,
      _ => null,
    };
    notifyListeners();
    try {
      if (isDemo) {
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        _applyDemo(cmd);
      } else {
        await _client!.callService(cmd.domain, cmd.service, cmd.data);
        // The integration refreshes after a command; wait for HA to show it.
        _pendingTimeout?.cancel();
        _pendingTimeout = Timer(const Duration(seconds: 90), () => _clearPending());
        _settlePending();
      }
      _localLog.add(ActivityItem(DateTime.now(), cmd.label, isDemo ? 'Demo, nothing was sent' : 'From this phone'));
    } catch (e) {
      _localLog.add(ActivityItem(DateTime.now(), '${cmd.label} failed', '$e'));
      if (cmd is LockCommand || cmd is UnlockCommand) {
        lockOverride = DoorLock.error;
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      _clearPending();
      rethrow;
    }
  }

  void _settlePending() {
    final done = switch (pending) {
      LockCommand() => car.lock == DoorLock.locked,
      UnlockCommand() => car.lock == DoorLock.unlocked,
      StartClimateCommand() => car.climateOn,
      StopClimateCommand() => !car.climateOn,
      StartChargeCommand() => car.charging,
      StopChargeCommand() => !car.charging,
      SetChargeLimitsCommand(:final ac) => car.acLimit == ac,
      null => false,
      _ => true,
    };
    if (done) _clearPending();
  }

  void _clearPending() {
    _pendingTimeout?.cancel();
    pending = null;
    lockOverride = null;
    notifyListeners();
  }

  void _applyDemo(CarCommand cmd) {
    final now = DateTime.now();
    void set(String id, String state) {
      final prev = demoStates()[id]!;
      car = car.withEntity(prev.copyWith(state: state, lastChanged: now));
    }

    switch (cmd) {
      case LockCommand():
        set(E.lock, 'locked');
      case UnlockCommand():
        set(E.lock, 'unlocked');
      case StartClimateCommand(:final request):
        set(E.climateSwitch, 'on');
        set(E.setTemp, request.tempC.toStringAsFixed(1));
        set(E.defrost, request.defrost ? 'on' : 'off');
        set(E.wheelHeat, request.wheel ? 'on' : 'off');
      case StopClimateCommand():
        set(E.climateSwitch, 'off');
      case StartChargeCommand():
        set(E.plugged, 'on');
        set(E.charging, 'on');
        set(E.chargePower, '7.2');
        set(E.chargeMinutes, '90');
      case StopChargeCommand():
        set(E.charging, 'off');
        set(E.chargePower, 'unknown');
      case SetChargeLimitsCommand(:final ac, :final dc):
        set(E.acLimit, '$ac');
        set(E.dcLimit, '$dc');
      case OpenChargePortCommand() || FlashCommand() || HonkCommand():
        break;
    }
    _clearPending();
  }

  /// Climate settings are local until the power button is held.
  void updateClimate(ClimateRequest request) {
    settings.climate = request;
    notifyListeners();
    unawaited(settings.save());
  }

  /// Redraws screens after a display setting such as units changes.
  void refreshViews() => notifyListeners();

  Future<void> refresh() async {
    if (isDemo) return;
    await connect();
  }

  /// Saves new settings and reconnects (or switches to demo).
  Future<void> applySettings() async {
    await settings.save();
    if (settings.demo || !settings.isConfigured) {
      _startDemo();
    } else {
      await connect();
    }
  }

  /// Tests a URL and token without changing the live connection.
  Future<void> testConnection(String url, String token) => _clientFactory(Uri.parse(url), token).ping();

  @override
  void dispose() {
    _retry?.cancel();
    _pendingTimeout?.cancel();
    _sub?.cancel();
    _client?.close();
    super.dispose();
  }
}
