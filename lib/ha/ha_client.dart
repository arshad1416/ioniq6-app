import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class EntityState {
  EntityState(this.entityId, this.state, this.attributes, this.lastChanged);

  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final DateTime lastChanged;

  /// For the saved snapshot on the phone.
  factory EntityState.fromJson(Map<String, dynamic> j) => EntityState(
    j['id'] as String,
    j['s'] as String,
    Map<String, dynamic>.from(j['a'] as Map? ?? const {}),
    DateTime.fromMillisecondsSinceEpoch(j['lc'] as int),
  );

  Map<String, dynamic> toJson() => {'id': entityId, 's': state, 'a': attributes, 'lc': lastChanged.millisecondsSinceEpoch};

  EntityState copyWith({String? entityId, String? state, Map<String, dynamic>? attributes, DateTime? lastChanged}) =>
      EntityState(
        entityId ?? this.entityId,
        state ?? this.state,
        attributes ?? this.attributes,
        lastChanged ?? this.lastChanged,
      );
}

class HaException implements Exception {
  HaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The token is wrong or revoked; retrying won't help.
class HaAuthException extends HaException {
  HaAuthException() : super('Home Assistant rejected the token');
}

/// Talks to Home Assistant: the WebSocket for live state (`subscribe_entities`),
/// service calls and the registries; REST for history and the setup check.
class HaClient {
  HaClient({required this.baseUrl, required this.token, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final String token;
  final http.Client _http;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  int _nextId = 1;
  final _pending = <int, Completer<dynamic>>{};
  Timer? _heartbeat;

  /// How often the open socket is checked, and how long it has to answer.
  static const heartbeatEvery = Duration(seconds: 30);
  static const _pongWithin = Duration(seconds: 10);

  Map<String, String> get _headers => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  Uri _api(String path, [Map<String, String>? query]) =>
      baseUrl.replace(path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}/api/$path', queryParameters: query);

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final r = await _http.get(_api(path, query), headers: _headers).timeout(const Duration(seconds: 15));
    if (r.statusCode == 401) throw HaAuthException();
    if (r.statusCode != 200) throw HaException('Home Assistant answered ${r.statusCode} for $path');
    return jsonDecode(r.body);
  }

  /// Confirms the URL and token work.
  Future<void> verify() async => _get('');

  /// Checks the open socket still answers; a phone can keep a dead one open
  /// after it switches networks.
  Future<void> ping() async => _send({'type': 'ping'}, timeout: _pongWithin);

  /// Every entity Home Assistant knows: `entity_id`, `unique_id`, `platform`
  /// (the integration) and `device_id`.
  Future<List<Map<String, dynamic>>> entityRegistry() async =>
      ((await _send({'type': 'config/entity_registry/list'})) as List).cast<Map<String, dynamic>>();

  /// Over the WebSocket, because REST turns a service's own error into a bare
  /// "500 Internal Server Error"; this way the add-on's reason reaches the user.
  Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    await _send({
      'type': 'call_service',
      'domain': domain,
      'service': service,
      'service_data': data,
    }, timeout: const Duration(seconds: 120));
  }

  /// State changes for [ids] since [start], oldest first.
  Future<List<EntityState>> history(List<String> ids, DateTime start) async {
    final data = await _get('history/period/${start.toUtc().toIso8601String()}', {
      'filter_entity_id': ids.join(','),
      'minimal_response': '',
      'no_attributes': '',
    }) as List;
    final out = <EntityState>[];
    for (final series in data.cast<List>()) {
      if (series.isEmpty) continue;
      final id = (series.first as Map)['entity_id'] as String;
      for (final j in series.cast<Map>()) {
        out.add(
          EntityState(
            id,
            '${j['state']}',
            const {},
            DateTime.tryParse('${j['last_changed']}')?.toLocal() ?? DateTime.now(),
          ),
        );
      }
    }
    out.sort((a, b) => a.lastChanged.compareTo(b.lastChanged));
    return out;
  }

