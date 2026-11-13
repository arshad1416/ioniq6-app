import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../car/charge_schedule.dart';
import '../car/commands.dart';

/// Bluelink answered with an error, or not at all.
class BluelinkException implements Exception {
  BluelinkException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Bluelink has no usable sign-in on this phone; sign in again in Settings.
class BluelinkSignedOut extends BluelinkException {
  BluelinkSignedOut([super.message = 'Sign in to Bluelink again in Settings']);
}

class BluelinkCredentials {
  const BluelinkCredentials({required this.user, required this.password, required this.pin});
  final String user, password, pin;
}

/// A new device has to be confirmed with a one-time code before it can sign in.
class OtpChallenge {
  OtpChallenge({required this.userInfoUuid, required this.email, this.phone});
  final String userInfoUuid;
  final String email;
  final String? phone;
  String? otpKey;
}

/// What a sign-in leaves behind: tokens, this phone's device id and the car.
class BluelinkSession {
  BluelinkSession({required this.deviceId, this.accessToken, this.refreshToken, this.validUntil, this.vehicleId});

  /// Stays the same for the life of the install, so Bluelink asks for the
  /// one-time code only once.
  final String deviceId;
  String? accessToken, refreshToken, vehicleId;
  DateTime? validUntil;

  bool get signedIn => refreshToken != null;
  bool get fresh => accessToken != null && validUntil != null && DateTime.now().isBefore(validUntil!);

  factory BluelinkSession.fromJson(Map<String, dynamic> j) => BluelinkSession(
    deviceId: j['deviceId'] as String,
    accessToken: j['accessToken'] as String?,
    refreshToken: j['refreshToken'] as String?,
    vehicleId: j['vehicleId'] as String?,
    validUntil: j['validUntil'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['validUntil'] as int),
  );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'vehicleId': vehicleId,
    'validUntil': validUntil?.millisecondsSinceEpoch,
  };

  /// A signed-out session with a new device id.
  factory BluelinkSession.create() {
    final random = Random.secure();
    final hex = [for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
    return BluelinkSession(deviceId: base64Encode(utf8.encode(hex)));
  }
}

/// Talks to Bluelink Canada (mybluelink.ca) the way the MyHyundai phone app
/// does. Used only as a fallback when Home Assistant can't reach the car, so
/// it never polls: every call here is the result of something the user did.
///
/// Request shapes follow the Hyundai / Kia Connect library's Canadian client
/// and the app's own (see ha/custom_components/ioniq6_extras/bluelink.py).
class BluelinkClient {
  BluelinkClient({
    required this.credentials,
    required this.session,
    required this.onSession,
    http.Client? client,
    this.pollEvery = const Duration(seconds: 5),
    this.commandTimeout = const Duration(seconds: 90),
  }) : _http = client ?? http.Client();

  /// Read at each use; null when the user hasn't set Bluelink up.
  final BluelinkCredentials? Function() credentials;
  BluelinkSession session;

  /// Called whenever the session changes, to store it.
  final Future<void> Function(BluelinkSession) onSession;
  final http.Client _http;
  final Duration pollEvery, commandTimeout;

  static final _api = Uri.parse('https://mybluelink.ca/tods/api/');
  static const _timeout = Duration(seconds: 30);

  /// Token expired, deleted, or issued to another network address.
  static const _tokenErrors = {'7403', '7602', '7606'};
  static const _otpRequired = '7110';
  static const _mfaCode = '0107';

  BluelinkCredentials get _creds => credentials() ?? (throw BluelinkSignedOut());

  Map<String, String> _headers({bool token = true, String? pAuth, String? transactionId}) => {
    'User-Agent': 'okhttp/4.12.0',
    'Content-Type': 'application/json;charset=UTF-8',
    'from': 'SPA',
    'offset': '${DateTime.now().timeZoneOffset.inHours}',
    'language': '0',
    'client_id': 'HATAHSPACA0232141ED9722C67715A0B',
    'client_secret': 'CLISCR01AHSPA',
    'Deviceid': session.deviceId,
    if (token) 'accessToken': session.accessToken ?? '',
    if (token && session.vehicleId != null) 'vehicleId': session.vehicleId!,
    'pAuth': ?pAuth,
    'transactionId': ?transactionId,
  };

