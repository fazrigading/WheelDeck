import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';

void main() {
  final layout = DrivingLayout.sequential();

  LayoutSlot slotCovering(int row, int col) =>
      layout.slots.firstWhere((slot) => slot.rect.contains(row, col));

  void expectTiles(Iterable<CellRect> rects) {
    final covered = <String>{};
    for (final rect in rects) {
      for (var row = rect.rowStart; row < rect.rowStart + rect.rowSpan; row++) {
        for (
          var col = rect.colStart;
          col < rect.colStart + rect.colSpan;
          col++
        ) {
          final key = '$row:$col';
          expect(covered.contains(key), isFalse, reason: 'overlap at $key');
          covered.add(key);
        }
      }
    }
    expect(covered.length, 8 * 15);
  }

  group('block grid', () {
    test('six blocks tile the 8x15 grid without overlap', () {
      expectTiles(DrivingLayout.blocks);
    });

    test('sequential slots tile the 8x15 grid without overlap', () {
      expectTiles(layout.slots.map((slot) => slot.rect));
    });
  });

  group('sequential preset', () {
    test('block A matches the researched table', () {
      expect(slotCovering(1, 1).control, ControlId.adaptiveCruise);
      expect(slotCovering(1, 2).control, ControlId.laneKeeping);
      expect(slotCovering(1, 3).control, ControlId.laneAssistant);
      expect(slotCovering(2, 1).control, ControlId.trailerAxle);
      expect(slotCovering(2, 2).control, ControlId.liftDropAxle);
      expect(slotCovering(2, 3).control, ControlId.trailer);
      expect(slotCovering(3, 1).control, ControlId.hazardLights);
      expect(slotCovering(3, 2).control, ControlId.beaconLights);
      expect(slotCovering(3, 3).control, ControlId.differentialLock);
      expect(slotCovering(4, 1).control, ControlId.turnSignalLeft);
      expect(slotCovering(4, 2).control, ControlId.turnSignalRight);
      expect(slotCovering(4, 3).control, ControlId.highBeamToggle);

      final clutch = slotCovering(1, 4);
      expect(clutch.kind, SlotKind.pedal);
      expect(clutch.pedal, PedalType.clutch);
      expect(clutch.control, isNull);
      expect(
        clutch.rect,
        const CellRect(rowStart: 1, colStart: 4, rowSpan: 4, colSpan: 2),
      );
    });

    test('block B matches the researched table', () {
      expect(slotCovering(1, 6).control, ControlId.audioVolumeDown);
      expect(slotCovering(1, 7).control, ControlId.audioPrevious);
      expect(slotCovering(1, 8).control, ControlId.audioPlayPause);
      expect(slotCovering(1, 9).control, ControlId.audioNext);
      expect(slotCovering(1, 10).control, ControlId.audioVolumeUp);

      expect(slotCovering(2, 6).control, ControlId.driverWindowUp);
      expect(slotCovering(2, 7).control, ControlId.navigationZoomIn);
      expect(slotCovering(2, 8).control, ControlId.cruiseSpeedIncrease);
      expect(slotCovering(2, 9).control, ControlId.retarderIncrease);
      expect(slotCovering(2, 10).control, ControlId.passengerWindowUp);

      expect(slotCovering(3, 6).control, ControlId.driverWindowDown);
      expect(slotCovering(3, 7).control, ControlId.navigationZoomOut);
      expect(slotCovering(3, 8).control, ControlId.cruiseSpeedDecrease);
      expect(slotCovering(3, 9).control, ControlId.retarderDecrease);
      expect(slotCovering(3, 10).control, ControlId.passengerWindowDown);

      expect(slotCovering(4, 6).control, ControlId.overlayActivation);
      expect(slotCovering(4, 7).control, ControlId.chatActivation);
      expect(slotCovering(4, 8).control, ControlId.quickReplies);
      expect(slotCovering(4, 9).control, ControlId.nameTags);
      expect(slotCovering(4, 10).control, ControlId.pushToTalk);
    });

    test('block C matches the researched table', () {
      final gearUp = slotCovering(1, 11);
      expect(gearUp.kind, SlotKind.gearUp);
      expect(gearUp.control, ControlId.gearUp);
      expect(
        gearUp.rect,
        const CellRect(rowStart: 1, colStart: 11, rowSpan: 2, colSpan: 2),
      );

      final cameraPad = slotCovering(1, 13);
      expect(cameraPad.kind, SlotKind.cameraPad);
      expect(cameraPad.control, isNull);
      expect(
        cameraPad.rect,
        const CellRect(rowStart: 1, colStart: 13, rowSpan: 3, colSpan: 3),
      );

      final gearDown = slotCovering(3, 11);
      expect(gearDown.kind, SlotKind.gearDown);
      expect(gearDown.control, ControlId.gearDown);
      expect(
        gearDown.rect,
        const CellRect(rowStart: 3, colStart: 11, rowSpan: 2, colSpan: 2),
      );

      expect(slotCovering(4, 13).control, ControlId.emergencyBrake);
      expect(slotCovering(4, 14).control, ControlId.engineBrake);
      expect(slotCovering(4, 15).control, ControlId.cruiseToggle);
    });

    test('block D matches the researched table', () {
      final wheel = slotCovering(5, 2);
      expect(wheel.kind, SlotKind.wheel);
      expect(wheel.control, isNull);
      expect(
        wheel.rect,
        const CellRect(rowStart: 5, colStart: 1, rowSpan: 4, colSpan: 4),
      );

      expect(slotCovering(5, 5).control, ControlId.horn);
      expect(slotCovering(6, 5).control, ControlId.flasher);
      expect(slotCovering(7, 5).control, ControlId.wipers);
      expect(slotCovering(8, 5).control, ControlId.headlightToggle);
    });

    test('block E matches the researched table', () {
      expect(slotCovering(5, 6).control, ControlId.cameraInterior);
      expect(slotCovering(5, 7).control, ControlId.cameraChasing);
      expect(slotCovering(5, 8).control, ControlId.cameraTopdown);
      expect(slotCovering(5, 9).control, ControlId.cameraRoof);
      expect(slotCovering(5, 10).control, ControlId.cameraLeanout);

      expect(slotCovering(6, 6).control, ControlId.quickSave);
      expect(slotCovering(6, 7).control, ControlId.dashboardInfo);
      expect(slotCovering(6, 8).control, ControlId.nextCamera);
      expect(slotCovering(6, 9).control, ControlId.hudWidgets);
      expect(slotCovering(6, 10).control, ControlId.cruiseSetResume);

      expect(slotCovering(7, 6).control, ControlId.quickInfo);
      expect(slotCovering(7, 7).control, ControlId.mirrorToggle);
      expect(slotCovering(7, 8).control, ControlId.screenshot);
      expect(slotCovering(7, 9).control, ControlId.widgetOptions);
      expect(slotCovering(7, 10).control, ControlId.services);

      expect(slotCovering(8, 6).control, ControlId.menu);
      expect(slotCovering(8, 7).control, ControlId.worldMap);
      expect(slotCovering(8, 8).control, ControlId.photoMode);
      expect(slotCovering(8, 9).control, ControlId.garageManager);
      expect(slotCovering(8, 10).control, ControlId.activate);
    });

    test('block F matches the researched table', () {
      expect(slotCovering(5, 11).control, ControlId.engineElectricity);
      expect(slotCovering(6, 11).control, ControlId.engineStart);
      expect(slotCovering(7, 11).control, ControlId.parkingBrake);
      expect(slotCovering(8, 11).control, ControlId.shiftToNeutral);

      final brake = slotCovering(5, 12);
      expect(brake.kind, SlotKind.pedal);
      expect(brake.pedal, PedalType.brake);
      expect(
        brake.rect,
        const CellRect(rowStart: 5, colStart: 12, rowSpan: 4, colSpan: 2),
      );
    });

    test('accelerator is the right-most pedal in block F', () {
      final brake = slotCovering(5, 12);
      final accelerator = slotCovering(5, 14);
      expect(accelerator.kind, SlotKind.pedal);
      expect(accelerator.pedal, PedalType.accelerator);
      expect(
        accelerator.rect,
        const CellRect(rowStart: 5, colStart: 14, rowSpan: 4, colSpan: 2),
      );
      expect(
        accelerator.rect.colStart,
        greaterThan(brake.rect.colStart + brake.rect.colSpan - 1),
      );
    });

    test(
      'wheel slot encodes the square centered flush-bottom box at 2400x1080',
      () {
        const cellWidth = 2400.0 / 15;
        const cellHeight = 1080.0 / 8;
        final wheel = slotCovering(5, 2);
        final slotWidth = wheel.rect.colSpan * cellWidth;
        final slotHeight = wheel.rect.rowSpan * cellHeight;

        // The slot is the full block-D height (4 rows) and 4 columns wide, so
        // the square box of side == block height fits centered with equal
        // margins and sits flush with the screen's bottom edge.
        expect(slotHeight, closeTo(540, 0.01));
        expect(slotWidth, closeTo(640, 0.01));
        expect(slotHeight, lessThanOrEqualTo(slotWidth));
        final diameter = slotHeight;
        final leftMargin = (slotWidth - diameter) / 2;
        final rightMargin = (slotWidth - diameter) / 2;
        expect(leftMargin, closeTo(50, 0.01));
        expect(rightMargin, closeTo(50, 0.01));
        expect(
          wheel.rect.rowStart + wheel.rect.rowSpan - 1,
          8,
          reason: 'wheel slot bottom is the grid bottom, so the box is flush',
        );
      },
    );

    test('slot kinds agree with their control and pedal fields', () {
      for (final slot in layout.slots) {
        switch (slot.kind) {
          case SlotKind.button || SlotKind.gearUp || SlotKind.gearDown:
            expect(
              slot.control,
              isNotNull,
              reason: '${slot.kind} at ${slot.rect} needs a control',
            );
          case SlotKind.hole ||
              SlotKind.pedal ||
              SlotKind.wheel ||
              SlotKind.cameraPad:
            expect(
              slot.control,
              isNull,
              reason: '${slot.kind} at ${slot.rect} carries no control',
            );
        }
        if (slot.kind != SlotKind.pedal) {
          expect(slot.pedal, isNull, reason: 'only pedals carry a pedal');
        }
      }
      // Every Sequential slot now binds a real control or structure; no
      // holes remain.
      expect(layout.slots.where((slot) => slot.kind == SlotKind.hole), isEmpty);
    });

    test('controlAt resolves the slot covering a probed cell', () {
      expect(
        layout.controlAt(
          const CellRect(rowStart: 4, colStart: 1, rowSpan: 1, colSpan: 1),
        ),
        ControlId.turnSignalLeft,
      );
      // Pedal slots carry no ControlId.
      expect(
        layout.controlAt(
          const CellRect(rowStart: 1, colStart: 5, rowSpan: 1, colSpan: 1),
        ),
        isNull,
      );
      // The former trailer-axle hole is now a live control (TASK-040).
      expect(
        layout.controlAt(
          const CellRect(rowStart: 2, colStart: 1, rowSpan: 1, colSpan: 1),
        ),
        ControlId.trailerAxle,
      );
    });
  });

  group('TASK-038 automatic and h-shifter presets', () {
    final presets = {
      'Simple Automatic': DrivingLayout.simpleAutomatic(),
      'Real Automatic': DrivingLayout.realAutomatic(),
      'H-Shifter': DrivingLayout.hShifter(),
    };

    test('each preset tiles the 8x15 grid without overlap', () {
      for (final entry in presets.entries) {
        expectTiles(
          entry.value.slots.map((slot) => slot.rect),
        );
      }
    });

    test('every non-null slot control exists in ControlId', () {
      for (final preset in presets.values) {
        for (final slot in preset.slots) {
          if (slot.control != null) {
            expect(ControlId.values, contains(slot.control));
          }
          if (slot.kind == SlotKind.button) {
            expect(slot.control, isNotNull);
          }
        }
      }
    });

    test('simple automatic holes the gear cells', () {
      final simple = presets['Simple Automatic']!;
      for (final cell in const [
        CellRect(rowStart: 1, colStart: 11, rowSpan: 1, colSpan: 1),
        CellRect(rowStart: 3, colStart: 12, rowSpan: 1, colSpan: 1),
      ]) {
        final slot = simple.slots.firstWhere(
          (s) => s.rect.contains(cell.rowStart, cell.colStart),
        );
        expect(slot.kind, SlotKind.hole);
      }
    });

    test('real automatic carries drive and reverse buttons', () {
      final real = presets['Real Automatic']!;
      final drive = real.slots.firstWhere(
        (s) => s.control == ControlId.shiftToDrive,
      );
      expect(
        drive.rect,
        const CellRect(rowStart: 1, colStart: 11, rowSpan: 2, colSpan: 2),
      );
      final reverse = real.slots.firstWhere(
        (s) => s.control == ControlId.shiftToReverse,
      );
      expect(
        reverse.rect,
        const CellRect(rowStart: 3, colStart: 11, rowSpan: 2, colSpan: 2),
      );
      expect(
        real.slots.where(
          (s) =>
              s.control == ControlId.gearUp ||
              s.control == ControlId.gearDown,
        ),
        isEmpty,
      );
    });

    test('h-shifter places the hole module and keeps the camera pad', () {
      final hshifter = presets['H-Shifter']!;
      for (var row = 1; row <= 4; row++) {
        for (var col = 1; col <= 4; col++) {
          final slot = hshifter.slots.firstWhere(
            (s) => s.rect.contains(row, col),
          );
          expect(slot.kind, SlotKind.hole, reason: 'hole at $row:$col');
        }
      }
      expect(
        hshifter.slots.where(
          (s) => s.kind == SlotKind.pedal && s.pedal == PedalType.clutch,
        ),
        isEmpty,
      );
      final pad = hshifter.slots.firstWhere(
        (s) => s.kind == SlotKind.cameraPad,
      );
      expect(
        pad.rect,
        const CellRect(rowStart: 1, colStart: 13, rowSpan: 3, colSpan: 3),
      );
    });
  });
}
