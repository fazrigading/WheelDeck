import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/input/pedal_input.dart';
import 'package:wheeldeck/ui/pedals/pedal_panel.dart';

void main() {
  testWidgets('drags down to increase pressure and releases on drag end',
      (tester) async {
    final pressures = <double>[];
    var released = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
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
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PedalBar));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(pressures, isNotEmpty);
    expect(pressures.last, closeTo(1.0, 0.1));
    expect(released, isTrue);
  });

  testWidgets('drags up to lower pressure toward rest', (tester) async {
    final pressures = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 300,
              width: 80,
              child: PedalBar(
                pedal: PedalType.brake,
                label: 'BRK',
                pressure: 1.0,
                onDrag: (_, pressure) => pressures.add(pressure),
                onRelease: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PedalBar));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, -150));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(pressures, isNotEmpty);
    expect(pressures.last, closeTo(0.0, 0.1));
  });

  testWidgets('renders three pedals and wires drag to PedalInput',
      (tester) async {
    final input = PedalInput();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: PedalPanel(input: input),
          ),
        ),
      ),
    );

    expect(find.byType(PedalBar), findsNWidgets(3));

    final accBar = find.byKey(const ValueKey('pedal-accelerator'));
    final center = tester.getCenter(accBar);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    input.dispose();

    expect(input.pressureOf(PedalType.accelerator), greaterThan(0.0));
  });
}
