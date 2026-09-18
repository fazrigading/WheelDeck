import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/dashboard_send_gate.dart';

void main() {
  late List<(ControlId, ActionType)> sent;
  late Map<ControlId, String> bindings;

  DashboardSendGate buildGate() {
    sent = [];
    return DashboardSendGate(
      send: (control, action) => sent.add((control, action)),
      bindingFor: (control) => bindings[control] ?? '-',
      autoBlink: false,
    );
  }

  setUp(() {
    bindings = {for (final c in ControlId.values) c: 'K'};
  });

  group('send gate', () {
    test('bound control sends through', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.horn, ActionType.press);

      expect(sent, [(ControlId.horn, ActionType.press)]);
    });

    test('empty binding sends nothing', () {
      final gate = buildGate();
      addTearDown(gate.dispose);
      bindings[ControlId.horn] = '';

      gate.handle(ControlId.horn, ActionType.press);

      expect(sent, isEmpty);
    });

    test('dash binding sends nothing', () {
      final gate = buildGate();
      addTearDown(gate.dispose);
      bindings[ControlId.audioNext] = '-';

      gate.handle(ControlId.audioNext, ActionType.press);
      gate.handle(ControlId.audioNext, ActionType.release);

      expect(sent, isEmpty);
    });
  });

  group('light cycle', () {
    test('cycles parking -> lowbeam -> off with toggle pulses', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      gate.handle(ControlId.headlightToggle, ActionType.toggle);

      expect(sent, [
        (ControlId.lightsParking, ActionType.toggle),
        (ControlId.lightsLowbeam, ActionType.toggle),
        (ControlId.lightsOff, ActionType.toggle),
      ]);
    });

    test('wraps back to parking and tracks stage', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      expect(gate.lightStage, LightStage.off);
      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      expect(gate.lightStage, LightStage.parking);
      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      expect(gate.lightStage, LightStage.low);
      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      expect(gate.lightStage, LightStage.off);
      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      expect(sent.last.$1, ControlId.lightsParking);
    });

    test('unbound cycle step still advances state but sends nothing', () {
      final gate = buildGate();
      addTearDown(gate.dispose);
      bindings[ControlId.lightsParking] = '-';

      gate.handle(ControlId.headlightToggle, ActionType.toggle);

      expect(sent, isEmpty);
      expect(gate.lightStage, LightStage.parking);
    });

    test('high-beam stays independent of the cycle', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.headlightToggle, ActionType.toggle);
      gate.handle(ControlId.highBeamToggle, ActionType.toggle);

      expect(sent.last, (ControlId.highBeamToggle, ActionType.toggle));
      expect(gate.lightStage, LightStage.parking);
    });
  });

  group('signals and hazard', () {
    test('individual toggle sends and holds state', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.turnSignalLeft, ActionType.toggle);

      expect(sent, [(ControlId.turnSignalLeft, ActionType.toggle)]);
      expect(gate.leftOn, isTrue);
      expect(gate.rightOn, isFalse);
    });

    test('signals send and hold their own state during hazard', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.hazardLights, ActionType.toggle);
      expect(sent, [(ControlId.hazardLights, ActionType.toggle)]);
      expect(gate.hazardOn, isTrue);

      gate.handle(ControlId.turnSignalLeft, ActionType.toggle);
      expect(sent, hasLength(2));
      expect(sent.last, (ControlId.turnSignalLeft, ActionType.toggle));
      expect(gate.leftOn, isTrue);
      expect(gate.hazardOn, isTrue);

      // Both cells light on the shared phase while their states are held.
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isTrue);
      expect(gate.signalVisualActive(ControlId.hazardLights), isTrue);

      // Exclusion applies during hazard too: right replaces left silently.
      gate.handle(ControlId.turnSignalRight, ActionType.toggle);
      expect(sent, hasLength(3));
      expect(sent.last, (ControlId.turnSignalRight, ActionType.toggle));
      expect(gate.rightOn, isTrue);
      expect(gate.leftOn, isFalse);
      expect(gate.hazardOn, isTrue);

      gate.handle(ControlId.turnSignalRight, ActionType.toggle);
      expect(sent, hasLength(4));
      expect(gate.rightOn, isFalse);
      expect(gate.hazardOn, isTrue);

      // Left survives hazard clearing and blinks its own state afterward.
      gate.handle(ControlId.turnSignalLeft, ActionType.toggle);
      expect(sent, hasLength(5));
      expect(gate.leftOn, isTrue);

      gate.handle(ControlId.hazardLights, ActionType.toggle);
      expect(sent, hasLength(6));
      expect(gate.hazardOn, isFalse);
      expect(gate.leftOn, isTrue);
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isTrue);
      expect(gate.signalVisualActive(ControlId.hazardLights), isFalse);
      gate.advanceBlink();
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isFalse);
      gate.advanceBlink();
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isTrue);
    });

    test('turning one signal on clears the other without sending it', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.turnSignalLeft, ActionType.toggle);
      expect(gate.leftOn, isTrue);

      gate.handle(ControlId.turnSignalRight, ActionType.toggle);
      expect(sent, hasLength(2));
      expect(sent.last, (ControlId.turnSignalRight, ActionType.toggle));
      expect(gate.rightOn, isTrue);
      expect(gate.leftOn, isFalse);
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isFalse);

      gate.handle(ControlId.turnSignalLeft, ActionType.toggle);
      expect(sent, hasLength(3));
      expect(sent.last, (ControlId.turnSignalLeft, ActionType.toggle));
      expect(gate.leftOn, isTrue);
      expect(gate.rightOn, isFalse);
      expect(gate.signalVisualActive(ControlId.turnSignalRight), isFalse);
    });

    test('hazard drives both visuals, individuals drive their own', () {
      final gate = buildGate();
      addTearDown(gate.dispose);

      gate.handle(ControlId.turnSignalLeft, ActionType.toggle);
      // Lit immediately on activation, no dark first phase.
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isTrue);
      expect(gate.signalVisualActive(ControlId.turnSignalRight), isFalse);

      gate.handle(ControlId.hazardLights, ActionType.toggle);
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isTrue);
      expect(gate.signalVisualActive(ControlId.turnSignalRight), isTrue);

      gate.advanceBlink();
      expect(gate.signalVisualActive(ControlId.turnSignalLeft), isFalse);
      expect(gate.signalVisualActive(ControlId.turnSignalRight), isFalse);
      expect(gate.signalVisualActive(ControlId.hazardLights), isFalse);
    });

    test('blink defaults to ~1.5Hz phase', () {
      expect(DashboardSendGate.blinkFrequencyHz, 1.5);
      expect(DashboardSendGate.defaultBlinkPhase.inMilliseconds, 333);
    });
  });
}
