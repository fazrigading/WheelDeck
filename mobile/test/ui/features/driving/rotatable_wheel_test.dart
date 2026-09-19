import 'dart:math' as math;
import 'dart:ui' as ui;

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
    bool springBack = true,
    Duration springBackDuration = const Duration(milliseconds: 700),
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RotatableWheel(
            degrees: degrees,
            size: 300,
            springBack: springBack,
            springBackDuration: springBackDuration,
            onChanged: values.add,
          ),
        ),
      ),
    ),
  );

  String readout(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('rotation-readout')),
    );
    return text.data ?? '';
  }

  /// Drags the wheel clockwise a little and leaves the gesture open.
  Future<TestGesture> dragClockwise(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(RotatableWheel));
    final gesture = await tester.startGesture(center + const Offset(100, 0));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-12, 18));
      await tester.pump();
    }
    return gesture;
  }

  testWidgets('clockwise drag steers right and release springs to zero', (
    tester,
  ) async {
    final values = <double>[];
    await pumpWheel(tester, values);

    final gesture = await dragClockwise(tester);

    expect(values, isNotEmpty);
    expect(values.every((v) => v >= -1.0 && v <= 1.0), isTrue);
    expect(values.last, greaterThan(0.0));
    expect(readout(tester) == '0°', isFalse);

    await gesture.up();
    await tester.pump();

    // The zero report lands when the eased animation completes, not on
    // release.
    expect(values.last, isNot(0.0));

    await tester.pumpAndSettle();

    expect(values.last, 0.0);
    expect(readout(tester), '0°');
  });

  testWidgets('spring-back off holds the released angle', (tester) async {
    final values = <double>[];
    await pumpWheel(tester, values, springBack: false);

    final gesture = await dragClockwise(tester);
    final held = values.last;
    expect(held, greaterThan(0.0));

    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();

    // Steering stays where the driver left it, reported on release.
    expect(values.last, held);
    expect(readout(tester), isNot('0°'));
  });

  testWidgets('a new drag cancels an in-flight spring-back', (tester) async {
    final values = <double>[];
    await pumpWheel(
      tester,
      values,
      springBackDuration: const Duration(seconds: 10),
    );

    var gesture = await dragClockwise(tester);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    // Mid spring-back: easing toward zero but not there yet.
    final midFlight = readout(tester);
    expect(midFlight, isNot('0°'));

    // The new drag takes over from the current angle and the old animation
    // never completes.
    gesture = await dragClockwise(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(readout(tester), isNot('0°'));
    expect(values.contains(0.0), isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(values.last, 0.0);
  });

  testWidgets('the spring-back controller never outlives the widget', (
    tester,
  ) async {
    final values = <double>[];
    await pumpWheel(
      tester,
      values,
      springBackDuration: const Duration(seconds: 10),
    );

    final gesture = await dragClockwise(tester);
    await gesture.up();
    await tester.pump();

    // Disposing mid-animation must not throw a ticker/controller error.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    expect(values.last, 0.0);
  });

  testWidgets('steering and pedals work concurrently (multi-touch)', (
    tester,
  ) async {
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
    final wheelGesture = await tester.startGesture(
      wheelCenter + const Offset(70, 0),
    );
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
    await tester.pumpAndSettle();

    expect(wheelValues, isNotEmpty);
    expect(wheelValues.last, 0.0);
    expect(pressures, isNotEmpty);
    expect(released, isTrue);
  });

  group('rotation arc', () {
    /// Paints the arc painter at [steering] and scans the rendered pixels.
    ///
    /// Returns (red pixels right of center, red pixels left of center); the
    /// fill color is the wheel's red, the track is gray.
    Future<(int, int)> fillPixels(double steering) async {
      const size = Size(200, 200);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      RotationArcPainter(steering: steering).paint(canvas, size);
      final image = await recorder.endRecording().toImage(200, 200);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();

      var right = 0;
      var left = 0;
      final bytes = data!.buffer.asUint8List();
      // A band around the vertical center excludes the start cap's bleed:
      // the fill starts at twelve o'clock, on the center line.
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          final i = (y * 200 + x) * 4;
          // The red fill, allowing for antialiasing.
          if (bytes[i] > 180 && bytes[i + 1] < 100 && bytes[i + 2] < 100) {
            if (x < 90) {
              left++;
            } else if (x > 110) {
              right++;
            }
          }
        }
      }
      return (right, left);
    }

    test('nothing paints at zero steering', () async {
      final (right, left) = await fillPixels(0.0);
      expect(right, 0);
      expect(left, 0);
    });

    test('full-right steering fills only the top-right quarter', () async {
      final (right, left) = await fillPixels(1.0);
      expect(right, greaterThan(0));
      expect(left, 0);
    });

    test('full-left steering fills only the top-left quarter', () async {
      final (right, left) = await fillPixels(-1.0);
      expect(left, greaterThan(0));
      expect(right, 0);
    });
  });
}
