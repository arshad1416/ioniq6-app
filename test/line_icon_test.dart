import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/widgets/line_icon.dart';

void main() {
  test('relative lines, H and V move from the current point', () {
    final b = parseSvgPath('M3 16v-3l2-5h14').getBounds();
    expect(b, const Rect.fromLTRB(3, 8, 19, 16));
  });

  test('arcs with packed numbers parse', () {
    final b = parseSvgPath('M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z').getBounds();
    expect(b.width, closeTo(8, .01));
    expect(b.height, closeTo(8, .01));
  });

  test('every mockup glyph stays inside its 24 box', () {
    for (final g in [Glyphs.car, Glyphs.gear, Glyphs.heart, Glyphs.globe, Glyphs.help, Glyphs.walk, Glyphs.tow]) {
      final b = g.path.getBounds();
      // getBounds counts curve control points, so allow a little overshoot.
      expect(b.left >= -2 && b.top >= -2 && b.right <= 26 && b.bottom <= 26, isTrue, reason: g.d);
    }
  });
}
