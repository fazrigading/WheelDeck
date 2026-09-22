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

  CellRect copyWith({
    int? rowStart,
    int? colStart,
    int? rowSpan,
    int? colSpan,
  }) =>
      CellRect(
        rowStart: rowStart ?? this.rowStart,
        colStart: colStart ?? this.colStart,
        rowSpan: rowSpan ?? this.rowSpan,
        colSpan: colSpan ?? this.colSpan,
      );
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
  /// The Sequential preset currently emits none, but custom presets may.
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

  LayoutSlot copyWith({
    CellRect? rect,
    SlotKind? kind,
    ControlId? control,
    PedalType? pedal,
  }) =>
      LayoutSlot(
        rect: rect ?? this.rect,
        kind: kind ?? this.kind,
        control: control ?? this.control,
        pedal: pedal ?? this.pedal,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutSlot &&
          rect == other.rect &&
          kind == other.kind &&
          control == other.control &&
          pedal == other.pedal;

  @override
  int get hashCode => Object.hash(rect, kind, control, pedal);
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
  /// Global grid extents: every slot rect must fit inside these bounds.
  static const int gridRows = 8;
  static const int gridCols = 15;

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
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.driverWindowUp,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.navigationZoomIn,
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
      LayoutSlot(
        rect: CellRect(rowStart: 2, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.passengerWindowUp,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.driverWindowDown,
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
      LayoutSlot(
        rect: CellRect(rowStart: 3, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.passengerWindowDown,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.overlayActivation,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.chatActivation,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.quickReplies,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.nameTags,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 4, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.pushToTalk,
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
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cameraInterior,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cameraChasing,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cameraTopdown,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cameraRoof,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 5, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.cameraLeanout,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.quickSave,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.dashboardInfo,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 6, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.nextCamera,
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
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 6, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.menu,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 7, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.worldMap,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 8, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.photoMode,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 9, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.garageManager,
      ),
      LayoutSlot(
        rect: CellRect(rowStart: 8, colStart: 10, rowSpan: 1, colSpan: 1),
        kind: SlotKind.button,
        control: ControlId.activate,
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

/// Why a layout edit was refused. Surfaced so the editor can explain a
/// failed drop instead of silently ignoring it.
enum EditRefusal {
  /// No slot exists at the edit's source span.
  slotNotFound,

  /// The target span overlaps an already placed slot.
  targetOccupied,

  /// The target span falls outside the 8x15 grid.
  outOfBounds,

  /// The slot is structural (pedal, wheel) and cannot be removed.
  structuralSlot,
}

/// The outcome of a layout edit: either the new layout or a refusal reason.
sealed class LayoutEditResult {
  const LayoutEditResult();
}

/// An edit that produced [layout]. The input layout is never mutated.
final class EditApplied extends LayoutEditResult {
  const EditApplied(this.layout);
  final DrivingLayout layout;
}

/// An edit that left the layout unchanged, with the [reason] why.
final class EditRefused extends LayoutEditResult {
  const EditRefused(this.reason);
  final EditRefusal reason;
}

bool _overlaps(CellRect a, CellRect b) =>
    a.rowStart < b.rowStart + b.rowSpan &&
    b.rowStart < a.rowStart + a.rowSpan &&
    a.colStart < b.colStart + b.colSpan &&
    b.colStart < a.colStart + a.colSpan;

bool _inBounds(CellRect rect) =>
    rect.rowStart >= 1 &&
    rect.colStart >= 1 &&
    rect.rowStart + rect.rowSpan - 1 <= DrivingLayout.gridRows &&
    rect.colStart + rect.colSpan - 1 <= DrivingLayout.gridCols;

/// Moves the slot at [from] to [to], returning the new layout. Refuses when
/// no slot sits at [from], [to] leaves the grid, or [to] overlaps another
/// slot — neighbours are never pushed.
LayoutEditResult applyMove(
  DrivingLayout layout,
  CellRect from,
  CellRect to,
) {
  final index = layout.slots.indexWhere((slot) => slot.rect == from);
  if (index == -1) return const EditRefused(EditRefusal.slotNotFound);
  if (to == from) return EditApplied(layout);
  if (!_inBounds(to)) return const EditRefused(EditRefusal.outOfBounds);
  for (var i = 0; i < layout.slots.length; i++) {
    if (i != index && _overlaps(layout.slots[i].rect, to)) {
      return const EditRefused(EditRefusal.targetOccupied);
    }
  }
  final slots = layout.slots.toList()
    ..[index] = layout.slots[index].copyWith(rect: to);
  return EditApplied(DrivingLayout(name: layout.name, slots: slots));
}

/// Adds [control] as a button slot at [at]. Refuses when [at] leaves the
/// grid or overlaps an already placed slot.
LayoutEditResult addControl(
  DrivingLayout layout,
  CellRect at,
  ControlId control,
) {
  if (!_inBounds(at)) return const EditRefused(EditRefusal.outOfBounds);
  for (final slot in layout.slots) {
    if (_overlaps(slot.rect, at)) {
      return const EditRefused(EditRefusal.targetOccupied);
    }
  }
  return EditApplied(
    DrivingLayout(
      name: layout.name,
      slots: [
        ...layout.slots,
        LayoutSlot(rect: at, kind: SlotKind.button, control: control),
      ],
    ),
  );
}

/// Removes the slot at [at], returning its cells to empty. Refuses when no
/// slot sits at [at], or when the slot is structural (pedal, wheel).
LayoutEditResult removeSlot(DrivingLayout layout, CellRect at) {
  final index = layout.slots.indexWhere((slot) => slot.rect == at);
  if (index == -1) return const EditRefused(EditRefusal.slotNotFound);
  final kind = layout.slots[index].kind;
  if (kind == SlotKind.pedal || kind == SlotKind.wheel) {
    return const EditRefused(EditRefusal.structuralSlot);
  }
  final slots = layout.slots.toList()..removeAt(index);
  return EditApplied(DrivingLayout(name: layout.name, slots: slots));
}

/// Every position where a [rowSpan] x [colSpan] slot fits without overlap.
/// The editor highlights these as valid drop targets.
Set<CellRect> freeSpans(DrivingLayout layout, int rowSpan, int colSpan) {
  assert(rowSpan >= 1 && colSpan >= 1, 'span must cover whole cells');
  final free = <CellRect>{};
  for (var row = 1; row + rowSpan - 1 <= DrivingLayout.gridRows; row++) {
    for (var col = 1; col + colSpan - 1 <= DrivingLayout.gridCols; col++) {
      final candidate = CellRect(
        rowStart: row,
        colStart: col,
        rowSpan: rowSpan,
        colSpan: colSpan,
      );
      var blocked = false;
      for (final slot in layout.slots) {
        if (_overlaps(slot.rect, candidate)) {
          blocked = true;
          break;
        }
      }
      if (!blocked) free.add(candidate);
    }
  }
  return free;
}
