import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_car.dart';

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
    final units = AppScope.of(context).settings.units;
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  RollingNumber(thousands(units.dist(car.odometerKm)), style: Txt.display(52, weight: 200)),
                  Text(' ${units.distance}', style: Txt.display(22, color: Palette.mute)),
                ],
              ),
            ),
          ],
        ),
        Panel(
          children: [
            Lbl('Distance per month, ${units.distance}'),
            FutureBuilder(
              future: _months,
              builder: (context, snap) {
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      snap.connectionState == ConnectionState.waiting ? 'Loading…' : 'No history in Home Assistant yet',
                      style: Txt.muted(15),
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
                  '${units.dist(d.distanceKm)} ${units.distance} · ${(d.consumedWh / 1000).toStringAsFixed(1)} kWh',
                ),
              if (km > 0)
                Kv(
                  'Efficiency',
                  '${(wh / 10 / km * (units.miles ? 1.609344 : 1)).toStringAsFixed(1)} kWh/100 ${units.distance}',
                ),
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
                        Text(values[i].round().toString(), style: Txt.mono(12, weight: 400)),
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
                  style: Txt.mono(12, weight: 400),
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
    final units = AppScope.of(context).settings.units;
    return SubScreen(
      title: 'Health',
      children: [
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
            if (car.nextServiceKm != null)
              Kv('Next service (Bluelink)', 'at ${thousands(units.dist(car.nextServiceKm))} ${units.distance}'),
          ],
        ),
        _TireMap(warnings: car.tireWarnings),
      ],
    );
  }
}

/// The car from above with each tire's status just outside its wheel, as in
/// the mockup: labels at 21% (front) and 77% (rear) of the car's height, each
/// with a 12 px leader line.
class _TireMap extends StatelessWidget {
  const _TireMap({required this.warnings});
  final Map<String, bool> warnings;

  static const _frontAxle = .21, _rearAxle = .77;
  static const _height = 340.0, _lead = 12.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height,
    child: LayoutBuilder(
      builder: (context, box) {
        const carW = _height * TopCar.aspect;
        // TopCar centres its box, then nudges it right by 3.3%.
        final left = (box.maxWidth - carW) / 2 + carW * .033, right = left + carW;
        Widget badge(String k, double axle, bool onLeft) {
          final low = warnings[k] == true;
          final chip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Palette.raise,
              border: Border.all(color: low ? Palette.amber : Palette.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$k ${low ? 'low' : 'ok'}', style: Txt.mono(13, color: low ? Palette.amber : Palette.ok)),
          );
          final lead = Container(width: _lead, height: 1, color: Palette.line);
          return Positioned(
            top: _height * axle - 12,
            height: 24,
            right: onLeft ? box.maxWidth - left - _lead : null,
            left: onLeft ? null : right - _lead,
            child: Row(mainAxisSize: MainAxisSize.min, children: onLeft ? [chip, lead] : [lead, chip]),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(child: TopCar(height: _height)),
            badge('FL', _frontAxle, true),
            badge('FR', _frontAxle, false),
            badge('RL', _rearAxle, true),
            badge('RR', _rearAxle, false),
          ],
        );
      },
    ),
  );
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = AppScope.of(context).activity;
    return SubScreen(
      title: 'Activity',
      children: [
        if (items.isEmpty) Text('Nothing in the last two days.', style: Txt.muted(15)),
        for (final a in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Palette.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 64, child: Text(_when(a.time), style: Txt.mono(13, weight: 400))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: Txt.body(15)),
                      if (a.detail.isNotEmpty) Text(a.detail, style: Txt.muted(14)),
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
