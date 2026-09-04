import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/ui/wheel/wheel_view.dart';

void main() {
  testWidgets('maps a normalized angle to wheel rotation in turns', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WheelView(angle: 1.0, maxWheelRotation: math.pi / 2)),
      ),
    );

    final rotation = tester.widget<AnimatedRotation>(
      find.byType(AnimatedRotation),
    );
    expect(rotation.turns, closeTo(0.25, 0.0001));
  });

  testWidgets('zero angle keeps the wheel centered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WheelView(angle: 0.0)),
      ),
    );

    final rotation = tester.widget<AnimatedRotation>(
      find.byType(AnimatedRotation),
    );
    expect(rotation.turns, 0.0);
  });

  testWidgets('clamps out-of-range angles to full lock', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WheelView(angle: -2.5, maxWheelRotation: math.pi / 2)),
      ),
    );

    final rotation = tester.widget<AnimatedRotation>(
      find.byType(AnimatedRotation),
    );
    expect(rotation.turns, closeTo(-0.25, 0.0001));
  });
}
