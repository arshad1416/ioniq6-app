import '../bluelink/bluelink_client.dart';

/// How the car uses its off-peak window (Bluelink's offPeakPowerFlag).
enum OffPeakMode {
  /// 0: charges whenever it's plugged in.
  off,

  /// 1: charges in the window first, then outside it if it needs to.
  prefer,

  /// 2: charges only in the window.
  only,
}

/// One of the car's two scheduled departures.
class Departure {
  const Departure({
    required this.enabled,
    required this.days,
    required this.minutes,
    required this.climateOn,
    required this.defrost,
    this.tempC,
  });

  final bool enabled;

  /// 0 is Sunday through 6, Saturday.
  final List<int> days;

  /// Minutes after midnight.
  final int minutes;
  final bool climateOn, defrost;
  final double? tempC;
}

/// The charge schedule stored in the car, as Bluelink reports it in every
/// status (evStatus.reservChargeInfos). Read-only for now.
class ChargeSchedule {
  const ChargeSchedule({
    required this.mode,
    required this.start,
    required this.end,
    required this.scheduledCharging,
    required this.departures,
  });

  final OffPeakMode mode;

  /// The off-peak window, in minutes after midnight.
  final int start, end;

  /// Whether the car charges to be ready for its departures.
  final bool scheduledCharging;
  final List<Departure> departures;

  String get window => '${clock(start)}–${clock(end)}';

  /// Null when the status has no schedule or it isn't the expected shape.
  static ChargeSchedule? tryParse(Object? info) {
    if (info is! Map) return null;
    final offPeak = info['offpeakPowerInfo'];
    if (offPeak is! Map) return null;
    final times = offPeak['offPeakPowerTime1'];
    final start = times is Map ? _minutes(times['starttime']) : null;
    final end = times is Map ? _minutes(times['endtime']) : null;
    final mode = switch (offPeak['offPeakPowerFlag']) {
      0 => OffPeakMode.off,
      1 => OffPeakMode.prefer,
      2 => OffPeakMode.only,
      _ => null,
    };
    if (start == null || end == null || mode == null) return null;
    return ChargeSchedule(
      mode: mode,
      start: start,
      end: end,
      scheduledCharging: info['reservFlag'] == 1,
      departures: [
        for (final key in ['reservChargeInfo', 'reserveChargeInfo2']) ?_departure(info[key]),
      ],
    );
  }

  static Departure? _departure(Object? info) {
    final detail = info is Map ? info['reservChargeInfoDetail'] : null;
    if (detail is! Map) return null;
    final reserv = detail['reservInfo'];
    if (reserv is! Map) return null;
    final minutes = _minutes(reserv['time']);
    if (minutes == null) return null;
    final fatc = detail['reservFatcSet'] is Map ? detail['reservFatcSet'] as Map : const {};
    final temp = fatc['airTemp'] is Map ? (fatc['airTemp'] as Map)['value'] : null;
    return Departure(
      enabled: detail['reservChargeSet'] == true,
      days: [
        for (final d in reserv['day'] is List ? reserv['day'] as List : const [])
          if (d is int && d >= 0 && d <= 6) d,
      ]..sort(),
      minutes: minutes,
      climateOn: fatc['airCtrl'] == 1,
      defrost: fatc['defrost'] == true,
      tempC: BluelinkClient.tempFromCode(temp),
    );
  }

  /// Bluelink's {"time": "hhmm", "timeSection": 0 for AM, 1 for PM}.
  static int? _minutes(Object? t) {
    if (t is! Map) return null;
    final raw = t['time'], section = t['timeSection'];
    if (raw is! String || raw.length != 4 || (section != 0 && section != 1)) return null;
    final h = int.tryParse(raw.substring(0, 2)), m = int.tryParse(raw.substring(2));
    if (h == null || m == null || h < 0 || h > 12 || m > 59) return null;
    return ((h % 12) + (section == 1 ? 12 : 0)) * 60 + m;
  }
}

/// "07:00", "23:30".
String clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// "Weekdays", "Every day", "Weekends", or "Mon, Wed".
String daySummary(List<int> days) {
  final set = days.toSet();
  if (set.length == 7) return 'Every day';
  if (set.length == 5 && set.containsAll([1, 2, 3, 4, 5])) return 'Weekdays';
  if (set.length == 2 && set.containsAll([0, 6])) return 'Weekends';
  if (set.isEmpty) return 'No days';
  const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return (set.toList()..sort()).map((d) => names[d]).join(', ');
}
