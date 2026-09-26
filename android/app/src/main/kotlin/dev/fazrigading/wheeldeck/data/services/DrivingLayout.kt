package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType

/// A rectangular region of the driving screen's global 8x15 cell grid,
/// addressed in 1-based `(rowStart, colStart)` with spans. The grid is 2x3
/// blocks of 4 rows x 5 columns each; a 1x1 cell is `width/15 x height/8`
/// pixels and its aspect follows the screen. Value type.
data class CellRect(
    val rowStart: Int,
    val colStart: Int,
    val rowSpan: Int,
    val colSpan: Int,
) {
    /// Whether the 1-based cell position ([row], [col]) falls inside this rect.
    fun contains(row: Int, col: Int): Boolean =
        row >= rowStart && row < rowStart + rowSpan &&
            col >= colStart && col < colStart + colSpan

    fun overlaps(other: CellRect): Boolean =
        rowStart < other.rowStart + other.rowSpan &&
            other.rowStart < rowStart + rowSpan &&
            colStart < other.colStart + other.colSpan &&
            other.colStart < colStart + colSpan
}

/// What a layout slot renders.
enum class SlotKind {
    /// A single-cell dashboard control with a [LayoutSlot.control].
    Button,

    /// A pedal bar sized to its rect; [LayoutSlot.pedal] says which pedal.
    Pedal,

    /// The accelerator and brake as one group (TODO.md Dashboard 2). The
    /// renderer splits the rect between the two bars.
    PedalGroup,

    /// The steering wheel. Sized from its rect at render time.
    Wheel,

    /// The 2x1 gear-up button; [LayoutSlot.control] is [ControlId.GearUp].
    GearUp,

    /// The 2x1 gear-down button; [LayoutSlot.control] is [ControlId.GearDown].
    GearDown,

    /// The 3x3 camera pad. Its interaction lives in the pad widget.
    CameraPad,

    /// A reserved cell rendered disabled — either a control that does not exist
    /// yet or a cell freed by a layout reshape.
    Hole,
}

/// One placed element of a [DrivingLayout].
data class LayoutSlot(
    val rect: CellRect,
    val kind: SlotKind,
    /// The control this slot sends, or null for pedals, the wheel, the camera
    /// pad, and holes.
    val control: ControlId? = null,
    /// Which pedal this slot renders when [kind] is [SlotKind.Pedal]. The
    /// ControlId enum has no members for the pedals themselves, so the pedal
    /// kind needs its own discriminator for colouring and ordering.
    val pedal: PedalType? = null,
) {
    init {
        val buttonLike = kind == SlotKind.Button || kind == SlotKind.GearUp || kind == SlotKind.GearDown
        require(!buttonLike || control != null) { "a button slot needs its control" }
        require(buttonLike || control == null) { "only button-like slots carry a control" }
        require(kind == SlotKind.Pedal || pedal == null) { "only pedal slots carry a pedal" }
    }

    /// Whether this slot is a dashboard control cell: a button or a gear cell.
    val isButton: Boolean
        get() = kind == SlotKind.Button || kind == SlotKind.GearUp || kind == SlotKind.GearDown

    /// Whether this is one of the two gear cells, which the automatic presets
    /// replace.
    val isGearCell: Boolean
        get() = kind == SlotKind.GearUp || kind == SlotKind.GearDown
}

/// A named dashboard layout: the placement authority for the rotatable grid.
///
/// Layouts are declared as data, not widget literals (REQ-015). [blocks] are
/// the six block regions of the global grid; a preset like [sequential]
/// enumerates every slot it places, emitting [SlotKind.Hole] for cells no
/// control occupies.
data class DrivingLayout(val name: String, val slots: List<LayoutSlot>) {

    /// The control of the slot covering [cell]'s start position, or null when
    /// the covering slot has no control (pedal, wheel, camera pad, hole) or no
    /// slot covers it.
    fun controlAt(cell: CellRect): ControlId? =
        slots.firstOrNull { it.rect.contains(cell.rowStart, cell.colStart) }?.control

    /// The slot covering [cell]'s start position, if any.
    fun slotAt(cell: CellRect): LayoutSlot? =
        slots.firstOrNull { it.rect.contains(cell.rowStart, cell.colStart) }

    /// The slots that fall inside [block], grouped once per layout rather than
    /// refiltered on every frame.
    fun slotsIn(block: CellRect): List<LayoutSlot> = slotsByBlock.getOrElse(block) { emptyList() }

    private val slotsByBlock: Map<CellRect, List<LayoutSlot>> by lazy {
        blocks.associateWith { block -> slots.filter { it.rect.overlaps(block) } }
    }