  /// One POST. Returns the JSON envelope and the response headers; throws on
  /// an error envelope unless its code is in [allow].
  Future<(Map<String, dynamic>, Map<String, String>)> _raw(
    String path,
    Map<String, String> headers, {
    Object? body,
    Set<String> allow = const {},
  }) async {
    final http.Response r;
    try {
      r = await _http
          .post(_api.resolve(path), headers: headers, body: body == null ? null : jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      throw BluelinkException('Bluelink didn\'t answer in time');
    } on http.ClientException catch (e) {
      throw BluelinkException('Couldn\'t reach Bluelink: ${e.message}');
    }
    Map<String, dynamic> data;
    try {
      final decoded = r.body.isEmpty ? const <String, dynamic>{} : jsonDecode(r.body);
      data = decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      throw BluelinkException('Bluelink answered HTTP ${r.statusCode} with something unreadable');
    }
    final error = data['error'];
    if ((data['responseHeader'] as Map?)?['responseCode'] == 1 || error is Map && error.isNotEmpty) {
      final code = '${(error as Map?)?['errorCode'] ?? ''}';
      if (!allow.contains(code)) {
        throw BluelinkException('${error?['errorDesc'] ?? 'Bluelink error $code'}', code: code);
      }
    }
    return (data, r.headers);
  }

  /// A signed-in POST: refreshes the token first when it has run out, and
  /// once more if Bluelink says it's no longer good.
  Future<(Map<String, dynamic>, Map<String, String>)> _post(
    String path, {
    Object? body,
    String? pAuth,
    String? transactionId,
  }) async {
    if (!session.signedIn) throw BluelinkSignedOut();
    if (!session.fresh) await _refresh();
    try {
      return await _raw(
        path,
        _headers(pAuth: pAuth, transactionId: transactionId),
        body: body,
      );
    } on BluelinkException catch (e) {
      if (!_tokenErrors.contains(e.code)) rethrow;
      await _refresh();
      return _raw(
        path,
        _headers(pAuth: pAuth, transactionId: transactionId),
        body: body,
      );
    }
  }

  Future<void> _adopt(Map<String, dynamic> token) async {
    session
      ..accessToken = token['accessToken'] as String
      ..refreshToken = token['refreshToken'] as String
      ..validUntil = DateTime.now().add(Duration(seconds: int.parse('${token['expireIn']}') - 60));
    await onSession(session);
  }

  // Sign-in --------------------------------------------------------------------

  /// Signs in. Returns a challenge when Bluelink wants a one-time code for
  /// this phone first (then [sendOtp] and [verifyOtp]); null when signed in.
  Future<OtpChallenge?> signIn() async {
    final creds = _creds;
    final (data, _) = await _raw(
      'v2/login',
      _headers(token: false),
      body: {'loginId': creds.user, 'password': creds.password},
      allow: {_otpRequired},
    );
    if ((data['error'] as Map?)?['errorCode'] == _otpRequired) {
      final (methods, _) = await _raw(
        'mfa/selverifmeth',
        _headers(token: false),
        body: {'mfaApiCode': _mfaCode, 'userAccount': creds.user},
      );
      final result = (methods['result'] as Map?) ?? const {};
      final emails = (result['emailList'] as List?) ?? const [];
      return OtpChallenge(
        userInfoUuid: '${result['userInfoUuid']}',
        email: emails.isEmpty ? creds.user : '${emails.first}',
        phone: result['userPhone'] as String?,
      );
    }
    await _adopt(Map<String, dynamic>.from((data['result'] as Map)['token'] as Map));
    await _pickVehicle();
    return null;
  }

  /// Has Bluelink send the one-time code, by email or by text.
  Future<void> sendOtp(OtpChallenge challenge, {bool sms = false}) async {
    final (data, _) = await _raw(
      'mfa/sendotp',
      _headers(token: false),
      body: {
        'otpMethod': sms ? 'S' : 'E',
        'mfaApiCode': _mfaCode,
        'userAccount': challenge.email,
        'userPhone': sms ? challenge.phone ?? '' : '',
        'userInfoUuid': challenge.userInfoUuid,
      },
    );
    challenge.otpKey = '${(data['result'] as Map)['otpKey']}';
  }

  /// Finishes the sign-in with the code the user received.
  Future<void> verifyOtp(OtpChallenge challenge, String code) async {
    final creds = _creds;
    final (checked, _) = await _raw(
      'mfa/validateotp',
      _headers(token: false),
      body: {'otpNo': code.trim(), 'userAccount': creds.user, 'otpKey': challenge.otpKey, 'mfaApiCode': _mfaCode},
    );
    final result = (checked['result'] as Map?) ?? const {};
    if (result['verifiedOtp'] != true) throw BluelinkException('That code wasn\'t accepted');
    final (minted, _) = await _raw(
      'mfa/genmfatkn',
      _headers(token: false),
      body: {
        'userAccount': creds.user,
        'otpEmail': challenge.email,
        'mfaApiCode': _mfaCode,
        'otpValidationKey': result['otpValidationKey'],
        'mfaYn': 'Y',
      },
    );
    await _adopt(Map<String, dynamic>.from((minted['result'] as Map)['token'] as Map));
    await _pickVehicle();
  }

  /// A new access token from the refresh token, else a fresh sign-in.
  Future<void> _refresh() async {
    try {
      final (data, _) = await _raw(
        'gtothbyrftkn',
        _headers(token: false),
        body: {'refTokenData': session.refreshToken},
      );
      await _adopt(Map<String, dynamic>.from(data['result'] as Map));
      return;
    } on BluelinkException {
      // The refresh token is spent; sign in again with the stored login.
    }
    if (await signIn() != null) {
      throw BluelinkSignedOut('Bluelink wants a new one-time code; sign in again in Settings');
    }
  }

  Future<void> _pickVehicle() async {
    final (data, _) = await _raw('vhcllst', _headers());
    final vehicles = ((data['result'] as Map?)?['vehicles'] as List?) ?? const [];
    if (vehicles.isEmpty) throw BluelinkException('This Bluelink account has no car');
    session.vehicleId = '${(vehicles.first as Map)['vehicleId']}';
    await onSession(session);
  }

  Future<void> signOut() async {
    session = BluelinkSession(deviceId: session.deviceId);
    await onSession(session);
  }

  // Reads ----------------------------------------------------------------------

  /// The car's status. By default the last one it reported to Bluelink, which
  /// doesn't wake it; [wake] asks the car itself.
  Future<Map<String, dynamic>> status({bool wake = false}) async {
    final (data, _) = await _post(wake ? 'rltmvhclsts' : 'lstvhclsts');
    return Map<String, dynamic>.from(((data['result'] as Map?)?['status'] as Map?) ?? const {});
  }

  /// The AC and DC charge limits, in percent.
  Future<({int? ac, int? dc})> chargeLimits() async {
    final (data, _) = await _post('evc/selsoc');
    int? level(int plugType) {
      for (final entry in (data['result'] as List?) ?? const []) {
        if (entry is Map && entry['plugType'] == plugType && entry['level'] is num && entry['level'] <= 100) {
          return (entry['level'] as num).round();
        }
      }
      return null;
    }

    return (ac: level(1), dc: level(0));
  }

  /// Find My Car (read only).
  Future<(double, double)?> locate() async {
    final (data, _) = await _post('evc/fme', pAuth: await _pinToken());
    final result = (data['result'] as Map?) ?? const {};
    final coord = (result['coord'] ?? (result['gpsDetail'] as Map?)?['coord']) as Map?;
    final lat = coord?['lat'], lon = coord?['lon'];
    return lat is num && lon is num ? (lat.toDouble(), lon.toDouble()) : null;
  }

  // Commands -------------------------------------------------------------------

  /// Whether [cmd] can be sent this way. Flash, honk, the charge port and new
  /// 360 shots only go through Home Assistant for now.
  static bool supports(CarCommand cmd) => switch (cmd) {
    FlashCommand() || HonkCommand() || OpenChargePortCommand() || TakeCameraShotsCommand() => false,
    _ => true,
  };

  /// Sends [cmd] to the car and waits for the car to confirm it.
  Future<void> send(CarCommand cmd) async {
    final pin = _creds.pin;
    if (cmd is SetOffPeakCommand) return _setOffPeak(cmd, pin);
    final (String path, Map<String, dynamic> extra) = switch (cmd) {
      LockCommand() => ('drlck', const {}),
      UnlockCommand() => ('drulck', const {}),
      StartClimateCommand(:final request) => ('evc/rfon', {'hvacInfo': climateSettings(request)}),
      StopClimateCommand() => ('evc/rfoff', const {}),
      StartChargeCommand() => ('evc/rcstrt', const {}),
      StopChargeCommand() => ('evc/rcstp', const {}),
      SetChargeLimitsCommand(:final ac, :final dc) => (
        'evc/setsoc',
        {
          'tsoc': [
            {'plugType': 0, 'level': dc},
            {'plugType': 1, 'level': ac},
          ],
        },
      ),
      ValetCommand(:final on) => (on ? 'valet/activate' : 'valet/deactivate', const {}),
      PreconditionCommand(:final on) => (on ? 'evc/prcndtngon' : 'evc/prcndtngoff', const {}),
      _ => throw BluelinkException('${cmd.label} isn\'t available directly from Bluelink yet'),
    };
    final (_, headers) = await _post(path, body: {'pin': pin, ...extra}, pAuth: await _pinToken());
    final transaction = headers['transactionid'];
    if (transaction != null && transaction.isNotEmpty) await _waitFor(transaction);
  }

  /// The car's telematics generation ("Gen3" or another value), which
  /// decides how a schedule is saved.
  Future<String?> generation() async {
    final (data, _) = await _post('vhcllst');
    for (final v in ((data['result'] as Map?)?['vehicles'] as List?) ?? const []) {
      if (v is Map && '${v['vehicleId']}' == session.vehicleId) return v['genHeaderType'] as String?;
    }
    return null;
  }

  /// As the MyHyundai app saves it: Gen3 cars take only the window, with
  /// the PIN check as a gate; others take the whole schedule with pAuth. The
  /// app doesn't wait on the car for either.
  Future<void> _setOffPeak(SetOffPeakCommand cmd, String pin) async {
    if ((await generation())?.toLowerCase() == 'gen3') {
      await _pinToken();
      await _post('v2/rc/ev/reschargeset', body: gen3ScheduleBody(pin, cmd.mode, cmd.start, cmd.end));
      return;
    }
    final current = (await status())['evStatus'];
    final info = current is Map ? current['reservChargeInfos'] : null;
    if (info is! Map) {
      throw BluelinkException('The car hasn\'t reported its schedule yet, so it can\'t be changed safely');
    }
    await _post(
      'evc/srcfs',
      body: {'pin': pin, 'reservChargeInfos': srcfsSchedule(info, cmd.mode, cmd.start, cmd.end)},
      pAuth: await _pinToken(),
    );
  }

  /// The body Bluelink expects for an EV climate start.
  static Map<String, dynamic> climateSettings(ClimateRequest request) => {
    'airCtrl': 1,
    'defrost': request.defrost,
    'heating1': request.wheel ? 4 : 0,
    'airTemp': {'value': tempCode(request.tempC), 'unit': 0, 'hvacTempType': 1},
    'igniOnDuration': request.minutes,
    'seatHeaterVentCMD': {
      'drvSeatOptCmd': request.driverSeat.code,
      'astSeatOptCmd': request.passengerSeat.code,
      'rlSeatOptCmd': 0,
      'rrSeatOptCmd': 0,
    },
  };

  /// Bluelink's code for a temperature: half-degree steps from 14 °C, as two
  /// hex digits and an H ("0EH" is 21 °C).
  static String tempCode(double celsius) {
    final index = ((celsius.clamp(14, 31.5) - 14) * 2).round();
    return '${index.toRadixString(16).padLeft(2, '0')}H'.toUpperCase();
  }

  /// The temperature for one of Bluelink's codes, or null for "OFF" and the like.
  static double? tempFromCode(Object? code) {
    if (code is! String || !code.endsWith('H')) return null;
    final index = int.tryParse(code.substring(0, code.length - 1), radix: 16);
    return index == null ? null : 14 + index / 2;
  }

  /// vrfypin: trades the PIN for the pAuth token that commands need.
  Future<String> _pinToken() async {
    final (data, _) = await _post('vrfypin', body: {'pin': _creds.pin});
    final pAuth = (data['result'] as Map?)?['pAuth'];
    if (pAuth is! String || pAuth.isEmpty) throw BluelinkException('Bluelink didn\'t accept the PIN');
    return pAuth;
  }

  /// Polls rmtsts until the car confirms the command, refuses it, or time runs out.
  Future<void> _waitFor(String transaction) async {
    final pAuth = await _pinToken();
    final deadline = DateTime.now().add(commandTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final (data, _) = await _post('rmtsts', pAuth: pAuth, transactionId: transaction);
      switch (((data['result'] as Map?)?['transaction'] as Map?)?['apiResult']) {
        case 'C':
          return;
        case 'P':
          await Future<void>.delayed(pollEvery);
        default:
          throw BluelinkException('The car didn\'t confirm the change');
      }
    }
    throw BluelinkException('The car didn\'t answer in time');
  }
}
