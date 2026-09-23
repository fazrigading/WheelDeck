import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';

const _buttonA = CellRect(
  rowStart: 1,
  colStart: 1,
  rowSpan: 1,
  colSpan: 1,
);
const _buttonB = CellRect(
  rowStart: 1,
  colStart: 3,
  rowSpan: 1,
  colSpan: 2,
);
const _pedal = CellRect(
  rowStart: 5,
  colStart: 12,
  rowSpan: 4,
  colSpan: 2,
);
const _wheel = CellRect(
  rowStart: 5,
  colStart: 6,
  rowSpan: 2,
  colSpan: 2,
);

DrivingLayout testLayout() => const DrivingLayout(
  name: 'test',
  slots: [
    LayoutSlot(
      rect: _buttonA,
      kind: SlotKind.button,
      control: ControlId.hazardLights,
    ),
    LayoutSlot(
      rect: _buttonB,
      kind: SlotKind.button,
      control: ControlId.horn,
    ),
    LayoutSlot(
      rect: _pedal,
      kind: SlotKind.pedal,
      pedal: PedalType.brake,
    ),
    LayoutSlot(rect: _wheel, kind: SlotKind.wheel),
  ],
);

DrivingLayout applied(LayoutEditResult result) {
  expect(result, isA<EditApplied>());
  return (result as EditApplied).layout;
}

EditRefusal refused(LayoutEditResult result) {
  expect(result, isA<EditRefused>());
  return (result as EditRefused).reason;
}

