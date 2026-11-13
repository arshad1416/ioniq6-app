import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/car/units.dart';

void main() {
  test('metric passes through', () {
    const u = Units();
    expect(u.dist(328), 328);
    expect(u.temp(21), '21°');
    expect(u.temp(21.5), '21.5°');
  });

  test('miles and Fahrenheit convert', () {
    const u = Units(miles: true, fahrenheit: true);
    expect(u.dist(328), 204);
    expect(u.distance, 'mi');
    expect(u.temp(21), '70°');
    expect(u.temp(null), '–');
  });
}
