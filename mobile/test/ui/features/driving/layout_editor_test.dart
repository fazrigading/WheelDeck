import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';
import 'package:wheeldeck/ui/features/driving/view_models/layout_edit_view_model.dart';
import 'package:wheeldeck/ui/features/driving/views/layout_editor.dart';

/// Reference resolution from the grid tests: cell = 160x135.
const Size reference = Size(2400, 1080);
const _hornAt = CellRect(
  rowStart: 1,
  colStart: 1,
  rowSpan: 1,
  colSpan: 1,
);

void main() {
  late DashboardInput input;
  late List<(ControlId, ActionType)> events;
  late Map<ControlId, String> bindings;
  late LayoutEditViewModel edit;

  setUp(() {
    input = DashboardInput();
    events = [];
    input.onControlActivated(
      (control, action) => events.add((control, action)),
    );
    bindings = {for (final c in ControlId.values) c: 'K'};
    edit = LayoutEditViewModel(
      initialLayout: const DrivingLayout(
        name: 'Edit fixture',
        slots: [
          LayoutSlot(
            rect: _hornAt,
            kind: SlotKind.button,
            control: ControlId.horn,
          ),
          LayoutSlot(
            rect: CellRect(rowStart: 1, colStart: 3, rowSpan: 1, colSpan: 1),
            kind: SlotKind.button,
            control: ControlId.wipers,
          ),
        ],
      ),
    );
    edit.beginEdit();
    addTearDown(edit.dispose);
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = reference;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutEditor(
            edit: edit,
            input: input,
            bindingFor: (control) => bindings[control] ?? '-',
            pedalInput: PedalInput(),
            shownPedals: const {},
            degrees: 270,
            onSteering: (_) {},
            onCameraPadModeSwitch: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  CellRect hornRect() =>
      edit.workingLayout.slots
          .firstWhere((slot) => slot.control == ControlId.horn)
          .rect;

  testWidgets('TEST-001 drag into a free span moves the control', (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.drag(
      find.byKey(const ValueKey('dashboard-horn')),
      const Offset(0, 135),
    );
    await tester.pumpAndSettle();

    expect(
      hornRect(),
      const CellRect(rowStart: 2, colStart: 1, rowSpan: 1, colSpan: 1),
    );
    expect(edit.lastRefusal, isNull);
    expect(events, isEmpty);
  });

  testWidgets('TEST-002 drop on an occupied span flashes red, unchanged', (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.drag(
      find.byKey(const ValueKey('dashboard-horn')),
      const Offset(320, 0),
    );
    await tester.pump();

    expect(edit.lastRefusal, EditRefusal.targetOccupied);
    expect(hornRect(), _hornAt);
    expect(find.byKey(const ValueKey('refusal-flash')), findsOneWidget);

    // The flash clears on its timer; settle alone would not advance the
    // fake clock with no frames scheduled.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('refusal-flash')), findsNothing);
  });

  // TEST-003 (a control outside edit mode still sends its activation) is
  // covered in block_grid_test.dart: 'outside edit mode taps still send
  // control events'.
}
