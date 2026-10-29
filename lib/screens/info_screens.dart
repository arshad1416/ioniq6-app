import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<List<Map<String, dynamic>>>? _months;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _months ??= AppScope.of(context).monthlyOdometer();
  }

  @override
  Widget build(BuildContext context) {
    final car = AppScope.of(context).car;
    final days = car.dailyStats;
    final km = days.fold<num>(0, (a, d) => a + d.distanceKm);
    final wh = days.fold<num>(0, (a, d) => a + d.consumedWh);
    return SubScreen(
      title: 'Stats',
      children: [
        Column(
          children: [
            const Lbl('Odometer'),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: thousands(car.odometerKm), style: Txt.display(52, weight: 200)),
                  TextSpan(
                    text: ' km',
                    style: Txt.display(22, color: Palette.mute),
                  ),
                ],
              ),
            ),
          ],
        ),
        Panel(
          children: [
            const Lbl('Distance per month, km'),
            FutureBuilder(
              future: _months,
              builder: (context, snap) {
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      snap.connectionState == ConnectionState.waiting ? 'Loading…' : 'No history in Home Assistant yet',
                      style: Txt.muted(13),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return _MonthChart(rows);
              },
            ),
          ],
        ),
        if (days.isNotEmpty)
          Panel(
            children: [
              Lbl('Last ${days.length} days with driving'),
              for (final d in days)
                Kv(
                  '${_weekday(d.day)} ${d.day.day}',
                  '${d.distanceKm} km · ${(d.consumedWh / 1000).toStringAsFixed(1)} kWh',
                ),
              if (km > 0) Kv('Efficiency', '${(wh / 10 / km).toStringAsFixed(1)} kWh/100 km'),
              if (days.any((d) => d.regenWh > 0))
                Kv(
                  'Recovered by regen',
                  '${(days.fold<num>(0, (a, d) => a + d.regenWh) / 1000).toStringAsFixed(1)} kWh',
                ),
            ],
          ),
      ],
    );
  }
}

class _MonthChart extends StatelessWidget {
  const _MonthChart(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final values = [for (final r in rows) ((r['change'] as num?) ?? 0).toDouble()];
    final top = values.fold<double>(1, (a, b) => b > a ? b : a);
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Column(
      children: [
        const SizedBox(height: 18),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(values[i].round().toString(), style: Txt.mono(10, weight: 400)),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder(
                          tween: Tween(begin: 0.0, end: values[i] / top),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, f, _) => Container(
                            height: 96 * f,
                            decoration: BoxDecoration(
                              color: i == values.length - 1 ? Palette.red : Palette.unlit,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                                bottom: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(color: Palette.line, height: 1),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final r in rows)
              Expanded(
                child: Text(
                  names[(_start(r)?.month ?? 1) - 1],
                  textAlign: TextAlign.center,
                  style: Txt.mono(10, weight: 400),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static DateTime? _start(Map<String, dynamic> r) {
    final s = r['start'];
    if (s is num) return DateTime.fromMillisecondsSinceEpoch(s.toInt());
    return DateTime.tryParse('$s')?.toLocal();
  }
}

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final car = AppScope.of(context).car;
    final tires = car.tireWarnings;
    Widget tire(String k, Alignment a) => Align(
      alignment: a,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Palette.raise,
          border: Border.all(color: Palette.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$k ${tires[k] == true ? 'low' : 'ok'}',
          style: Txt.mono(11, color: tires[k] == true ? Palette.amber : Palette.ok),
        ),
      ),
    );
    return SubScreen(
      title: 'Health',
      children: [
        SizedBox(
          height: 230,
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'car',
                  child: RotatedBox(quarterTurns: 1, child: Image.asset('assets/images/top.webp', fit: BoxFit.contain)),
                ),
              ),
              tire('FL', const Alignment(-.85, -.7)),
              tire('FR', const Alignment(.85, -.7)),
              tire('RL', const Alignment(-.85, .7)),
              tire('RR', const Alignment(.85, .7)),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            StatusChip(car.tiresOk ? 'Tires ok' : 'Check tire pressure', ok: car.tiresOk),
            StatusChip(car.lampsOk ? 'Lamps ok' : 'Lamp fault', ok: car.lampsOk),
            StatusChip(car.brakeFluidOk ? 'Brake fluid ok' : 'Brake fluid low', ok: car.brakeFluidOk),
            StatusChip(car.washerFluidOk ? 'Washer fluid ok' : 'Washer fluid low', ok: car.washerFluidOk),
            StatusChip('${car.dtcCount} fault codes', ok: car.dtcCount == 0),
          ],
        ),
        Panel(
          children: [
            Kv('12 V battery', car.twelveVoltPct == null ? '–' : '${car.twelveVoltPct}%'),
            Kv('High-voltage battery', car.soc == null ? '–' : '${car.soc}%'),
            Kv('Doors, hood, trunk', car.allClosed ? 'Closed' : 'Open'),
            // Bluelink's service schedule can lag the odometer, so show it as reported.
            if (car.nextServiceKm != null) Kv('Next service (Bluelink)', 'at ${thousands(car.nextServiceKm)} km'),
          ],
        ),
      ],
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = AppScope.of(context).activity;
    return SubScreen(
      title: 'Activity',
      children: [
        if (items.isEmpty) Text('Nothing in the last two days.', style: Txt.muted(13)),
        for (final a in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Palette.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 64, child: Text(_when(a.time), style: Txt.mono(11, weight: 400))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: Txt.body(13)),
                      if (a.detail.isNotEmpty) Text(a.detail, style: Txt.muted(12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? hm(t) : '${_weekday(t)} ${hm(t)}';
  }
}

String _weekday(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