  /// Long-term statistics (`recorder/statistics_during_period`) over WebSocket.
  Future<List<Map<String, dynamic>>> statistics(String id, DateTime start, {String period = 'month'}) async {
    final r = await _send({
      'type': 'recorder/statistics_during_period',
      'start_time': start.toUtc().toIso8601String(),
      'statistic_ids': [id],
      'period': period,
      'types': ['change', 'state'],
    });
    return (((r as Map)[id] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// Opens the WebSocket and streams entity updates for [ids] in batches.
  /// The first batch is the current state of every entity that exists.
  Stream<List<EntityState>> subscribe(List<String> ids) {
    final out = StreamController<List<EntityState>>();
    final known = <String, EntityState>{};

    out.onListen = () async {
      try {
        await _connect(out);
        final sub = _nextId++;
        _subscriptions[sub] = (Map<String, dynamic> event) {
          final batch = <EntityState>[];
          for (final MapEntry(:key, :value) in ((event['a'] as Map?) ?? const {}).entries) {
            batch.add(known[key as String] = _fromCompressed(key, value as Map));
          }
          for (final MapEntry(:key, :value) in ((event['c'] as Map?) ?? const {}).entries) {
            final prev = known[key];
            if (prev == null) continue;
            final plus = (value as Map)['+'] as Map?;
            final minus = value['-'] as Map?;
            final attrs = Map<String, dynamic>.from(prev.attributes);
            if (plus?['a'] is Map) attrs.addAll(Map<String, dynamic>.from(plus!['a'] as Map));
            for (final k in (minus?['a'] as List?) ?? const []) {
              attrs.remove(k);
            }
            batch.add(
              known[key as String] = prev.copyWith(
                state: plus?['s'] == null ? null : '${plus!['s']}',
                attributes: attrs,
                lastChanged: plus?['lc'] == null ? null : _epoch(plus!['lc']),
              ),
            );
          }
          for (final key in (event['r'] as List?) ?? const []) {
            final gone = known.remove(key);
            if (gone != null) batch.add(gone.copyWith(state: 'unavailable'));
          }
          out.add(batch);
        };
        _ws!.sink.add(jsonEncode({'id': sub, 'type': 'subscribe_entities', 'entity_ids': ids}));
        _heartbeat = Timer.periodic(heartbeatEvery, (_) async {
          try {
            await ping();
          } catch (_) {
            if (out.isClosed) return;
            out.addError(HaException('Home Assistant stopped answering'));
            await close();
          }
        });
      } catch (e, st) {
        out.addError(e, st);
        await out.close();
      }
    };
    out.onCancel = close;
    return out.stream;
  }

  final _subscriptions = <int, void Function(Map<String, dynamic>)>{};

  static DateTime _epoch(dynamic seconds) => DateTime.fromMillisecondsSinceEpoch(((seconds as num) * 1000).round());

  static EntityState _fromCompressed(String id, Map j) => EntityState(
    id,
    '${j['s']}',
    Map<String, dynamic>.from(j['a'] as Map? ?? const {}),
    j['lc'] == null ? DateTime.now() : _epoch(j['lc']),
  );

  Future<void> _connect([StreamController<List<EntityState>>? errors]) async {
    if (_ws != null) return;
    final wsUri = baseUrl.replace(
      scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
      path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}/api/websocket',
    );
    final ws = WebSocketChannel.connect(wsUri);
    await ws.ready.timeout(const Duration(seconds: 15));
    final authed = Completer<void>();
    _ws = ws;
    _wsSub = ws.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        switch (msg['type']) {
          case 'auth_required':
            ws.sink.add(jsonEncode({'type': 'auth', 'access_token': token}));
          case 'auth_ok':
            authed.complete();
          case 'auth_invalid':
            authed.completeError(HaAuthException());
          case 'event':
            _subscriptions[msg['id']]?.call(Map<String, dynamic>.from(msg['event'] as Map));
          case 'pong':
            _pending.remove(msg['id'])?.complete(null);
          case 'result':
            final c = _pending.remove(msg['id']);
            if (c == null) break;
            if (msg['success'] == true) {
              c.complete(msg['result']);
            } else {
              c.completeError(HaException('${(msg['error'] as Map?)?['message'] ?? 'request failed'}'));
            }
        }
      },
      onError: (Object e) => errors?.addError(e),
      onDone: () {
        _ws = null;
        errors?.addError(HaException('Lost the connection to Home Assistant'));
        for (final c in _pending.values) {
          c.completeError(HaException('Connection closed'));
        }
        _pending.clear();
      },
    );
    try {
      await authed.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      await close(); // don't leave a half-open socket for the next call to reuse
      rethrow;
    }
  }

  Future<dynamic> _send(Map<String, dynamic> msg, {Duration timeout = const Duration(seconds: 20)}) async {
    await _connect();
    final id = _nextId++;
    final c = Completer<dynamic>();
    _pending[id] = c;
    _ws!.sink.add(jsonEncode({...msg, 'id': id}));
    return c.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Home Assistant took too long to answer');
      },
    );
  }

  Future<void> close() async {
    _heartbeat?.cancel();
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _ws = null;
    _subscriptions.clear();
    for (final c in _pending.values) {
      c.completeError(HaException('Connection closed'));
    }
    _pending.clear();
  }
}
