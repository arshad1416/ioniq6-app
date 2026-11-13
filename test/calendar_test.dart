import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/calendar/calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 12, 9);
  CalendarEvent at(int day, int hour, {String place = '', bool allDay = false, String title = 'x'}) => CalendarEvent(
    title: title,
    start: DateTime(2026, 11, day, hour),
    end: DateTime(2026, 11, day, hour + 1),
    location: place,
    allDay: allDay,
  );

  test('reads a row from the phone', () {
    final start = DateTime(2026, 11, 13, 8, 30);
    final e = CalendarEvent.fromMap({
      'begin': start.millisecondsSinceEpoch,
      'end': start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'title': '  Dentist ',
      'location': ' 100 Queen St W ',
      'allDay': false,
      'calendar': 'Work',
      'color': 0xFF0000,
    });
    expect(e.title, 'Dentist');
    expect(e.location, '100 Queen St W');
    expect(e.start, start);
    expect(e.hasPlace, isTrue);
    expect(e.calendar, 'Work');
  });

  test('an all-day event lands on its own date and a missing title gets a placeholder', () {
    final e = CalendarEvent.fromMap({
      'begin': DateTime.utc(2026, 11, 14).millisecondsSinceEpoch,
      'end': DateTime.utc(2026, 11, 15).millisecondsSinceEpoch,
      'title': null,
      'location': null,
      'allDay': true,
    });
    expect(e.start, DateTime(2026, 11, 14));
    expect(e.title, '(No title)');
    expect(e.hasPlace, isFalse);
  });

  test('maps link opens driving navigation to the address', () {
    final uri = at(13, 8, place: '100 Queen St W, Toronto & Co').mapsUri;
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '100 Queen St W, Toronto & Co');
    expect(uri.queryParameters['travelmode'], 'driving');
    expect(uri.queryParameters['dir_action'], 'navigate');
    expect(uri.toString(), contains('Toronto+%26+Co'));
  });

  test('next trip is the earliest timed event with a place that has not ended', () {
    final events = [
      at(12, 7, place: 'Gym', title: 'ended'),
      at(13, 10, place: 'Office', title: 'later'),
      at(12, 12, title: 'no place'),
      at(12, 0, place: 'Cottage', allDay: true, title: 'all day'),
      at(12, 15, place: 'Clinic', title: 'next'),
    ];
    expect(nextTrip(events, now)?.title, 'next');
    expect(nextTrip([at(12, 12)], now), isNull);
  });

  test('without the Android side there is no access and no events', () async {
    expect(await PhoneCalendar.hasPermission(), isFalse);
    expect(await PhoneCalendar.upcoming(), isEmpty);
  });
}
