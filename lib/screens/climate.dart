import 'package:flutter/material.dart';

import '../car/commands.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/line_icon.dart';
import '../widgets/top_car.dart';

class ClimateScreen extends StatelessWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final req = store.settings.climate;
    final on = car.climateOn;
    final cabin = car.cabinTempC;

    return SubScreen(
      title: 'Climate',
      scroll: false,
      children: [
        Expanded(
          child: _Cabin(
            req: req,
            onDriver: () => store.updateClimate(req.copyWith(driverSeat: req.driverSeat.next)),
            onPassenger: () => store.updateClimate(req.copyWith(passengerSeat: req.passengerSeat.next)),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(color: Palette.raise, borderRadius: BorderRadius.circular(26)),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                _Temps(inside: cabin),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: HoldButton(
                        enabled: store.pending == null,
                        onHeld: () => runCommand(context, on ? const StopClimateCommand() : StartClimateCommand(req)),
                        builder: (context, p) => Column(
                          children: [
                            HoldRing(
                              progress: p,
                              size: 40,
                              child: LineIcon(
                                Glyphs.power,
                                size: 28,
                                stroke: 1.8,
                                color: on ? Palette.red : Palette.light,
                              ),
                            ),
                            Text(
                              store.pending is StartClimateCommand || store.pending is StopClimateCommand
                                  ? 'Sending'
                                  : on
                                  ? 'On'
                                  : 'Off',
                              style: Txt.muted(13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Cooler',
                              onPressed: req.tempC <= 16
                                  ? null
                                  : () => store.updateClimate(req.copyWith(tempC: req.tempC - .5)),
                              icon: const Icon(Icons.chevron_left, color: Palette.mute),
                            ),
                            Text(
                              store.settings.units.temp(req.tempC),
                              style: Txt.display(
                                52,
                                weight: 200,
                              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                            IconButton(
                              tooltip: 'Warmer',
                              onPressed: req.tempC >= 30
                                  ? null
                                  : () => store.updateClimate(req.copyWith(tempC: req.tempC + .5)),
                              icon: const Icon(Icons.chevron_right, color: Palette.mute),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: GestureDetector(
                        onTap: () => store.updateClimate(req.copyWith(wheel: !req.wheel)),
                        child: Column(
                          children: [
                            LineIcon(
                              Glyphs.wheel,
                              size: 28,
                              stroke: 1.8,
                              color: req.wheel ? Palette.red : Palette.light,
                            ),
                            const SizedBox(height: 6),
                            Text('Wheel', style: Txt.muted(13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                WideButton(
                  icon: (color) => CustomPaint(size: const Size.square(26), painter: _DefrostIcon(color)),
                  label: 'Defrost car',
                  on: req.defrost,
                  onTap: () => store.updateClimate(req.copyWith(defrost: !req.defrost)),
                ),
                const SizedBox(height: 10),
                Text(
                  on
                      ? 'Hold the power button to stop.'
                      : 'Hold the power button to start. Runs ${req.minutes} min, uses about 1%.',
                  style: Txt.muted(13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Inside X · Outside Y". Outside is the weather where the car is; when the car
/// hasn't shared a location it falls back to Home Assistant's weather, labelled
/// as home's unless the car is known to be at home.
class _Temps extends StatefulWidget {
  const _Temps({required this.inside});
  final double? inside;

  @override
  State<_Temps> createState() => _TempsState();
}

class _TempsState extends State<_Temps> {
  (double, double)? _asked;
  double? _atCar;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final at = store.isDemo ? null : car.location;
    if (at != null && at != _asked) {
      _asked = at;
      store.weather.tempC(at).then((t) {
        if (mounted && _asked == at) setState(() => _atCar = t);
      });
    }
    final units = store.settings.units;
    final home = car.homeWeatherC;
    return Text(
      [
        if (widget.inside != null) 'Inside ${units.temp(widget.inside)}',
        if (at != null && _atCar != null)
          'Outside ${units.temp(_atCar)}'
        else if (home != null)
          car.atHome || store.isDemo ? 'Outside ${units.temp(home)}' : 'At home ${units.temp(home)}',
      ].join(' · '),
      style: Txt.muted(13),
    );
  }
}

/// The car from above, as in the mockup: the front seats show through the
/// smoked panoramic roof, and a heated seat glows red beneath it.
class _Cabin extends StatelessWidget {
  const _Cabin({required this.req, required this.onDriver, required this.onPassenger});
  final ClimateRequest req;
  final VoidCallback onDriver, onPassenger;

  // Fractions of the overhead car's box, from the mockup.
  static const _driver = Offset(.335, .46), _passenger = Offset(.60, .46);
  static const _glass = Rect.fromLTWH(.22, .375, .495, .195);

  @override
  Widget build(BuildContext context) {
    CarSpot seat(SeatLevel level, VoidCallback onTap, Offset at, String label) {
      final heated = level != SeatLevel.off;
      return CarSpot(
        at,
        const Size.square(52),
        Semantics(
          label: '$label seat heat ${level.name}',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: heated ? 1 : 0,
                  duration: Motion.nav,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Palette.red.withValues(alpha: .25 + .1 * level.index),
                          Colors.transparent,
                        ],
                        stops: const [0, .7],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Opacity(
                  opacity: .8,
                  // Upright waves: the heated-seat symbol.
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Icon(Icons.waves, size: 24, color: heated ? Palette.red : const Color(0xFF9A9A9E)),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  child: Text(level.badge, style: Txt.mono(11, weight: 600, color: Palette.red)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) => Center(
        child: TopCar(
          height: box.maxHeight.clamp(0, 460).toDouble(),
          spots: [
            seat(req.driverSeat, onDriver, _driver, 'Driver'),
            seat(req.passengerSeat, onPassenger, _passenger, 'Passenger'),
            // Smoked glass with a sheen, over the seats but not their taps.
            CarSpot.area(
              _glass,
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: const Alignment(-.42, -1),
                      end: const Alignment(.42, 1),
                      colors: [
                        Colors.white.withValues(alpha: .13),
                        Colors.white.withValues(alpha: .02),
                        const Color(0xFF080A0E).withValues(alpha: .38),
                        Colors.white.withValues(alpha: .06),
                      ],
                      stops: const [0, .35, .6, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The standard defrost symbol: a window with three wavy arrows rising through it.
class _DefrostIcon extends CustomPainter {
  const _DefrostIcon(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(RRect.fromLTRBR(1.5 * u, 3 * u, 22.5 * u, 15.5 * u, Radius.circular(1.5 * u)), pen);
    for (final x in [7.0, 12.0, 17.0]) {
      final path = Path()
        ..moveTo(x * u, 22 * u)
        ..cubicTo((x - 1.8) * u, 19.5 * u, (x + 1.8) * u, 16.5 * u, x * u, 13.5 * u)
        ..cubicTo((x - 1.4) * u, 11.5 * u, (x + .8) * u, 9.5 * u, x * u, 7 * u);
      canvas.drawPath(path, pen);
      canvas.drawPath(
        Path()
          ..moveTo((x - 1.4) * u, 8.4 * u)
          ..lineTo(x * u, 6.6 * u)
          ..lineTo((x + 1.4) * u, 8.4 * u),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_DefrostIcon old) => old.color != color;
}
