import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/dashboard_send_gate.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';
import 'package:wheeldeck/ui/features/driving/views/block_grid.dart';
import 'package:wheeldeck/ui/features/driving/views/dashboard_panel.dart';
import 'package:wheeldeck/ui/features/driving/views/pedal_panel.dart';
import 'package:wheeldeck/ui/features/driving/views/rotatable_wheel.dart';

/// Reference resolution from the plan: cell = 160x135, block = 800x540.
const Size reference = Size(2400, 1080);

void main() {
  late DashboardInput input;
  late List<(ControlId, ActionType)> events;
  late Map<ControlId, String> bindings;
  late List<double> steering;

  setUp(() {
    input = DashboardInput();
    events = [];
    input.onControlActivated(
      (control, action) => events.add((control, action)),
    );
    bindings = {for (final c in ControlId.values) c: 'K'};
    steering = [];
  });

  Future<void> pumpGrid(
    WidgetTester tester, {
    DashboardSendGate? gate,
    Set<PedalType> shownPedals = const {
      PedalType.clutch,
      PedalType.brake,
      PedalType.accelerator,
    },
  }) async {
    tester.view.physicalSize = reference;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlockGrid(
            layout: DrivingLayout.sequential(),
            input: input,
            bindingFor: (control) => bindings[control] ?? '-',
            gate: gate,
            pedalInput: PedalInput(),
            shownPedals: shownPedals,
            degrees: 270,
            onSteering: steering.add,
          ),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

  testWidgets('renders the sequential preset through the grid renderer', (
    tester,
  ) async {
    await pumpGrid(tester);

    final layout = DrivingLayout.sequential();
    final cellCount = layout.slots
        .where(
          (s) =>
              s.kind == SlotKind.button ||
              s.kind == SlotKind.gearUp ||
              s.kind == SlotKind.gearDown ||
              s.kind == SlotKind.hole,
        )
        .length;

    expect(find.byType(DashboardControl), findsNWidgets(cellCount));
    expect(find.byType(RotatableWheel), findsOneWidget);
    expect(find.byType(PedalBar), findsNWidgets(3));
    // Signals are ordinary grid entries with their straight arrows.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dashboard-turnSignalLeft')),
        matching: find.byIcon(Icons.arrow_back),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wheel box is square at the block height, centered, flush '
      'bottom', (tester) async {
    await pumpGrid(tester);

    // Wheel slot: global rows 5-8, cols 1-4 -> 640x540 at the reference.
    const slot = Rect.fromLTWH(0, 540, 640, 540);
    final rect = rectOf(tester, const ValueKey('wheel-slot'));

    expect(rect.size, const Size(540, 540));
    // Horizontally centered with equal 50px margins.
    expect(rect.left - slot.left, slot.right - rect.right);
    // Flush with the slot's bottom edge.
    expect(rect.bottom, slot.bottom);
  });

  testWidgets('pedals fill their slots with the inset, accelerator '
      'right-most', (tester) async {
    await pumpGrid(tester);

    // Brake slot: global cols 12-13; accelerator: cols 14-15; rows 5-8.
    final brake = rectOf(tester, const ValueKey('pedal-brake'));
    final accelerator = rectOf(tester, const ValueKey('pedal-accelerator'));

    // Exactly half the screen height, flush bottom.
    expect(brake.height, 540);
    expect(brake.bottom, 1080);
    expect(accelerator.height, 540);
    expect(accelerator.bottom, 1080);

    // The 8px inset lives inside each bar, between adjacent slots.
    expect(brake.left, 11 * 160 + 8);
    expect(brake.right, 13 * 160 - 8);
    expect(accelerator.left, 13 * 160 + 8);
    expect(accelerator.right, 15 * 160 - 8);

    // Accelerator is right-most.
    expect(accelerator.right, greaterThan(brake.right));
  });

  testWidgets('holes render disabled, matching the unbound visual', (
    tester,
  ) async {
    bindings[ControlId.horn] = '-';
    await pumpGrid(tester);

    // A hole cell (block A, row 2 col 1) and the unbound horn control.
    final hole = tester.widget<DashboardControl>(
      find.byKey(const ValueKey('hole-r2c1')),
    );
    final horn = tester.widget<DashboardControl>(
      find.byKey(const ValueKey('dashboard-horn')),
    );

    expect(hole.enabled, isFalse);
    expect(horn.enabled, isFalse);

    Color cellColor(Key key) =>
        ((tester.widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(key),
                    matching: find.byType(AnimatedContainer),
                  ),
                )).decoration
                as BoxDecoration)
            .color!;
    expect(
      cellColor(const ValueKey('hole-r2c1')),
      cellColor(const ValueKey('dashboard-horn')),
    );

    // Tapping a hole sends nothing and opens no binder.
    await tester.tap(find.byKey(const ValueKey('hole-r2c1')));
    await tester.pump();
    expect(events, isEmpty);
  });

  testWidgets('buttons size to their cells', (tester) async {
    await pumpGrid(tester);

    Size cellSize(Key key) => (tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedContainer),
      ),
    )).constraints!.biggest;

    // A 1x1 cell is 160x135 at the reference resolution.
    expect(cellSize(const ValueKey('dashboard-wipers')), const Size(160, 135));
    // The gear cell spans 2x2 cells: 320x270.
    expect(cellSize(const ValueKey('dashboard-gearUp')), const Size(320, 270));
  });

  testWidgets('wheel drag reports steering through onSteering', (tester) async {
    await pumpGrid(tester);

    final center = tester.getCenter(find.byType(RotatableWheel));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(steering, isNotEmpty);
    // Release always reports the spring-back to zero.
    expect(steering.last, 0.0);
  });
}
