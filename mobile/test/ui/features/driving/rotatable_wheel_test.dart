import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';
import 'package:wheeldeck/ui/features/driving/views/pedal_panel.dart';
import 'package:wheeldeck/ui/features/driving/views/rotatable_wheel.dart';

void main() {
  Future<void> pumpWheel(
    WidgetTester tester,
    List<double> values, {
    int degrees = 900,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RotatableWheel(
                degrees: degrees,
                size: 300,
                onChanged: values.add,
              ),
            ),
          ),
        ),
      );

  String readout(WidgetTester tester) {
    final text = tester.widget<Text>(find.byKey(const ValueKey(
      'rotation-readout',
    )));
    return text.data ?? '';
  }

  testWidgets('clockwise drag steers right and release springs to zero',
      (tester) async {
    final values = <double>[];
    await pumpWheel(tester, values);

    final center = tester.getCenter(find.byType(RotatableWheel));
    final gesture = await tester.startGesture(center + const Offset(100, 0));
    // Arc east -> south-east -> south (clockwise on screen).
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-12, 18));
      await tester.pump();
    }

    expect(values, isNotEmpty);
    expect(values.every((v) => v >= -1.0 && v <= 1.0), isTrue);
    expect(values.last, greaterThan(0.0));
    expect(readout(tester) == '0°', isFalse);

    await gesture.up();
    await tester.pump();

    expect(values.last, 0.0);
    expect(readout(tester), '0°');
  });

  testWidgets('accumulation clamps at half-range (full lock)', (tester) async {
    final values = <double>[];
    await pumpWheel(tester, values, degrees: 180);

    Offset circlePoint(double tDeg) {
      final t = tDeg * math.pi / 180;
      return Offset(100 * math.cos(t), 100 * math.sin(t));
    }

    final center = tester.getCenter(find.byType(RotatableWheel));
    final gesture = await tester.startGesture(center + circlePoint(0));
    // A 150-degree clockwise arc: past half of the 180 range, so steering
    // and readout must clamp at full lock instead of overshooting.
    var prev = circlePoint(0);
    for (var t = 15; t <= 150; t += 15) {
      final p = circlePoint(t.toDouble());
      await gesture.moveBy(p - prev);
      await tester.pump();
      prev = p;
    }

    expect(values.last, 1.0);
    expect(readout(tester), '90°');

    await gesture.up();
    await tester.pump();
    expect(values.last, 0.0);
  });

  testWidgets('counter-clockwise drag steers left', (tester) async {
    final values = <double>[];
    await pumpWheel(tester, values);

    final center = tester.getCenter(find.byType(RotatableWheel));
    final gesture = await tester.startGesture(center + const Offset(100, 0));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-12, -18));
      await tester.pump();
    }

    expect(values, isNotEmpty);
    expect(values.last, lessThan(0.0));

    await gesture.up();
    await tester.pump();
    expect(values.last, 0.0);
  });

  testWidgets('steering and pedals work concurrently (multi-touch)',
      (tester) async {
    final wheelValues = <double>[];
    final pressures = <double>[];
    var released = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotatableWheel(
                  degrees: 900,
                  size: 200,
                  onChanged: wheelValues.add,
                ),
                SizedBox(
                  height: 300,
                  width: 80,
                  child: PedalBar(
                    pedal: PedalType.accelerator,
                    label: 'ACC',
                    pressure: 0.0,
                    onDrag: (_, pressure) => pressures.add(pressure),
                    onRelease: (_) => released = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final wheelCenter = tester.getCenter(find.byType(RotatableWheel));
    final wheelGesture =
        await tester.startGesture(wheelCenter + const Offset(70, 0));
    for (var i = 0; i < 4; i++) {
      await wheelGesture.moveBy(const Offset(-10, 15));
      await tester.pump();
    }

    final pedalCenter = tester.getCenter(find.byType(PedalBar));
    final pedalGesture = await tester.startGesture(pedalCenter);
    await pedalGesture.moveBy(const Offset(0, 100));
    await tester.pump();

    await pedalGesture.up();
    await wheelGesture.up();
    await tester.pump();

    expect(wheelValues, isNotEmpty);
    expect(wheelValues.last, 0.0);
    expect(pressures, isNotEmpty);
    expect(released, isTrue);
  });
}
