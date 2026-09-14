import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/dashboard_send_gate.dart';
import 'package:wheeldeck/ui/features/driving/views/signal_arrows.dart';
import 'package:wheeldeck/ui/features/driving/views/tilt_readout.dart';

DashboardSendGate buildGate(
  List<(ControlId, ActionType)> sent,
  Map<ControlId, String> bindings,
) =>
    DashboardSendGate(
      send: (control, action) => sent.add((control, action)),
      bindingFor: (control) => bindings[control] ?? 'K',
      autoBlink: false,
    );

void main() {
  testWidgets('arrows emit left/right toggles', (tester) async {
    final input = DashboardInput();
    final events = <(ControlId, ActionType)>[];
    input.onControlActivated(
        (control, action) => events.add((control, action)));
    final sent = <(ControlId, ActionType)>[];
    final gate = buildGate(sent, {for (final c in ControlId.values) c: 'K'});
    addTearDown(gate.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SignalArrows(input: input, gate: gate))),
    );

    await tester.tap(find.byKey(const ValueKey('signal-left')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('signal-right')));
    await tester.pump();

    expect(events, [
      (ControlId.turnSignalLeft, ActionType.toggle),
      (ControlId.turnSignalRight, ActionType.toggle),
    ]);
  });

  testWidgets('active arrow lights with the blink phase', (tester) async {
    final input = DashboardInput();
    input.onControlActivated((control, action) {});
    final sent = <(ControlId, ActionType)>[];
    final gate = buildGate(sent, {for (final c in ControlId.values) c: 'K'});
    addTearDown(gate.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SignalArrows(input: input, gate: gate))),
    );

    Color colorOf(String key) {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (container.decoration as BoxDecoration).color!;
    }

    // Idle: both dim.
    expect(colorOf('signal-left'), isNot(const Color(0xFFFFB300)));

    input.activate(ControlId.turnSignalLeft, ActionType.toggle);
    gate.handle(ControlId.turnSignalLeft, ActionType.toggle);
    await tester.pump();
    // Lit immediately on activation.
    expect(colorOf('signal-left'), const Color(0xFFFFB300));
    expect(colorOf('signal-right'), isNot(const Color(0xFFFFB300)));

    gate.advanceBlink();
    await tester.pump();
    expect(colorOf('signal-left'), isNot(const Color(0xFFFFB300)));
  });

  testWidgets('hazard lights both arrows', (tester) async {
    final input = DashboardInput();
    input.onControlActivated((control, action) {});
    final sent = <(ControlId, ActionType)>[];
    final gate = buildGate(sent, {for (final c in ControlId.values) c: 'K'});
    addTearDown(gate.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SignalArrows(input: input, gate: gate))),
    );

    Color colorOf(String key) => ((tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(AnimatedContainer),
          ),
        )).decoration as BoxDecoration)
            .color!;

    gate.handle(ControlId.hazardLights, ActionType.toggle);
    await tester.pump();
    expect(colorOf('signal-left'), const Color(0xFFFFB300));
    expect(colorOf('signal-right'), const Color(0xFFFFB300));
  });

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
