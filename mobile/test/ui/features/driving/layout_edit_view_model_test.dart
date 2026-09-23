import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/ui/features/driving/view_models/layout_edit_view_model.dart';

const _a = CellRect(rowStart: 1, colStart: 1, rowSpan: 1, colSpan: 1);
const _b = CellRect(rowStart: 1, colStart: 3, rowSpan: 1, colSpan: 1);
const _free = CellRect(rowStart: 2, colStart: 2, rowSpan: 1, colSpan: 1);

DrivingLayout fixture() => const DrivingLayout(
  name: 'test',
  slots: [
    LayoutSlot(
      rect: _a,
      kind: SlotKind.button,
      control: ControlId.hazardLights,
    ),
    LayoutSlot(rect: _b, kind: SlotKind.button, control: ControlId.horn),
  ],
);

void main() {
  group('TASK-010 LayoutEditViewModel', () {
    test('beginEdit opens a session; cancelEdit discards work', () {
      final vm = LayoutEditViewModel(initialLayout: fixture());
      addTearDown(vm.dispose);

      expect(vm.editing, isFalse);
      vm.beginEdit();
      expect(vm.editing, isTrue);

      vm.move(_a, _free);
      expect(vm.workingLayout.slots[0].rect, _free);

      vm.cancelEdit();
      expect(vm.editing, isFalse);
      expect(vm.workingLayout.slots[0].rect, _a);
    });

    test('move/add/remove delegate to the primitives', () {
      final vm = LayoutEditViewModel(initialLayout: fixture());
      addTearDown(vm.dispose);
      vm.beginEdit();

      vm.move(_a, _free);
      expect(vm.lastRefusal, isNull);
      expect(vm.workingLayout.slots[0].rect, _free);

      vm.move(_free, _b);
      expect(vm.lastRefusal, EditRefusal.targetOccupied);
      expect(vm.workingLayout.slots[0].rect, _free);

      vm.addControl(_a, ControlId.wipers);
      expect(vm.lastRefusal, isNull);
      expect(vm.workingLayout.slots.length, 3);

      vm.remove(_a);
      expect(vm.lastRefusal, isNull);
      expect(vm.workingLayout.slots.length, 2);
    });

    test('select is ignored outside a session', () {
      final vm = LayoutEditViewModel(initialLayout: fixture());
      addTearDown(vm.dispose);

      vm.select(_a);
      expect(vm.selected, isNull);

      vm.beginEdit();
      vm.select(_a);
      expect(vm.selected, _a);
    });

    test('saveAs rejects blank names and stores the snapshot', () {
      final vm = LayoutEditViewModel(initialLayout: fixture());
      addTearDown(vm.dispose);
      vm.beginEdit();
      vm.move(_a, _free);

      expect(vm.saveAs('  '), isFalse);
      expect(vm.savedProfiles, isEmpty);

      expect(vm.saveAs('Mine'), isTrue);
      expect(vm.savedProfiles['Mine']!.slots[0].rect, _free);
    });

    test('freeSpansFor follows the working layout', () {
      final vm = LayoutEditViewModel(initialLayout: fixture());
      addTearDown(vm.dispose);
      vm.beginEdit();

      expect(vm.freeSpansFor(1, 1).contains(_a), isFalse);
      vm.remove(_a);
      expect(vm.freeSpansFor(1, 1).contains(_a), isTrue);
    });
  });
}