void main() {
  group('TASK-006 value semantics', () {
    test('CellRect has value equality and copyWith', () {
      const a = CellRect(
        rowStart: 1,
        colStart: 2,
        rowSpan: 3,
        colSpan: 4,
      );
      expect(
        a,
        const CellRect(
          rowStart: 1,
          colStart: 2,
          rowSpan: 3,
          colSpan: 4,
        ),
      );
      expect(
        a.copyWith(colStart: 5),
        const CellRect(
          rowStart: 1,
          colStart: 5,
          rowSpan: 3,
          colSpan: 4,
        ),
      );
    });

    test('LayoutSlot has value equality and copyWith', () {
      const a = LayoutSlot(
        rect: _buttonA,
        kind: SlotKind.button,
        control: ControlId.horn,
      );
      expect(
        a,
        const LayoutSlot(
          rect: _buttonA,
          kind: SlotKind.button,
          control: ControlId.horn,
        ),
      );
      expect(a.copyWith(rect: _buttonB).rect, _buttonB);
      expect(a.copyWith(rect: _buttonB).control, ControlId.horn);
    });
  });

  group('TASK-007 applyMove', () {
    test('move into a free span succeeds without mutating the input', () {
      const to = CellRect(
        rowStart: 2,
        colStart: 1,
        rowSpan: 1,
        colSpan: 1,
      );
      final before = testLayout();
      final after = applied(applyMove(before, _buttonA, to));

      expect(after.slots[0].rect, to);
      expect(after.slots[0].control, ControlId.hazardLights);
      expect(after.slots[1].rect, _buttonB);
      expect(before.slots[0].rect, _buttonA);
    });

    test('move onto an occupied span is refused and pushes nothing', () {
      final before = testLayout();
      const to = CellRect(
        rowStart: 1,
        colStart: 4,
        rowSpan: 1,
        colSpan: 1,
      );
      expect(applyMove(before, _buttonA, to), isA<EditRefused>());
      expect(
        refused(applyMove(before, _buttonA, to)),
        EditRefusal.targetOccupied,
      );
      expect(before.slots[0].rect, _buttonA);
      expect(before.slots[1].rect, _buttonB);
    });

    test('move from an empty span reports slotNotFound', () {
      const from = CellRect(
        rowStart: 8,
        colStart: 15,
        rowSpan: 1,
        colSpan: 1,
      );
      const to = CellRect(
        rowStart: 8,
        colStart: 14,
        rowSpan: 1,
        colSpan: 1,
      );
      expect(
        refused(applyMove(testLayout(), from, to)),
        EditRefusal.slotNotFound,
      );
    });

    test('move outside the grid reports outOfBounds', () {
      const to = CellRect(
        rowStart: 9,
        colStart: 1,
        rowSpan: 1,
        colSpan: 1,
      );
      expect(
        refused(applyMove(testLayout(), _buttonA, to)),
        EditRefusal.outOfBounds,
      );
    });

    test('move onto its own span succeeds unchanged', () {
      final after = applied(applyMove(testLayout(), _buttonA, _buttonA));
      expect(after.slots.map((slot) => slot.rect), [
        _buttonA,
        _buttonB,
        _pedal,
        _wheel,
      ]);
    });
  });

  group('TASK-008 addControl and removeSlot', () {
    test('add fills empty cells', () {
      const at = CellRect(
        rowStart: 2,
        colStart: 2,
        rowSpan: 1,
        colSpan: 1,
      );
      final after = applied(
        addControl(testLayout(), at, ControlId.wipers),
      );
      final added = after.slots.last;
      expect(added.rect, at);
      expect(added.control, ControlId.wipers);
      expect(after.slots.length, testLayout().slots.length + 1);
    });

    test('add onto an occupied span is refused', () {
      const at = CellRect(
        rowStart: 1,
        colStart: 3,
        rowSpan: 1,
        colSpan: 1,
      );
      expect(
        refused(addControl(testLayout(), at, ControlId.wipers)),
        EditRefusal.targetOccupied,
      );
    });

    test('remove returns cells to empty', () {
      final after = applied(removeSlot(testLayout(), _buttonB));
      expect(
        after.slots.where((slot) => slot.rect == _buttonB),
        isEmpty,
      );
      expect(after.slots.length, testLayout().slots.length - 1);
    });

    test('remove from an empty span reports slotNotFound', () {
      const at = CellRect(
        rowStart: 8,
        colStart: 15,
        rowSpan: 1,
        colSpan: 1,
      );
      expect(
        refused(removeSlot(testLayout(), at)),
        EditRefusal.slotNotFound,
      );
    });

    test('remove of a pedal or wheel slot is refused', () {
      expect(
        refused(removeSlot(testLayout(), _pedal)),
        EditRefusal.structuralSlot,
      );
      expect(
        refused(removeSlot(testLayout(), _wheel)),
        EditRefusal.structuralSlot,
      );
    });
  });

  group('TASK-009 freeSpans', () {
    test('returns free cells and excludes occupied ones', () {
      final free = freeSpans(testLayout(), 1, 1);
      expect(
        free.contains(
          const CellRect(
            rowStart: 2,
            colStart: 2,
            rowSpan: 1,
            colSpan: 1,
          ),
        ),
        isTrue,
      );
      expect(free.contains(_buttonA), isFalse);
      expect(
        free.contains(
          const CellRect(
            rowStart: 1,
            colStart: 3,
            rowSpan: 1,
            colSpan: 1,
          ),
        ),
        isFalse,
      );
    });

    test('a fully tiled layout has no free spans', () {
      expect(freeSpans(DrivingLayout.sequential(), 1, 1), isEmpty);
    });

    test('an empty layout fits a 1x1 span in every cell', () {
      const empty = DrivingLayout(name: 'empty', slots: []);
      expect(freeSpans(empty, 1, 1).length, 8 * 15);
    });
  });

  group('TASK-027 through TASK-029 modules', () {
    test('audio player places as one unit with offset slots', () {
      const empty = DrivingLayout(name: 'empty', slots: []);
      const at = CellRect(
        rowStart: 2,
        colStart: 3,
        rowSpan: 1,
        colSpan: 5,
      );
      final after = applied(
        placeModule(empty, at, LayoutModule.audioPlayer),
      );

      expect(after.slots.length, 5);
      expect(after.slots[0].control, ControlId.audioVolumeDown);
      expect(
        after.slots[0].rect,
        const CellRect(rowStart: 2, colStart: 3, rowSpan: 1, colSpan: 1),
      );
      expect(after.slots[4].control, ControlId.audioVolumeUp);
      expect(
        after.slots[4].rect,
        const CellRect(rowStart: 2, colStart: 7, rowSpan: 1, colSpan: 1),
      );
    });

    test('module placement refuses overlap and out-of-bounds spans', () {
      const overlapping = CellRect(
        rowStart: 1,
        colStart: 1,
        rowSpan: 1,
        colSpan: 5,
      );
      expect(
        refused(
          placeModule(testLayout(), overlapping, LayoutModule.audioPlayer),
        ),
        EditRefusal.targetOccupied,
      );
      const offGrid = CellRect(
        rowStart: 4,
        colStart: 12,
        rowSpan: 1,
        colSpan: 5,
      );
      expect(
        refused(placeModule(testLayout(), offGrid, LayoutModule.audioPlayer)),
        EditRefusal.outOfBounds,
      );
    });

    test('h-shifter ships as sixteen holes', () {
      final module = LayoutModule.hShifter;
      expect(module.rowSpan, 4);
      expect(module.colSpan, 4);
      expect(module.slots.length, 16);
      expect(
        module.slots.every((slot) => slot.kind == SlotKind.hole),
        isTrue,
      );
    });
  });
}
