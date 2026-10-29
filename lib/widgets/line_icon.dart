import 'package:flutter/material.dart';

import '../theme.dart';

/// A 24×24 line icon drawn from the mockup's own SVG path data, so the app's
/// icons are the mockup's icons. Colour and size come from the [IconTheme],
/// like [Icon].
class LineIcon extends StatelessWidget {
  const LineIcon(this.glyph, {super.key, this.size, this.color, this.stroke = 1.6});
  final LineGlyph glyph;
  final double? size;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return SizedBox.square(
      dimension: size ?? theme.size ?? 24,
      child: CustomPaint(painter: _LinePainter(glyph, color ?? theme.color ?? Palette.ink, stroke)),
    );
  }
}

/// SVG path data (`d`) plus any circles, in a 24×24 box.
class LineGlyph {
  const LineGlyph(this.d, {this.circles = const []});
  final String d;

  /// (cx, cy, r) for each circle.
  final List<(double, double, double)> circles;

  static final _cache = <String, Path>{};
  Path get path => _cache.putIfAbsent(d, () => parseSvgPath(d));
}

/// The mockup's icons (index.html), by what they show.
abstract final class Glyphs {
  static const car = LineGlyph(
    'M3 16v-3l2-5h14l2 5v3zM3 16v2h3v-2M18 16v2h3v-2',
    circles: [(7.5, 13, 1), (16.5, 13, 1)],
  );
  static const bolt = LineGlyph('M13 2L4 14h7l-1 8 9-12h-7z');
  static const stats = LineGlyph('M4 20V10M10 20V4M16 20v-7M22 20H2');
  static const heart = LineGlyph(
    'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z',
  );
  static const activity = LineGlyph('M3 12h4l3 8 4-16 3 8h4');
  static const camera = LineGlyph('M3 8h3l2-3h8l2 3h3v11H3z', circles: [(12, 13, 3.5)]);
  static const calendar = LineGlyph('M3 5h18v16H3zM3 10h18M8 3v4M16 3v4');
  static const lock = LineGlyph('M5 11h14v10H5zM8 11V8a4 4 0 0 1 8 0v3');
  static const lockOpen = LineGlyph('M5 11h14v10H5zM8 11V8a4 4 0 0 1 7.5-2');
  static const flash = LineGlyph('M14 6a6 6 0 0 1 0 12zM14 6v12M3 8h7M3 12h7M3 16h7');
  static const honk = LineGlyph('M3 10v4h3l9 5V5L6 10zM18 9a4 4 0 0 1 0 6');
  static const pin = LineGlyph('M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z', circles: [(12, 10, 2.5)]);
  static const valet = LineGlyph('M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM5 21l2-6h10l2 6M10 15l2 3 2-3');
  static const gear = LineGlyph(
    'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z',
    circles: [(12, 12, 3)],
  );
  static const power = LineGlyph('M12 3v8M6.3 7.5a8 8 0 1 0 11.4 0');
  static const wheel = LineGlyph('M4 12h6M14 12h6M12 14v6', circles: [(12, 12, 8), (12, 12, 2)]);
  static const person = LineGlyph('M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0');
  static const key = LineGlyph('M15 9a4 4 0 1 1-1.2-2.8M13.8 6.2 21 13.4V17h-3v-2h-2v-2h-2');
  static const walk = LineGlyph('M13 4a1.5 1.5 0 1 0 0-.01M10 21l2-6 3 3v3M8 12l2-4 4 1 2 3h3M12 15l-2-4');
  static const brush = LineGlyph('M4 15l9-9 5 5-9 9H4zM14 5l2-2 5 5-2 2');
  static const ruler = LineGlyph('M3 17 17 3l4 4L7 21zM7 13l2 2M10 10l2 2M13 7l2 2');
  static const thermometer = LineGlyph('M14 14.8V4a2 2 0 0 0-4 0v10.8a4 4 0 1 0 4 0z');
  static const globe = LineGlyph(
    'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18',
  );
  static const house = LineGlyph('M3 11 12 3l9 8v10H3zM9 21v-6h6v6');
  static const password = LineGlyph('M4 7h16v10H4zM8 12h.01M12 12h.01M16 12h.01');
  static const phone = LineGlyph('M7 3h10v18H7zM11 18h2');
  static const help = LineGlyph(
    'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.7M12 17h.01',
  );
  static const warning = LineGlyph('M12 3 2 20h20zM12 9v5M12 17h.01');
  static const tow = LineGlyph('M3 17h2l2-5h10l2 5h2M7 17a2 2 0 1 0 4 0M13 17a2 2 0 1 0 4 0M12 5v4');
  static const pinFilled = LineGlyph(
    'M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  );
  static const lines = LineGlyph('M3 7h18M3 12h18M3 17h12');
  static const mail = LineGlyph('M4 6h16v12H4zM4 8l8 5 8-5');
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.glyph, this.color, this.stroke);
  final LineGlyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(glyph.path, pen);
    for (final (x, y, r) in glyph.circles) {
      canvas.drawCircle(Offset(x, y), r, pen);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.glyph != glyph || old.color != color || old.stroke != stroke;
}

/// Parses the SVG path commands the mockup uses: M L H V C S A Z, absolute
/// and relative.
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?').allMatches(d).map((m) => m[0]!);
  final it = tokens.iterator;
  final path = Path();
  var cur = Offset.zero, start = Offset.zero, lastCtrl = Offset.zero;
  String? cmd;
  String? pending;

  bool next() {
    if (pending != null) return true;
    if (!it.moveNext()) return false;
    pending = it.current;
    return true;
  }

  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double num() {
    next();
    final v = double.parse(pending!);
    pending = null;
    return v;
  }

  // Flags in arcs can be written without separators ("0 0 0" or "001").
  bool flag() {
    next();
    final t = pending!;
    if (t.length > 1 && (t[0] == '0' || t[0] == '1') && !t.startsWith('0.')) {
      pending = t.substring(1);
      return t[0] == '1';
    }
    pending = null;
    return t == '1';
  }

  while (next()) {
    if (isCmd(pending!)) {
      cmd = pending;
      pending = null;
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        cur = start;
        continue;
      }
    }
    final rel = cmd!.toLowerCase() == cmd;
    final base = rel ? cur : Offset.zero;
    switch (cmd.toUpperCase()) {
      case 'M':
        cur = base + Offset(num(), num());
        start = cur;
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L';
      case 'L':
        cur = base + Offset(num(), num());
        path.lineTo(cur.dx, cur.dy);
      case 'H':
        cur = Offset((rel ? cur.dx : 0) + num(), cur.dy);
        path.lineTo(cur.dx, cur.dy);
      case 'V':
        cur = Offset(cur.dx, (rel ? cur.dy : 0) + num());
        path.lineTo(cur.dx, cur.dy);
      case 'C':
        final c1 = base + Offset(num(), num()), c2 = base + Offset(num(), num()), end = base + Offset(num(), num());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastCtrl = c2;
        cur = end;
      case 'S':
        final c1 = cur * 2 - lastCtrl, c2 = base + Offset(num(), num()), end = base + Offset(num(), num());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastCtrl = c2;
        cur = end;
      case 'A':
        final rx = num(), ry = num(), rot = num();
        final large = flag(), sweep = flag();
        final end = base + Offset(num(), num());
        path.arcToPoint(end, radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
        cur = end;
    }
    if (cmd.toUpperCase() != 'C' && cmd.toUpperCase() != 'S') lastCtrl = cur;
  }
  return path;
}
