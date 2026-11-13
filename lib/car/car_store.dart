import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../bluelink/bluelink_client.dart';
import '../bluelink/bluelink_states.dart';

import '../ha/entities.dart';
import '../ha/entity_map.dart';
import '../ha/ha_client.dart';
import 'camera_cache.dart';
import 'car_state.dart';
import 'outside_weather.dart';
import 'commands.dart';
import 'charge_schedule.dart';
import 'demo_data.dart';
import 'health.dart';
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

/// The path to the car is known to be broken, so nothing was sent.
class PathDown implements Exception {
  PathDown(this.reason);
  final String reason;
  @override
  String toString() => '$reason. Nothing was sent.';
}

/// App state: the car as Home Assistant reports it, the connection, and any
/// command in flight. Screens listen to this and never call HA directly.
class CarStore extends ChangeNotifier {
  CarStore(
    this.settings, {
    HaClient Function(Uri, String)? clientFactory,
    OutsideWeather? weather,
    CameraCache? cameras,
    http.Client? bluelinkHttp,
  }) : _clientFactory = clientFactory ?? ((url, token) => HaClient(baseUrl: url, token: token)),
       weather = weather ?? OutsideWeather(),
       cameras = cameras ?? CameraCache() {
    bluelink = BluelinkClient(
      credentials: () => settings.bluelinkCredentials,
      session: BluelinkSession.create(),
      onSession: (session) {
        settings.bluelinkSession = jsonEncode(session.toJson());
        return settings.saveBluelink();
      },
      client: bluelinkHttp,
    );
  }

  final Settings settings;
  final OutsideWeather weather;
  final CameraCache cameras;

  /// The fallback path: straight to Bluelink when Home Assistant can't reach the car.
  late final BluelinkClient bluelink;
  final HaClient Function(Uri, String) _clientFactory;

  CarState car = CarState.empty;
  Connection connection = Connection.none;
  String? error;
  CarCommand? pending;
  DoorLock? lockOverride;
  final List<ActivityItem> _localLog = [];
  List<ActivityItem> _history = [];

  HaClient? _client;
  StreamSubscription<List<EntityState>>? _sub;
  Timer? _retry, _pendingTimeout, _saveTimer;
  int _failures = 0;
  Object? _lastError;
  EntityMap _map = const EntityMap();
  String? _activeUrl;

  /// Entities Home Assistant has but whose integration isn't providing them.
  /// Their last good values stay in [car].
  final _down = <String>{};

  /// When Home Assistant last gave us the car's own data.
  DateTime? dataAt;

  /// When the 360 shots saved on the phone were taken.
  DateTime? _savedShotsAt;

  /// Home Assistant has failed more than once in a row.
  bool _haDown = false;

  /// The last read straight from Bluelink worked, and when it was.
  bool _directOk = false;
  DateTime? _directAt;
  bool _directBusy = false;

  /// Why the last direct read failed, if it did.
  String? directError;

  /// Direct reads are spaced at least this far apart unless the user asks.
  static const _directEvery = Duration(minutes: 2);

