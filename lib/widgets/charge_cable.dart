import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Arshad's car with the charging connector seated in its port when plugged
/// in. The cable runs from the end of the grip down to the ground, and a red
/// pulse travels along it toward the car while charging.
class ChargingCar extends StatefulWidget {
  const ChargingCar({super.key, required this.plugged, required this.charging});
  final bool plugged, charging;

  // car.webp is 1047×404 and shows the right side, where the Ioniq 6 has its
  // port: the round flap on the rear quarter panel.
  static const _aspect = 1047 / 404;
  static const _port = Offset(.059, .426);

  @override
  State<ChargingCar> createState() => _ChargingCarState();
}

class _ChargingCarState extends State<ChargingCar> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ChargingCar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.charging && widget.plugged) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Leave room on the left for the cable to hang, then fit the photo.
      final gutter = box.maxWidth * .1;
      final w = math.min(box.maxWidth - gutter, box.maxHeight * ChargingCar._aspect);
      final img = Rect.fromLTWH(
        box.maxWidth - w,
        (box.maxHeight - w / ChargingCar._aspect) / 2,
        w,
        w / ChargingCar._aspect,
      );
      final port = Offset(img.left + img.width * ChargingCar._port.dx, img.top + img.height * ChargingCar._port.dy);
      return Stack(
        children: [
          Positioned.fromRect(
            rect: img,
            child: Image.asset('assets/images/car.webp', fit: BoxFit.fill, semanticLabel: 'Your Ioniq 6'),
          ),
          if (widget.plugged)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (context, _) => CustomPaint(
                    painter: _CablePainter(
                      port: port,
                      ground: box.maxHeight,
                      scale: img.height / 180,
                      flow: widget.charging ? _flow.value : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CablePainter extends CustomPainter {
  _CablePainter({required this.port, required this.ground, required this.scale, this.flow});
  final Offset port;
  final double ground, scale;

  /// 0–1 phase of the charging pulse, or null when plugged in but idle.
  final double? flow;

  // The connector leaves the port pointing out and down, 30° below horizontal.
  static const _angle = math.pi - math.pi / 6;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;
    final dir = Offset(math.cos(_angle), math.sin(-_angle).abs());
    final nozzleEnd = port + dir * (10 * s);
    final gripEnd = nozzleEnd + dir * (22 * s);

    // Cable: from the end of the grip, sagging to the ground and off the left edge.
    final cable = Path()
      ..moveTo(gripEnd.dx, gripEnd.dy)
      ..cubicTo(
        gripEnd.dx - 14 * s,
        gripEnd.dy + 30 * s,
        gripEnd.dx - 4 * s,
        ground - 6 * s,
        gripEnd.dx - 40 * s,
        ground - 4 * s,
      )
      ..lineTo(-10, ground - 2 * s);
    canvas.drawPath(
      cable,
      Paint()
        ..color = const Color(0xFF2A2A2D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * s
        ..strokeCap = StrokeCap.round,
    );
    if (flow != null) _drawPulse(canvas, cable, s);

    // Connector: a short nozzle in the port, then a thicker grip.
    canvas.save();
    canvas.translate(port.dx, port.dy);
    canvas.rotate(math.atan2(dir.dy, dir.dx));
    final body = Paint()..color = const Color(0xFF3A3A3D);
    canvas.drawRRect(RRect.fromLTRBR(-2 * s, -3.2 * s, 11 * s, 3.2 * s, Radius.circular(1.5 * s)), body);
    canvas.drawRRect(
      RRect.fromLTRBR(10 * s, -4.6 * s, 32 * s, 4.6 * s, Radius.circular(3 * s)),
      Paint()..color = const Color(0xFF1E1E21),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(10 * s, -4.6 * s, 32 * s, 4.6 * s, Radius.circular(3 * s)),
      Paint()
        ..color = const Color(0xFF4A4A4E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8 * s,
    );
    // Status light on the grip: steady red when plugged, brighter while charging.
    final lit = flow == null ? .55 : .75 + .25 * math.sin(flow! * 2 * math.pi);
    canvas.drawCircle(
      Offset(15 * s, -1.8 * s),
      2.6 * s,
      Paint()
        ..color = Palette.red.withValues(alpha: .35 * lit)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );
    canvas.drawCircle(Offset(15 * s, -1.8 * s), 1.2 * s, Paint()..color = Palette.red.withValues(alpha: lit));
    canvas.restore();
  }

  void _drawPulse(Canvas canvas, Path cable, double s) {
    final metric = cable.computeMetrics().first;
    final len = metric.length;
    final paint = Paint()
      ..color = Palette.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    // Three short dashes moving from the ground end toward the car.
    for (var i = 0; i < 3; i++) {
      final t = 1 - ((flow! + i / 3) % 1);
      final start = (t * len).clamp(0.0, len);
      final end = (start + 10 * s).clamp(0.0, len);
      canvas.drawPath(metric.extractPath(start, end), paint..color = Palette.red.withValues(alpha: .4 + .6 * (1 - t)));
    }
  }

  @override
  bool shouldRepaint(_CablePainter old) =>
      old.flow != flow || old.port != port || old.scale != scale || old.ground != ground;
}