    companion object {
        private fun slot(
            rect: CellRect,
            kind: SlotKind,
            control: ControlId? = null,
            pedal: PedalType? = null,
        ) = LayoutSlot(rect, kind, control, pedal)

        /// Global grid extents: every slot rect must fit inside these bounds.
        const val GRID_ROWS = 8
        const val GRID_COLS = 15

        val blockA = CellRect(1, 1, 4, 5)
        val blockB = CellRect(1, 6, 4, 5)
        val blockC = CellRect(1, 11, 4, 5)
        val blockD = CellRect(5, 1, 4, 5)
        val blockE = CellRect(5, 6, 4, 5)
        val blockF = CellRect(5, 11, 4, 5)

        /// The six block regions, A through F: rows 1-4 form the top band, rows
        /// 5-8 the bottom; columns 1-5, 6-10, and 11-15 the left, middle, and
        /// right bands.
        val blocks = listOf(blockA, blockB, blockC, blockD, blockE, blockF)

        /// The Sequential shifting preset: gear-up and gear-down shifting, all
        /// six blocks filled per the researched tables, with holes for cells no
        /// control occupies.
        val sequential = DrivingLayout(
            name = "Sequential",
            slots = listOf(
        // ---- Block A
        slot(CellRect(rowStart = 1, colStart = 1, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.AdaptiveCruise),
        slot(CellRect(rowStart = 1, colStart = 2, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.LaneKeeping),
        slot(CellRect(rowStart = 1, colStart = 3, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.LaneAssistant),
        slot(CellRect(rowStart = 1, colStart = 4, rowSpan = 4, colSpan = 2), SlotKind.Pedal, pedal = PedalType.Clutch),
        slot(CellRect(rowStart = 1, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.AudioVolumeDown),
        slot(CellRect(rowStart = 1, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.AudioPrevious),
        slot(CellRect(rowStart = 1, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.AudioPlayPause),
        slot(CellRect(rowStart = 1, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.AudioNext),
        slot(CellRect(rowStart = 1, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.AudioVolumeUp),
        // TODO.md Dashboard 1: 2 rows x 1 col, not 2x2.
        slot(CellRect(rowStart = 1, colStart = 11, rowSpan = 2, colSpan = 1), SlotKind.GearUp, control = ControlId.GearUp),
        slot(CellRect(rowStart = 1, colStart = 13, rowSpan = 3, colSpan = 3), SlotKind.CameraPad),
        slot(CellRect(rowStart = 2, colStart = 1, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.TrailerAxle),
        slot(CellRect(rowStart = 2, colStart = 2, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.LiftDropAxle),
        slot(CellRect(rowStart = 2, colStart = 3, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Trailer),
        slot(CellRect(rowStart = 2, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.DriverWindowUp),
        slot(CellRect(rowStart = 2, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.NavigationZoomIn),
        slot(CellRect(rowStart = 2, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CruiseSpeedIncrease),
        slot(CellRect(rowStart = 2, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.RetarderIncrease),
        slot(CellRect(rowStart = 2, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.PassengerWindowUp),
        slot(CellRect(rowStart = 3, colStart = 1, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.HazardLights),
        slot(CellRect(rowStart = 3, colStart = 2, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.BeaconLights),
        slot(CellRect(rowStart = 3, colStart = 3, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.DifferentialLock),
        slot(CellRect(rowStart = 3, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.DriverWindowDown),
        slot(CellRect(rowStart = 3, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.NavigationZoomOut),
        slot(CellRect(rowStart = 3, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CruiseSpeedDecrease),
        slot(CellRect(rowStart = 3, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.RetarderDecrease),
        slot(CellRect(rowStart = 3, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.PassengerWindowDown),
        slot(CellRect(rowStart = 3, colStart = 11, rowSpan = 2, colSpan = 1), SlotKind.GearDown, control = ControlId.GearDown),
        slot(CellRect(rowStart = 4, colStart = 1, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.TurnSignalLeft),
        slot(CellRect(rowStart = 4, colStart = 2, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.TurnSignalRight),
        slot(CellRect(rowStart = 4, colStart = 3, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.HighBeamToggle),
        slot(CellRect(rowStart = 4, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.OverlayActivation),
        slot(CellRect(rowStart = 4, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.ChatActivation),
        slot(CellRect(rowStart = 4, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.QuickReplies),
        slot(CellRect(rowStart = 4, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.NameTags),
        slot(CellRect(rowStart = 4, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.PushToTalk),
        slot(CellRect(rowStart = 4, colStart = 13, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.EmergencyBrake),
        slot(CellRect(rowStart = 4, colStart = 14, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.EngineBrake),
        slot(CellRect(rowStart = 4, colStart = 15, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CruiseToggle),
        // ---- Block B
        // ---- Block C
        // ---- Block D
        slot(CellRect(rowStart = 5, colStart = 1, rowSpan = 4, colSpan = 4), SlotKind.Wheel),
        slot(CellRect(rowStart = 5, colStart = 5, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Horn),
        slot(CellRect(rowStart = 5, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CameraInterior),
        slot(CellRect(rowStart = 5, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CameraChasing),
        slot(CellRect(rowStart = 5, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CameraTopdown),
        slot(CellRect(rowStart = 5, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CameraRoof),
        slot(CellRect(rowStart = 5, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CameraLeanout),
        slot(CellRect(rowStart = 5, colStart = 11, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.EngineElectricity),
        // TODO.md Dashboard 2: accelerator + brake as one 4x3 group.
        slot(CellRect(rowStart = 5, colStart = 12, rowSpan = 4, colSpan = 3), SlotKind.PedalGroup),
        slot(CellRect(rowStart = 6, colStart = 5, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Flasher),
        slot(CellRect(rowStart = 6, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.QuickSave),
        slot(CellRect(rowStart = 6, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.DashboardInfo),
        slot(CellRect(rowStart = 6, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.NextCamera),
        slot(CellRect(rowStart = 6, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.HudWidgets),
        slot(CellRect(rowStart = 6, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.CruiseSetResume),
        slot(CellRect(rowStart = 6, colStart = 11, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.EngineStart),
        slot(CellRect(rowStart = 7, colStart = 5, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Wipers),
        slot(CellRect(rowStart = 7, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.QuickInfo),
        slot(CellRect(rowStart = 7, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.MirrorToggle),
        slot(CellRect(rowStart = 7, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Screenshot),
        slot(CellRect(rowStart = 7, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.WidgetOptions),
        slot(CellRect(rowStart = 7, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Services),
        slot(CellRect(rowStart = 7, colStart = 11, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.ParkingBrake),
        slot(CellRect(rowStart = 8, colStart = 5, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.HeadlightToggle),
        slot(CellRect(rowStart = 8, colStart = 6, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Menu),
        slot(CellRect(rowStart = 8, colStart = 7, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.WorldMap),
        slot(CellRect(rowStart = 8, colStart = 8, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.PhotoMode),
        slot(CellRect(rowStart = 8, colStart = 9, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.GarageManager),
        slot(CellRect(rowStart = 8, colStart = 10, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.Activate),
        slot(CellRect(rowStart = 8, colStart = 11, rowSpan = 1, colSpan = 1), SlotKind.Button, control = ControlId.ShiftToNeutral),
        // ---- Cells the two reshapes above freed, kept as holes so the grid
        // still tiles end to end (TODO.md Dashboard 1 and 2).
        slot(CellRect(rowStart = 1, colStart = 12, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 2, colStart = 12, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 3, colStart = 12, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 4, colStart = 12, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 5, colStart = 15, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 6, colStart = 15, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 7, colStart = 15, rowSpan = 1, colSpan = 1), SlotKind.Hole),
        slot(CellRect(rowStart = 8, colStart = 15, rowSpan = 1, colSpan = 1), SlotKind.Hole),            ),
        )

        /// The module is 16 single-cell holes: a reserved footprint the
        /// physical shifter occupies in game.
        private val hShifterModuleHoles = buildList {
            for (row in 1..4) {
                for (col in 1..4) add(holeAt(CellRect(row, col, 1, 1)))
            }
        }

        /// Simple Automatic: the game shifts; the gear cells become holes. Same
        /// rects as [sequential], so tiling is unchanged.
        val simpleAutomatic = sequential.copy(
            name = "Simple Automatic",
            slots = sequential.slots.map { if (it.isGearCell) holeAt(it.rect) else it },
        )

        /// Real Automatic: the gear cells become Drive and Reverse buttons;
        /// Neutral already sits in block F, completing the PRND set. Drive and
        /// Reverse ship unbound (user-set-able, mirroring the desktop tables).
        val realAutomatic = sequential.copy(
            name = "Real Automatic",
            slots = sequential.slots.map {
                when (it.kind) {
                    SlotKind.GearUp -> it.asButton(ControlId.ShiftToDrive)
                    SlotKind.GearDown -> it.asButton(ControlId.ShiftToReverse)
                    else -> it
                }
            },
        )

        /// Where the 4x4 H-Shifter module lands in [hShifter].
        private val hShifterModule = CellRect(1, 1, 4, 4)

        /// H-Shifter: the physical shifter and clutch replace the screen gears,
        /// the clutch bar, and the Block A assist cluster, where the hole-only
        /// 4x4 H-Shifter module lands.
        val hShifter = DrivingLayout(
            name = "H-Shifter",
            slots = sequential.slots.mapNotNull { slot ->
                when {
                    slot.isGearCell -> holeAt(slot.rect)
                    slot.kind == SlotKind.Pedal && slot.pedal == PedalType.Clutch ->
                        holeAt(CellRect(1, 5, 4, 1))
                    slot.rect.overlaps(hShifterModule) -> null
                    else -> slot
                }
            } + hShifterModuleHoles,
        )


        /// Every shipped preset, in the order the layout editor lists them.
        val presets = listOf(sequential, simpleAutomatic, realAutomatic, hShifter)

        private fun holeAt(rect: CellRect) = LayoutSlot(rect, SlotKind.Hole)

        private fun LayoutSlot.asButton(control: ControlId) =
            copy(kind = SlotKind.Button, control = control)
    }
}
