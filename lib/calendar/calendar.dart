import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One occurrence of an event on the phone's calendar.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.allDay = false,
    this.calendar = '',
    this.color,
  });

  factory CalendarEvent.fromMap(Map<dynamic, dynamic> m) {
    final allDay = m['allDay'] == true;
    // All-day instances are stored at UTC midnight; show them on that local date.
    DateTime at(Object? ms) {
      final t = DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: allDay);
      return allDay ? DateTime(t.year, t.month, t.day) : t.toLocal();
    }

    final title = (m['title'] as String?)?.trim() ?? '';
    return CalendarEvent(
      title: title.isEmpty ? '(No title)' : title,
      start: at(m['begin']),
      end: at(m['end']),
      location: (m['location'] as String?)?.trim() ?? '',
      allDay: allDay,
      calendar: (m['calendar'] as String?) ?? '',
      color: (m['color'] as num?)?.toInt(),
    );
  }

  final String title, location, calendar;
  final DateTime start, end;
  final bool allDay;
  final int? color;

  /// Whether there's an address (or place name) to drive to.
  bool get hasPlace => location.isNotEmpty;

  /// Google Maps, straight into driving directions. With Android Auto
  /// connected, the route shows on the car's screen.
  Uri get mapsUri => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'travelmode': 'driving',
    'dir_action': 'navigate',
    'destination': location,
  });
}

/// The next timed event with somewhere to go that hasn't ended yet.
CalendarEvent? nextTrip(Iterable<CalendarEvent> events, DateTime now) {
  final trips = events.where((e) => !e.allDay && e.hasPlace && e.end.isAfter(now)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  return trips.isEmpty ? null : trips.first;
}

/// Reads the phone's calendar through the Android side. Off Android, and in
/// tests, it reports no access and no events.
abstract final class PhoneCalendar {
  static const _channel = MethodChannel('ioniq6/calendar');

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasPermission() => _ask('hasPermission');

  /// Shows Android's permission prompt if access hasn't been given yet.
  static Future<bool> requestPermission() => _ask('requestPermission');

  static Future<List<CalendarEvent>> upcoming({Duration ahead = const Duration(days: 7)}) async {
    if (!_android) return const [];
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    try {
      final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>('events', {
        'from': from.millisecondsSinceEpoch,
        'to': now.add(ahead).millisecondsSinceEpoch,
      });
      return [for (final r in rows ?? const <Map<dynamic, dynamic>>[]) CalendarEvent.fromMap(r)]
          .where((e) => e.end.isAfter(now))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
    } on PlatformException catch (e) {
      debugPrint('Calendar: $e');
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<bool> _ask(String method) async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (e) {
      debugPrint('Calendar: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
