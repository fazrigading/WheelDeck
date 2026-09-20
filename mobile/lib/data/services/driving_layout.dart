import 'dashboard_input.dart';
import 'pedal_input.dart';

/// A rectangular region of the driving screen's global 8x15 cell grid,
/// addressed in 1-based `(rowStart, colStart)` with spans. The grid is
/// 2x3 blocks of 4 rows x 5 columns each; a 1x1 cell is `W/15 x H/8` device
/// pixels and its aspect follows the screen. Value type.
class CellRect {
  const CellRect({
    required this.rowStart,
    required this.colStart,
    required this.rowSpan,
    required this.colSpan,
  });

  final int rowStart;
  final int colStart;
  final int rowSpan;
  final int colSpan;

  /// Whether the 1-based cell position (`row`, `col`) falls inside this rect.
  bool contains(int row, int col) =>
      row >= rowStart &&
      row < rowStart + rowSpan &&
      col >= colStart &&
      col < colStart + colSpan;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellRect &&
          rowStart == other.rowStart &&
          colStart == other.colStart &&
          rowSpan == other.rowSpan &&
          colSpan == other.colSpan;

  @override
  int get hashCode => Object.hash(rowStart, colStart, rowSpan, colSpan);

  @override
  String toString() =>
      'CellRect($rowStart, $colStart, +$rowSpan rows, +$colSpan cols)';
}

/// What a layout slot renders.
enum SlotKind {
  /// A single-cell dashboard control with a [LayoutSlot.control].
  button,

  /// A pedal bar sized to its rect; [LayoutSlot.pedal] says which pedal.
  pedal,

  /// The steering wheel. Sized from its rect at render time.
  wheel,

  /// The 2x2 gear-up button; [LayoutSlot.control] is `ControlId.gearUp`.
  gearUp,

  /// The 2x2 gear-down button; [LayoutSlot.control] is `ControlId.gearDown`.
  gearDown,

  /// The 3x3 camera pad. Its interaction lives in the pad widget.
  cameraPad,

  /// A reserved cell whose control does not exist yet; rendered disabled.
  hole,
}

/// One placed element of a [DrivingLayout].
class LayoutSlot {
  const LayoutSlot({
    required this.rect,
    required this.kind,
    this.control,
    this.pedal,
  }) : assert(
         kind != SlotKind.button || control != null,
         'a button slot needs its control',
       ),
       assert(
         kind == SlotKind.button ||
             kind == SlotKind.gearUp ||
             kind == SlotKind.gearDown ||
             control == null,
         'only button-like slots carry a control',
       ),
       assert(
         kind == SlotKind.pedal || pedal == null,
         'only pedal slots carry a pedal',
       );

  final CellRect rect;
  final SlotKind kind;

  /// The control this slot sends, or null for pedals, the wheel, the camera
  /// pad, and holes.
  final ControlId? control;

  /// Which pedal this slot renders when [kind] is [SlotKind.pedal]. The
  /// ControlId enum has no members for the pedals themselves, so the pedal
  /// kind needs its own discriminator for colouring and ordering.
  final PedalType? pedal;
}

/// A named dashboard layout: the placement authority for the rotatable grid.
///
/// Layouts are declared as data, not widget literals (REQ-015). [blocks] are
/// the six block regions of the global grid; a preset like [sequential]
/// enumerates every slot it places, emitting [SlotKind.hole] for controls
/// that do not exist yet.
class DrivingLayout {
  const DrivingLayout({required this.name, required this.slots});

  final String name;
  final List<LayoutSlot> slots;

  /// The control of the slot covering [cell]'s start position, or null when
  /// the covering slot has no control (pedal, wheel, camera pad, hole) or no
  /// slot covers it.
  ControlId? controlAt(CellRect cell) {
    for (final slot in slots) {
      if (slot.rect.contains(cell.rowStart, cell.colStart)) {
        return slot.control;
      }
    }
    return null;
  }

  /// The six block regions, A through F, as `(rowStart, colStart)` rects on
  /// the global 8x15 grid: rows 1-4 form the top band, rows 5-8 the bottom;
  /// columns 1-5, 6-10, and 11-15 form the left, middle, and right bands.
  static const List<CellRect> blocks = [
    blockA,
    blockB,
    blockC,
    blockD,
    blockE,
    blockF,
  ];

