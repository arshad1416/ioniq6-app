import 'package:flutter/material.dart';

import '../theme.dart';

/// The front of the car with half a sun (red) and half a snowflake, from the
/// mockup's 24×24 line icon. Takes its colour and size from the [IconTheme],
/// like [Icon], so it drops in wherever an icon goes.
class ClimateIcon extends StatelessWidget {
  const ClimateIcon({super.key, this.size, this.color});
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(painter: _ClimatePainter(color ?? theme.color ?? Palette.ink)),
    );
  }
}

class _ClimatePainter extends CustomPainter {
  _ClimatePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    Paint pen(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void lines(Path p, List<double> xy) {
      for (var i = 0; i < xy.length; i += 4) {
        p
          ..moveTo(xy[i], xy[i + 1])
          ..lineTo(xy[i + 2], xy[i + 3]);
      }
    }

    final body = Path()
      ..moveTo(3.5, 19)
      ..lineTo(3.5, 13.3)
      ..cubicTo(3.5, 11.8, 4.3, 10.7, 5.5, 10.1)
      ..lineTo(7.4, 6.5)
      ..cubicTo(7.8, 5.7, 8.4, 5.3, 9.3, 5.3)
      ..lineTo(14.7, 5.3)
      ..cubicTo(15.6, 5.3, 16.2, 5.7, 16.6, 6.5)
      ..lineTo(18.5, 10.1)
      ..cubicTo(19.7, 10.7, 20.5, 11.8, 20.5, 13.3)
      ..lineTo(20.5, 19)
      ..close();
    // Wheels and mirrors.
    body
      ..moveTo(3.5, 19)
      ..lineTo(3.5, 20.6)
      ..lineTo(6.3, 20.6)
      ..lineTo(6.3, 19)
      ..moveTo(17.7, 19)
      ..lineTo(17.7, 20.6)
      ..lineTo(20.5, 20.6)
      ..lineTo(20.5, 19);
    lines(body, [5.5, 10.1, 3.8, 10.1, 18.5, 10.1, 20.2, 10.1]);
    canvas.drawPath(body, pen(color, 1.6));

    final snow = Path();
    lines(snow, [
      12, 9.6, 12, 17.4, //
      12, 13.5, 15.3, 11.6,
      12, 13.5, 15.3, 15.4,
      14.1, 12.3, 15.1, 12.7,
      14.1, 12.3, 14.3, 11.2,
      14.1, 14.7, 14.3, 15.8,
      14.1, 14.7, 15.1, 14.3,
    ]);
    canvas.drawPath(snow, pen(color, 1.15));

    final sun = Path()..addArc(Rect.fromCircle(center: const Offset(12, 13.5), radius: 1.6), -1.5708, -3.1416);
    lines(sun, [9.6, 13.5, 8.3, 13.5, 10.3, 11.8, 9.4, 10.9, 10.3, 15.2, 9.4, 16.1]);
    canvas.drawPath(sun, pen(Palette.red, 1.15));
  }

  @override
  bool shouldRepaint(_ClimatePainter old) => old.color != color;
}
