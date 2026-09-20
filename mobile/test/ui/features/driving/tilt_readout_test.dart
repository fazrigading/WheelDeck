import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/ui/features/driving/views/tilt_readout.dart';

void main() {
  testWidgets('tilt readout mirrors the steering angle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TiltReadout(angle: -0.5)),
      ),
    );

    expect(find.byKey(const ValueKey('tilt-readout')), findsOneWidget);
    final align = tester.widget<Align>(find.byKey(const ValueKey('tilt-marker')));
    expect((align.alignment as Alignment).x, -0.5);
  });
}
