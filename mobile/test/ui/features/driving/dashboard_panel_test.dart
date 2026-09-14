import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/dashboard_send_gate.dart';
import 'package:wheeldeck/data/services/dashboard_visibility.dart';
import 'package:wheeldeck/data/services/engine_start_mode.dart';
import 'package:wheeldeck/ui/features/driving/views/dashboard_panel.dart';

void main() {
  late DashboardInput input;
  late List<(ControlId, ActionType)> events;
  late Map<ControlId, String> bindings;

  setUp(() {
    input = DashboardInput();
    events = [];
    input.onControlActivated(
        (control, action) => events.add((control, action)));
    bindings = {for (final c in ControlId.values) c: 'K'};
  });

  DashboardSendGate buildGate(List<(ControlId, ActionType)> sent) {
    final gate = DashboardSendGate(
      send: (control, action) => sent.add((control, action)),
      bindingFor: (control) => bindings[control] ?? '-',
      autoBlink: false,
    );
    addTearDown(gate.dispose);
    return gate;
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    DashboardSendGate? gate,
    Set<ControlId> visibleExtras = DashboardVisibility.defaults,
    Set<ControlId> excluded = const {},
    EngineStartMode engineStartMode = EngineStartMode.holdConfirm,
    ValueChanged<ControlId>? onBindRequested,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPanel(
              input: input,
              bindingFor: (control) => bindings[control] ?? '-',
              gate: gate,
              visibleExtras: visibleExtras,
              excluded: excluded,
              engineStartMode: engineStartMode,
              onBindRequested: onBindRequested,
            ),
          ),
        ),
      );

  testWidgets('grid never shows left/right signals', (tester) async {
    await pumpPanel(tester);

    expect(find.byKey(const ValueKey('dashboard-turnSignalLeft')),
        findsNothing);
    expect(find.byKey(const ValueKey('dashboard-turnSignalRight')),
        findsNothing);
  });

  testWidgets('grid shows core plus visible extras', (tester) async {
    await pumpPanel(tester);

    // 14 core + 3 default extras (gears, engine brake).
    expect(find.byType(DashboardControl), findsNWidgets(17));
    expect(
        find.byKey(const ValueKey('dashboard-hazardLights')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-gearUp')), findsOneWidget);
  });

  testWidgets('hidden extras and excluded controls are skipped', (tester) async {
    await pumpPanel(
      tester,
      visibleExtras: const {},
      excluded: const {ControlId.gearUp, ControlId.gearDown},
    );

    expect(find.byType(DashboardControl),
        findsNWidgets(DashboardPanel.coreControls.length));
    expect(find.byKey(const ValueKey('dashboard-gearUp')), findsNothing);
  });

  testWidgets('tapping a toggle control emits a toggle action', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(const ValueKey('dashboard-hazardLights')));
    await tester.pump();

    expect(events, [(ControlId.hazardLights, ActionType.toggle)]);
  });

  testWidgets('holding a momentary control emits press then release',
      (tester) async {
    await pumpPanel(tester);

    final control = find.byKey(const ValueKey('dashboard-wipers'));
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(events.first, (ControlId.wipers, ActionType.press));
    expect(events.last, (ControlId.wipers, ActionType.release));
  });

  testWidgets('holding an engine start emits hold_confirm', (tester) async {
    await pumpPanel(tester);

    final control = find.byKey(const ValueKey('dashboard-engineStart'));
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(events, contains((ControlId.engineStart, ActionType.holdConfirm)));
  });

  testWidgets('single-press engine start emits press then release',
      (tester) async {
    await pumpPanel(tester,
        engineStartMode: EngineStartMode.singlePress);

    final control = find.byKey(const ValueKey('dashboard-engineStart'));
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(events.first, (ControlId.engineStart, ActionType.press));
    expect(events.last, (ControlId.engineStart, ActionType.release));
    expect(
      events.where((e) => e.$2 == ActionType.holdConfirm),
      isEmpty,
    );
  });

  testWidgets('unbound control is disabled and opens the binder',
      (tester) async {
    final bound = <ControlId>[];
    bindings[ControlId.horn] = '-';
    await pumpPanel(tester,
        onBindRequested: (control) => bound.add(control));

    await tester.tap(find.byKey(const ValueKey('dashboard-horn')));
    await tester.pump();

    expect(events, isEmpty);
    expect(bound, [ControlId.horn]);
    // Disabled "—" affordance badge.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dashboard-horn')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hazard blinks with the gate phase', (tester) async {
    final sent = <(ControlId, ActionType)>[];
    final gate = buildGate(sent);
    await pumpPanel(tester, gate: gate);

    Color hazardColor() => ((tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey('dashboard-hazardLights')),
            matching: find.byType(AnimatedContainer),
          ),
        )).decoration as BoxDecoration)
            .color!;

    expect(hazardColor(), isNot(const Color(0xFFFFB300)));

    gate.handle(ControlId.hazardLights, ActionType.toggle);
    await tester.pump();
    expect(hazardColor(), const Color(0xFFFFB300));

    gate.advanceBlink();
    await tester.pump();
    expect(hazardColor(), isNot(const Color(0xFFFFB300)));
  });

  testWidgets('headlight button shows the cycle stage', (tester) async {
    final sent = <(ControlId, ActionType)>[];
    final gate = buildGate(sent);
    await pumpPanel(tester, gate: gate);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dashboard-headlightToggle')),
        matching: find.text('OFF'),
      ),
      findsOneWidget,
    );

    gate.handle(ControlId.headlightToggle, ActionType.toggle);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dashboard-headlightToggle')),
        matching: find.text('PARK'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('controls render at 64px', (tester) async {
    await pumpPanel(tester);

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('dashboard-wipers')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(container.constraints,
        BoxConstraints.tight(const Size(64, 64)));
  });

  testWidgets('small phones fall back to rounded rectangles', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPanel(tester);

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('dashboard-wipers')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });
}