  static const CellRect blockA = CellRect(
    rowStart: 1,
    colStart: 1,
    rowSpan: 4,
    colSpan: 5,
  );
  static const CellRect blockB = CellRect(
    rowStart: 1,
    colStart: 6,
    rowSpan: 4,
    colSpan: 5,
  );
  static const CellRect blockC = CellRect(
    rowStart: 1,
    colStart: 11,
    rowSpan: 4,
    colSpan: 5,
  );
  static const CellRect blockD = CellRect(
    rowStart: 5,
    colStart: 1,
    rowSpan: 4,
    colSpan: 5,
  );
  static const CellRect blockE = CellRect(
    rowStart: 5,
    colStart: 6,
    rowSpan: 4,
    colSpan: 5,
  );
  static const CellRect blockF = CellRect(
    rowStart: 5,
    colStart: 11,
    rowSpan: 4,
    colSpan: 5,
  );

  /// The Sequential shifting preset: gear-up and gear-down shifting, all six
  /// blocks filled per the researched tables, with holes for controls that
  /// do not exist yet.
  static DrivingLayout sequential() => const DrivingLayout(
    name: 'Sequential',
    slots: [
      // Block A — assists, signals, high beam, clutch.
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 1, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.adaptiveCruise,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 2, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.laneKeeping,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 3, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.laneAssistant,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 1, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.trailerAxle,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 2, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.liftDropAxle,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 3, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.trailer,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 1, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.hazardLights,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 2, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.beaconLights,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 3, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.differentialLock,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 1, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.turnSignalLeft,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 2, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.turnSignalRight,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 3, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.highBeamToggle,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 4, rowSpan: 4, colSpan: 2),
        kind: SlotKind.pedal,
        pedal: PedalType.clutch,
      ),

      // Block B — audio, windows, chat, retarder, cruise speed.
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.audioVolumeDown,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.audioPrevious,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.audioPlayPause,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.audioNext,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.audioVolumeUp,
      ),
      // Driver window up, nav zoom in: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cruiseSpeedIncrease,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.retarderIncrease,
      ),
      // Passenger window up: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      // Driver window down: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.navigationZoomOut,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cruiseSpeedDecrease,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.retarderDecrease,
      ),
      // Passenger window down: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      // Overlay, chat, quick replies, name tags, push to talk: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),

      // Block C — gears, camera pad, brakes, cruise.
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 11, rowSpan: 2, colSpan: 2),
        kind: SlotKind.gearUp,
        control: ControlId.gearUp,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 1, colStart: 13, rowSpan: 3, colSpan: 3),
        kind: SlotKind.cameraPad,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 11, rowSpan: 2, colSpan: 2),
        kind: SlotKind.gearDown,
        control: ControlId.gearDown,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 13, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.emergencyBrake,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 14, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.engineBrake,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 15, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cruiseToggle,
      ),

      // Block D — wheel plus the beside-the-wheel column.
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 1, rowSpan: 4, colSpan: 4),
        kind: SlotKind.wheel,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 5, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.horn,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 5, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.flasher,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 5, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.wipers,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 5, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.headlightToggle,
      ),

      // Block E — cameras, info, services, menu.
      // Camera row: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.quickSave,
      ),
      // Dashboard info, next camera: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.hudWidgets,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cruiseSetResume,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.quickInfo,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.mirrorToggle,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.screenshot,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.widgetOptions,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.services,
      ),
      // Menu, world map, photo mode: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.garageManager,
      ),
      // Activate: Phase 6.
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.hole,
      ),

      // Block F — engine column, brake, accelerator.
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 11, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.engineElectricity,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 11, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.engineStart,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 7, colStart: 11, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.parkingBrake,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 11, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.shiftToNeutral,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 12, rowSpan: 4, colSpan: 2),
        kind: SlotKind.pedal,
        pedal: PedalType.brake,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 14, rowSpan: 4, colSpan: 2),
        kind: SlotKind.pedal,
        pedal: PedalType.accelerator,
      ),
    ],
  );
}
