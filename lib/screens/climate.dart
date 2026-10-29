import 'package:flutter/material.dart';

import '../car/commands.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hold_button.dart';
import '../widgets/rive_view.dart';

class ClimateScreen extends StatelessWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final car = store.car;
    final req = store.settings.climate;
    final on = car.climateOn;
    final cabin = car.cabinTempC;
    final heating = req.tempC >= (cabin ?? 15);
    final progress = cabin == null || !on ? 0.0 : (1 - ((req.tempC - cabin).abs() / 12)).clamp(0.0, 1.0);

    return SubScreen(
      title: 'Climate',
      scroll: false,
      children: [
        Expanded(
          child: _Cabin(
            req: req,
            rive: RiveView(
              asset: 'assets/rive/ioniq6_climate.riv',
              values: {'on': on, 'mode': heating ? 1 : 0, 'progress': progress},
              fallback: const SizedBox.shrink(),
            ),
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
                Text(
                  cabin == null ? 'Cabin temperature not reported' : 'Inside ${store.settings.units.temp(cabin)}',
                  style: Txt.muted(11),
                ),
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
                              child: Icon(Icons.power_settings_new, size: 28, color: on ? Palette.red : Palette.light),
                            ),
                            Text(
                              store.pending is StartClimateCommand || store.pending is StopClimateCommand
                                  ? 'Sending'
                                  : on
                                  ? 'On'
                                  : 'Off',
                              style: Txt.muted(11),
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
                            Icon(Icons.trip_origin, size: 28, color: req.wheel ? Palette.red : Palette.light),
                            const SizedBox(height: 6),
                            Text('Wheel', style: Txt.muted(11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Wide(
                  icon: (color) => CustomPaint(size: const Size.square(26), painter: _DefrostIcon(color)),
                  label: 'Defrost car',
                  on: req.defrost,
                  onTap: () => store.updateClimate(req.copyWith(defrost: !req.defrost)),
                ),
                const SizedBox(height: 10),
                Text(
                  on
                      ? 'Hold the power button to stop.'
                      : 'Hold the power button to start. Runs ${req.minutes} min with these settings.',
                  style: Txt.muted(11),
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

class _Wide extends StatelessWidget {
  const _Wide({required this.icon, required this.label, required this.on, required this.onTap});
  final Widget Function(Color color) icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: on ? Palette.red : const Color(0xFF3A3A3C)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          icon(on ? Palette.red : Palette.light),
          const SizedBox(width: 14),
          Text(label, style: Txt.body(14)),
        ],
      ),
    ),
  );
}

/// The cabin from above. The front seats sit under a smoked-glass pane, like
/// the panoramic roof, and a heated seat glows red beneath it.
class _Cabin extends StatelessWidget {
  const _Cabin({required this.req, required this.rive, required this.onDriver, required this.onPassenger});
  final ClimateRequest req;
  final Widget rive;
  final VoidCallback onDriver, onPassenger;

  // Measured on top_v.webp (237×560) as fractions of the image.
  static const _aspect = 237 / 560;
  static const _seatY = .553, _driverX = .292, _passengerX = .708;
  static const _glass = Rect.fromLTRB(.15, .466, .85, .632);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Same maths as BoxFit.contain, so the overlays land on the seats.
      final h = box.maxHeight.clamp(0.0, box.maxWidth / _aspect);
      final img = Rect.fromCenter(center: box.biggest.center(Offset.zero), width: h * _aspect, height: h);
      Offset at(double x, double y) => Offset(img.left + img.width * x, img.top + img.height * y);
      final glass = Rect.fromPoints(at(_glass.left, _glass.top), at(_glass.right, _glass.bottom));

      Widget seat(SeatLevel level, VoidCallback onTap, double x, String label) {
        final c = at(x, _seatY);
        final heated = level != SeatLevel.off;
        return Positioned(
          left: c.dx - 30,
          top: c.dy - 30,
          width: 60,
          height: 60,
          child: Semantics(
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
                            Palette.red.withValues(alpha: .25 + .15 * level.index),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Icon(Icons.waves, size: 24, color: heated ? Palette.red : const Color(0xFF9A9A9E)),
                  Positioned(
                    bottom: 8,
                    child: Text(level.badge, style: Txt.mono(9, weight: 600, color: Palette.red)),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Stack(
        children: [
          Positioned.fromRect(
            rect: img,
            child: Hero(
              tag: 'car',
              child: Image.asset('assets/images/top_v.webp', fit: BoxFit.fill, semanticLabel: 'Cabin from above'),
            ),
          ),
          seat(req.driverSeat, onDriver, _driverX, 'Driver'),
          seat(req.passengerSeat, onPassenger, _passengerX, 'Passenger'),
          // Smoked glass with a light sheen, over the seats but not their taps.
          Positioned.fromRect(
            rect: glass,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      const Color(0xFF0B0B0C).withValues(alpha: .35),
                      const Color(0xFF0B0B0C).withValues(alpha: .45),
                      Colors.white.withValues(alpha: .06),
                    ],
                    stops: const [0, .35, .8, 1],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(child: SizedBox.square(dimension: 160, child: rive)),
          ),
        ],
      );
    },
  );
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
