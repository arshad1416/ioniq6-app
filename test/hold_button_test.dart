import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/widgets/hold_button.dart';

void main() {
  testWidgets('dragging out of a hold control cancels it', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: HoldButton(
      onHeld: () => calls++, builder: (_, _) => const SizedBox(width: 100, height: 100, child: Text('Hold')),
    )))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Hold')));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    expect(calls, 0);
  });
  testWidgets('disabling a control during a hold cancels it', (tester) async {
    var calls = 0;
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (_, setState) {
      update = setState;
      return Center(child: HoldButton(enabled: enabled, onHeld: () => calls++,
        builder: (_, _) => const SizedBox(width: 100, height: 100, child: Text('Hold'))));
    }))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Hold')));
    await tester.pump(const Duration(milliseconds: 400));
    update(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    expect(calls, 0);
  });
}
