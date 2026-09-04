import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/input/steering_sensor.dart';
import 'package:wheeldeck/ui/wheel/calibration_view.dart';

class _CountingSensor extends SteeringSensor {
  _CountingSensor() : super(rawAngleStream: const Stream.empty());

  int centerCalls = 0;

  @override
  void setCenter() {
    centerCalls++;
    super.setCenter();
  }
}

void main() {
  late _CountingSensor sensor;

  setUp(() {
    sensor = _CountingSensor();
  });

  testWidgets('tapping the button calls setCenter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CalibrationView(sensor: sensor))),
    );

    await tester.tap(find.text('Set straight ahead'));
    await tester.pump();

    expect(sensor.centerCalls, 1);
  });

  testWidgets('shows the current steering angle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationView(sensor: sensor, angle: 0.42),
        ),
      ),
    );

    expect(find.textContaining('0.42'), findsOneWidget);
  });
}