  /// Quick, silent retries before the error banner shows. Right after the
  /// phone wakes or switches networks, DNS often fails for a few seconds.
  static const _quietRetries = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8)];

  /// After those, the wait between tries grows to this.
  static const _slowestRetry = Duration(seconds: 60);

  /// How long the home-network address gets before the remote one is tried.
  static const _localWait = Duration(seconds: 4);
  static const _remoteWait = Duration(seconds: 20);

  /// A parked car reports rarely; past this the app says so.
  static const staleAfter = Duration(hours: 6);

  static const _snapshotKey = 'carSnapshot';

  bool get isDemo => connection == Connection.demo;
  DoorLock get lockState => lockOverride ?? car.lock;

  /// Which link to the car is broken, if any.
  Health get health {
    final link = _haLink;
    final broken = !const {Link.ok, Link.demo, Link.stale}.contains(link);
    return Health(
      link,
      detail: directError ?? error,
      extrasMissing: connection == Connection.live && !_map.extrasFound,
      direct: broken && usingDirect && _directOk,
    );
  }

  /// The Bluelink fallback is signed in on this phone.
  bool get directReady => bluelink.session.signedIn && settings.bluelinkCredentials != null;

  /// Home Assistant's path to the car is broken and the fallback is standing in.
  bool get usingDirect {
    if (isDemo || !directReady) return false;
    return _haDown || const {Link.tokenRejected, Link.integrationMissing, Link.carUnavailable}.contains(_haLink);
  }

  /// The state of the Home Assistant path alone.
  Link get _haLink {
    switch (connection) {
      case Connection.demo:
        return Link.demo;
      case Connection.none || Connection.connecting:
        return Link.connecting;
      case Connection.error:
        if (_lastError is HaAuthException) return Link.tokenRejected;
        final text = '$_lastError';
        final offline = text.contains('Failed host lookup') || text.contains('Network is unreachable');
        return offline ? Link.noNetwork : Link.haUnreachable;
      case Connection.live:
        if (!_map.integrationFound || !car.hasCar) return Link.integrationMissing;
        if (_down.contains(E.soc) && _down.contains(E.lock)) return Link.carUnavailable;
        final reported = car.lastUpdated;
        if (reported != null && DateTime.now().difference(reported) > staleAfter) return Link.stale;
        return Link.ok;
    }
  }

  /// Whether the screens show saved data, not what the car says right now.
  bool get showingSaved => !isDemo && car.hasData && !health.canCommand;

  List<ActivityItem> get activity => [..._localLog, ..._history]..sort((a, b) => b.time.compareTo(a.time));

  Future<void> start() async {
    await settings.load();
    if (settings.demo || !settings.isConfigured) {
      _startDemo();
    } else {
      if (settings.bluelinkSession != null) {
        bluelink.session = BluelinkSession.fromJson(jsonDecode(settings.bluelinkSession!) as Map<String, dynamic>);
      }
      await cameras.init();
      await _loadSnapshot();
      await connect();
    }
  }

  void _startDemo() {
    _retry?.cancel();
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

  /// Shows what the car last reported until Home Assistant answers.
  Future<void> _loadSnapshot() async {
    try {
      final raw = await settings.readCache(_snapshotKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      car = CarState({
        for (final e in (j['states'] as List).cast<Map<String, dynamic>>().map(EntityState.fromJson)) e.entityId: e,
      });
      dataAt = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
      _savedShotsAt = car.cameraTakenAt;
      _map = EntityMap(uniqueIds: Map<String, String>.from(j['uniqueIds'] as Map? ?? const {}));
      notifyListeners();
    } catch (_) {
      // A snapshot from an older version, or a damaged one: start empty.
    }
  }

  void _saveSnapshotSoon() {
    _saveTimer ??= Timer(const Duration(seconds: 3), () {
      _saveTimer = null;
      unawaited(
        settings.writeCache(
          _snapshotKey,
          jsonEncode({
            'at': (dataAt ?? DateTime.now()).millisecondsSinceEpoch,
            'uniqueIds': _map.uniqueIds,
            'states': [for (final e in car.entities) e.toJson()],
          }),
        ),
      );
    });
  }

  Future<void> connect() async {
    _retry?.cancel();
    await _sub?.cancel();
    await _client?.close();
    connection = Connection.connecting;
    notifyListeners();
    final urls = [if (settings.haLocalUrl.isNotEmpty) settings.haLocalUrl, settings.haUrl];
    for (final (i, url) in urls.indexed) {
      final last = i == urls.length - 1;
      try {
        await _open(url, last ? _remoteWait : _localWait);
        return;
      } catch (e) {
        await _sub?.cancel();
        await _client?.close();
        if (last || e is HaAuthException) return _fail(e);
      }
    }
  }

  Future<void> _open(String url, Duration wait) async {
    final client = _clientFactory(Uri.parse(url), settings.token);
    _client = client;
    _map = await _resolve(client).timeout(wait);
    final first = Completer<void>();
    _sub = client.subscribe(_map.subscribed).listen((batch) {
      _merge(batch);
      if (!first.isCompleted) first.complete();
    }, onError: (Object e) => first.isCompleted ? _fail(e) : first.completeError(e));
    await first.future.timeout(wait);
    _activeUrl = url;
    connection = Connection.live;
    error = null;
    _lastError = null;
    _failures = 0;
    _haDown = false;
    notifyListeners();
    unawaited(loadHistory());
    _directIfNeeded();
  }

  /// Finds the car's device and entities in this Home Assistant. A token
  /// without access to the registry falls back to the ids in [E].
  Future<EntityMap> _resolve(HaClient client) async {
    try {
      return EntityMap.resolve(await client.entityRegistry(), remembered: _map.uniqueIds);
    } on HaAuthException {
      rethrow;
    } on HaException {
      return EntityMap(uniqueIds: _map.uniqueIds);
    }
  }

  void _merge(List<EntityState> batch) {
    final good = <EntityState>[];
    for (final actual in batch) {
      final e = actual.copyWith(entityId: _map.canonical(actual.entityId));
      if (e.state == 'unavailable') {
        _down.add(e.entityId);
        // Keep the last good value on screen; [health] says it's old.
        if (!car.entities.any((known) => known.entityId == e.entityId)) good.add(e);
      } else {
        _down.remove(e.entityId);
        good.add(e);
      }
    }
    car = car.withEntities(good);
    if (!(_down.contains(E.soc) && _down.contains(E.lock))) dataAt = DateTime.now();
    _saveSnapshotSoon();
    _saveShots();
    _settlePending();
    notifyListeners();
    _directIfNeeded();
  }

  /// Copies new 360 shots to the phone.
  void _saveShots() {
    final taken = car.cameraTakenAt;
    if (taken == null || taken == _savedShotsAt) return;
    _savedShotsAt = taken;
    final pictures = <String, Uri>{};
    for (final view in E.cameraViews) {
      final path = car.cameraPicture(view);
      final url = path == null ? null : haUri(path);
      if (url != null) pictures[view] = url;
    }
    unawaited(cameras.save(pictures));
  }

  void _fail(Object e) {
    _retry?.cancel();
    _lastError = e;
    if (e is! HaAuthException && _failures < _quietRetries.length) {
      // One failure can be a blip; from the second on, stop waiting for
      // Home Assistant and ask Bluelink.
      _haDown = _failures >= 1;
      _retry = Timer(_quietRetries[_failures++], connect);
      _directIfNeeded();
      return; // still "connecting"; the last known state stays on screen
    }
    _haDown = true;
    connection = Connection.error;
    error = '$e';
    notifyListeners();
    _directIfNeeded();
    if (e is HaAuthException) return; // a new token is the only fix
    final wait = Duration(seconds: 20 * (++_failures - _quietRetries.length));
    _retry = Timer(wait > _slowestRetry ? _slowestRetry : wait, connect);
  }

  void _directIfNeeded() {
    if (!usingDirect || _directBusy) return;
    final last = _directAt;
    if (last != null && DateTime.now().difference(last) < _directEvery) return;
    unawaited(directRefresh());
  }

  /// Reads the car's status straight from Bluelink: the last one it
  /// reported, or with [wake] a fresh one from the car itself.
  Future<void> directRefresh({bool wake = false}) async {
    if (_directBusy) return;
    _directBusy = true;
    _directAt = DateTime.now();
    try {
      final status = await bluelink.status(wake: wake);
      final limits = await bluelink.chargeLimits();
      car = car.withEntities(statesFromBluelink(status, limits: limits));
      dataAt = DateTime.now();
      _directOk = true;
      directError = null;
      _saveSnapshotSoon();
    } catch (e) {
      _directOk = false;
      directError = '$e';
    } finally {
      _directBusy = false;
      notifyListeners();
    }
  }

  /// The app came back to the foreground: the socket may have died while the
  /// phone slept, so check it, or stop waiting and reconnect now.
  Future<void> onResume() async {
    if (isDemo || !settings.isConfigured || _lastError is HaAuthException) return;
    if (connection == Connection.live) {
      try {
        await _client!.ping();
        return;
      } catch (_) {
        // fall through to a fresh connection
      }
    }
    _failures = 0;
    await connect();
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

  bool locating = false;

  /// Asks the car where it is (Bluelink Find My Car, read-only) through the
  /// ioniq6_extras add-on; the answer arrives as [E.parked].
  Future<void> locate() async {
    if (locating) return;
    locating = true;
    notifyListeners();
    try {
      if (isDemo) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      } else if (usingDirect) {
        final at = await bluelink.locate();
        if (at == null) throw BluelinkException('The car didn\'t share its location');
        final now = DateTime.now();
        car = car.withEntity(
          EntityState(E.parked, 'not_home', {
            'latitude': at.$1,
            'longitude': at.$2,
            'located_at': now.toUtc().toIso8601String(),
          }, now),
        );
        _saveSnapshotSoon();
      } else {
        await _call('ioniq6_extras', 'locate', const {});
      }
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  /// Calls a Home Assistant service, refusing early when the path to the car
  /// is known to be broken and putting failures in plain words.
  Future<void> _call(String domain, String service, Map<String, dynamic> data) async {
    final state = health;
    if (!state.canCommand) throw PathDown(state.title ?? 'Still connecting to Home Assistant');
    if (domain == EntityMap.extrasPlatform && !_map.extrasFound) {
      throw PathDown("The Ioniq 6 Extras add-on isn't loaded in Home Assistant");
    }
    try {
      await _client!.callService(domain, service, _map.translate(data));
    } on TimeoutException {
      throw HaException("Home Assistant didn't answer in time, so it's unclear whether the car got it");
    } on HaException catch (e) {
      if (e.message.contains('not found')) {
        throw HaException("Home Assistant doesn't have $domain.$service; its integration isn't loaded");
      }
      rethrow;
    }
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
        _apply(cmd);
      } else if (usingDirect) {
        if (!BluelinkClient.supports(cmd)) throw PathDown('${cmd.label} needs Home Assistant, which is down');
        await bluelink.send(cmd); // returns once the car has confirmed
        _apply(cmd);
      } else {
        await _call(cmd.domain, cmd.service, cmd.data);
        // The integration refreshes after a command; wait for HA to show it.
        _pendingTimeout?.cancel();
        _pendingTimeout = Timer(const Duration(seconds: 90), () => _clearPending());
        _settlePending();
      }
      _localLog.add(
        ActivityItem(
          DateTime.now(),
          cmd.label,
          isDemo
              ? 'Demo, nothing was sent'
              : (usingDirect ? 'From this phone, straight to Bluelink' : 'From this phone'),
        ),
      );
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
      ValetCommand(:final on) => car.valetOn == on,
      PreconditionCommand(:final on) => car.preconditioningOn == on,
      SetOffPeakCommand(:final mode, :final start, :final end) => switch (car.chargeSchedule) {
        final s? => s.mode == mode && (mode == OffPeakMode.off || (s.start == start && s.end == end)),
        null => false,
      },
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

  /// Shows [cmd]'s effect without waiting for a status: in demo mode, and
  /// after Bluelink has confirmed a command sent to it directly.
  void _apply(CarCommand cmd) {
    final now = DateTime.now();
    void set(String id, String state) {
      final prev = car.entities.where((e) => e.entityId == id).firstOrNull;
      car = car.withEntity(prev?.copyWith(state: state, lastChanged: now) ?? EntityState(id, state, const {}, now));
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
      case ValetCommand(:final on):
        set(E.valet, on ? 'on' : 'off');
      case PreconditionCommand(:final on):
        set(E.preconditioning, on ? 'on' : 'off');
      case SetOffPeakCommand(:final mode, :final start, :final end):
        final prev = car.entities.where((e) => e.entityId == E.carData).firstOrNull;
        final data = prev?.attributes['vehicle_data'];
        final status = data is Map ? data['status'] : null;
        final ev = status is Map ? status['evStatus'] : null;
        final info = ev is Map ? ev['reservChargeInfos'] : null;
        if (info is Map) {
          car = car.withEntity(
            EntityState(E.carData, prev!.state, {
              ...prev.attributes,
              'vehicle_data': {
                ...data as Map,
                'status': {
                  ...status as Map,
                  'evStatus': {...ev as Map, 'reservChargeInfos': withOffPeak(info, mode, start, end)},
                },
              },
            }, now),
          );
        }
      case OpenChargePortCommand() || FlashCommand() || HonkCommand() || TakeCameraShotsCommand():
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
    _failures = 0;
    await connect();
    if (usingDirect) await directRefresh();
  }

  /// Signs the fallback in to Bluelink with the login in [settings]. Returns
  /// a challenge when Bluelink wants a one-time code for this phone first.
  Future<OtpChallenge?> directSignIn() async {
    await settings.saveBluelink();
    final challenge = await bluelink.signIn();
    notifyListeners();
    return challenge;
  }

  Future<void> directVerify(OtpChallenge challenge, String code) async {
    await bluelink.verifyOtp(challenge, code);
    notifyListeners();
  }

  /// Signs out of Bluelink and forgets the login.
  Future<void> directSignOut() async {
    await bluelink.signOut();
    settings
      ..bluelinkUser = ''
      ..bluelinkPassword = ''
      ..bluelinkPin = '';
    await settings.saveBluelink();
    _directOk = false;
    directError = null;
    notifyListeners();
  }

  /// Saves new settings and reconnects (or switches to demo).
  Future<void> applySettings() async {
    await settings.save();
    if (settings.demo || !settings.isConfigured) {
      _startDemo();
    } else {
      _failures = 0;
      await connect();
    }
  }

  /// A full URL on the Home Assistant server, for paths like an image
  /// entity's entity_picture (which carries its own access token).
  Uri? haUri(String path) {
    final base = _activeUrl ?? settings.haUrl;
    return base.isEmpty ? null : Uri.parse(base).resolve(path);
  }

  /// Tests a URL and token without changing the live connection.
  Future<void> testConnection(String url, String token) => _clientFactory(Uri.parse(url), token).verify();

  @override
  void dispose() {
    _retry?.cancel();
    _pendingTimeout?.cancel();
    _saveTimer?.cancel();
    _sub?.cancel();
    _client?.close();
    super.dispose();
  }
}
