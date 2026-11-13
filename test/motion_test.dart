import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/motion.dart';

void main() {
  testWidgets('a rolling number shows both values mid-roll, then only the new one', (tester) async {
    Widget app(String v) => MaterialApp(home: RollingNumber(v, style: const TextStyle(fontSize: 30)));
    await tester.pumpWidget(app('328'));
    await tester.pumpWidget(app('327'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('328'), findsOneWidget);
    expect(find.text('327'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('328'), findsNothing);
    expect(find.text('327'), findsOneWidget);
  });

  testWidgets('staggered items end fully visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StaggerIn(index: 3, child: Text('row'))));
    await tester.pump(Motion.stagger * 3);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.ancestor(of: find.text('row'), matching: find.byType(Opacity))).opacity, 1);
  });
}
