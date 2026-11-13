import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../calendar/calendar.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_icon.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// The clock time in the phone's 12 or 24 hour style.
String clockTime(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(t), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));

/// "Today", "Tomorrow" or "Fri 14 Nov".
String dayName(DateTime t, DateTime now) {
  final days = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
}

/// "8:30 AM tomorrow", "8:30 AM today" or "Fri 8:30 AM".
String tripWhen(BuildContext context, DateTime t, DateTime now) {
  final day = dayName(t, now);
  final time = clockTime(context, t);
  return day.length > 8 ? '${day.substring(0, 3)} $time' : '$time ${day.toLowerCase()}';
}

/// Opens Google Maps driving directions to the event, or says it has no address.
Future<void> navigateTo(BuildContext context, CalendarEvent e) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  if (!e.hasPlace) return say('No address on this event');
  if (!await launchUrl(e.mapsUri, mode: LaunchMode.externalApplication)) say('Couldn\'t open Google Maps');
}

/// Upcoming events from the phone's calendar. A tap on one with an address
/// starts Google Maps navigation, which shows on the car through Android Auto.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> with WidgetsBindingObserver {
  bool? _allowed;
  List<CalendarEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final allowed = await PhoneCalendar.hasPermission();
    final events = allowed ? await PhoneCalendar.upcoming() : const <CalendarEvent>[];
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _events = events;
    });
  }

  Future<void> _allow() async {
    final ok = await PhoneCalendar.requestPermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar access is off. You can turn it on in Android settings for this app.')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SubScreen(
      title: 'Next trip',
      children: switch (_allowed) {
        null => [Text('Loading…', style: Txt.muted(15), textAlign: TextAlign.center)],
        false => [
          Panel(
            children: [
              const Lbl('From your calendar'),
              Text(
                'See your calendar\'s upcoming events here. Tap one with an address to start Google Maps '
                'navigation, which shows on the car through Android Auto.',
                style: Txt.body(16),
              ),
              FilledButton(
                onPressed: _allow,
                style: FilledButton.styleFrom(backgroundColor: Palette.red),
                child: const Text('Allow calendar access'),
              ),
            ],
          ),
          _privacy,
        ],
        true => [..._list(context, now), _privacy],
      },
    );
  }

  static final _privacy = Text(
    'Events are read on this phone only and never leave it.',
    style: Txt.muted(14),
    textAlign: TextAlign.center,
  );

  List<Widget> _list(BuildContext context, DateTime now) {
    final next = nextTrip(_events, now);
    final days = <String, List<CalendarEvent>>{};
    for (final e in _events) {
      days.putIfAbsent(dayName(e.start, now), () => []).add(e);
    }
    return [
      if (next != null)
        Panel(
          children: [
            Lbl('From your calendar · ${next.calendar}'),
            Text(next.title, style: Txt.display(26)),
            Kv('Where', next.location),
            Kv('Starts', tripWhen(context, next.start, now)),
            FilledButton.icon(
              onPressed: () => navigateTo(context, next),
              style: FilledButton.styleFrom(backgroundColor: Palette.red),
              icon: const Icon(Icons.navigation_outlined, size: 18),
              label: const Text('Navigate'),
            ),
          ],
        ),
      if (_events.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Nothing on your calendar in the next 7 days', style: Txt.muted(15), textAlign: TextAlign.center),
        ),
      for (final MapEntry(key: day, value: events) in days.entries) ...[
        Lbl(day),
        RowsCard(
          children: [
            for (final e in events)
              NavRow(
                glyph: const LineIcon(Glyphs.calendar),
                label: e.title,
                sub: [e.allDay ? 'All day' : clockTime(context, e.start), if (e.hasPlace) e.location].join(' · '),
                value: e.hasPlace ? 'Navigate' : null,
                onTap: () => navigateTo(context, e),
              ),
          ],
        ),
      ],
    ];
  }
}

/// Home's "Next trip" row. Reads the calendar only if access was already
/// given, so opening the app never shows a permission prompt.
class NextTripRow extends StatefulWidget {
  const NextTripRow({super.key});

  @override
  State<NextTripRow> createState() => _NextTripRowState();
}

class _NextTripRowState extends State<NextTripRow> with WidgetsBindingObserver {
  CalendarEvent? _next;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final next = await PhoneCalendar.hasPermission() ? nextTrip(await PhoneCalendar.upcoming(), DateTime.now()) : null;
    if (mounted) setState(() => _next = next);
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    return NavRow(
      glyph: const LineIcon(Glyphs.calendar),
      label: 'Next trip',
      sub: next == null ? 'From your calendar' : next.title,
      value: next == null ? null : tripWhen(context, next.start, DateTime.now()),
      onTap: () async {
        await Navigator.pushNamed(context, '/trip');
        _load();
      },
    );
  }
}
