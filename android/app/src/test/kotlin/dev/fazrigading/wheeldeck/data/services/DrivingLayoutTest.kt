package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of mobile/test/data/services/driving_layout_test.dart, with the slot
/// geometry updated for the TODO.md Dashboard fixes: the gear cells are 2x1, the
/// accelerator and brake are one 4x3 group, and the cells those reshapes free
/// are holes.
class DrivingLayoutTest {

    private val layout = DrivingLayout.sequential

    private fun assertSlot(
        layout: DrivingLayout,
        row: Int,
        col: Int,
        kind: SlotKind,
        rowSpan: Int,
        colSpan: Int,
    ) {
        val slot = requireNotNull(layout.slotAt(CellRect(row, col, 1, 1))) { "no slot at $row:$col" }
        assertEquals("kind at $row:$col", kind, slot.kind)
        assertEquals("rect at $row:$col", CellRect(row, col, rowSpan, colSpan), slot.rect)
    }

    /// Every cell of every rect, so both an overlap and a gap fail.
    private fun coveredCells(layout: DrivingLayout): Set<String> {
        val covered = mutableSetOf<String>()
        for (slot in layout.slots) {
            for (row in slot.rect.rowStart until slot.rect.rowStart + slot.rect.rowSpan) {
                for (col in slot.rect.colStart until slot.rect.colStart + slot.rect.colSpan) {
                    val key = "$row:$col"
                    assertTrue("overlap at $key", key !in covered)
                    covered += key
                }
            }
        }
        return covered
    }

    @Test
    fun `block A matches the researched table`() {
    assertEquals(ControlId.AdaptiveCruise, layout.slotAt(CellRect(1, 1, 1, 1))?.control)
    assertEquals(ControlId.LaneKeeping, layout.slotAt(CellRect(1, 2, 1, 1))?.control)
    assertEquals(ControlId.LaneAssistant, layout.slotAt(CellRect(1, 3, 1, 1))?.control)
    assertSlot(layout, 1, 4, SlotKind.Pedal, 4, 2)
    assertEquals(PedalType.Clutch, layout.slotAt(CellRect(1, 4, 1, 1))?.pedal)
    assertEquals(ControlId.TrailerAxle, layout.slotAt(CellRect(2, 1, 1, 1))?.control)
    assertEquals(ControlId.LiftDropAxle, layout.slotAt(CellRect(2, 2, 1, 1))?.control)
    assertEquals(ControlId.Trailer, layout.slotAt(CellRect(2, 3, 1, 1))?.control)
    assertEquals(ControlId.HazardLights, layout.slotAt(CellRect(3, 1, 1, 1))?.control)
    assertEquals(ControlId.BeaconLights, layout.slotAt(CellRect(3, 2, 1, 1))?.control)
    assertEquals(ControlId.DifferentialLock, layout.slotAt(CellRect(3, 3, 1, 1))?.control)
    assertEquals(ControlId.TurnSignalLeft, layout.slotAt(CellRect(4, 1, 1, 1))?.control)
    assertEquals(ControlId.TurnSignalRight, layout.slotAt(CellRect(4, 2, 1, 1))?.control)
    assertEquals(ControlId.HighBeamToggle, layout.slotAt(CellRect(4, 3, 1, 1))?.control)
    }

    @Test
    fun `block B matches the researched table`() {
    assertEquals(ControlId.AudioVolumeDown, layout.slotAt(CellRect(1, 6, 1, 1))?.control)
    assertEquals(ControlId.AudioPrevious, layout.slotAt(CellRect(1, 7, 1, 1))?.control)
    assertEquals(ControlId.AudioPlayPause, layout.slotAt(CellRect(1, 8, 1, 1))?.control)
    assertEquals(ControlId.AudioNext, layout.slotAt(CellRect(1, 9, 1, 1))?.control)
    assertEquals(ControlId.AudioVolumeUp, layout.slotAt(CellRect(1, 10, 1, 1))?.control)
    assertEquals(ControlId.DriverWindowUp, layout.slotAt(CellRect(2, 6, 1, 1))?.control)
    assertEquals(ControlId.NavigationZoomIn, layout.slotAt(CellRect(2, 7, 1, 1))?.control)
    assertEquals(ControlId.CruiseSpeedIncrease, layout.slotAt(CellRect(2, 8, 1, 1))?.control)
    assertEquals(ControlId.RetarderIncrease, layout.slotAt(CellRect(2, 9, 1, 1))?.control)
    assertEquals(ControlId.PassengerWindowUp, layout.slotAt(CellRect(2, 10, 1, 1))?.control)
    assertEquals(ControlId.DriverWindowDown, layout.slotAt(CellRect(3, 6, 1, 1))?.control)
    assertEquals(ControlId.NavigationZoomOut, layout.slotAt(CellRect(3, 7, 1, 1))?.control)
    assertEquals(ControlId.CruiseSpeedDecrease, layout.slotAt(CellRect(3, 8, 1, 1))?.control)
    assertEquals(ControlId.RetarderDecrease, layout.slotAt(CellRect(3, 9, 1, 1))?.control)
    assertEquals(ControlId.PassengerWindowDown, layout.slotAt(CellRect(3, 10, 1, 1))?.control)
    assertEquals(ControlId.OverlayActivation, layout.slotAt(CellRect(4, 6, 1, 1))?.control)
    assertEquals(ControlId.ChatActivation, layout.slotAt(CellRect(4, 7, 1, 1))?.control)
    assertEquals(ControlId.QuickReplies, layout.slotAt(CellRect(4, 8, 1, 1))?.control)
    assertEquals(ControlId.NameTags, layout.slotAt(CellRect(4, 9, 1, 1))?.control)
    assertEquals(ControlId.PushToTalk, layout.slotAt(CellRect(4, 10, 1, 1))?.control)
    }

    @Test
    fun `block C matches the researched table`() {
    assertEquals(ControlId.GearUp, layout.slotAt(CellRect(1, 11, 1, 1))?.control)
    assertSlot(layout, 1, 11, SlotKind.GearUp, 2, 1)
    assertSlot(layout, 1, 13, SlotKind.CameraPad, 3, 3)
    assertEquals(ControlId.GearDown, layout.slotAt(CellRect(3, 11, 1, 1))?.control)
    assertSlot(layout, 3, 11, SlotKind.GearDown, 2, 1)
    assertEquals(ControlId.EmergencyBrake, layout.slotAt(CellRect(4, 13, 1, 1))?.control)
    assertEquals(ControlId.EngineBrake, layout.slotAt(CellRect(4, 14, 1, 1))?.control)
    assertEquals(ControlId.CruiseToggle, layout.slotAt(CellRect(4, 15, 1, 1))?.control)
    }

    @Test
    fun `block D matches the researched table`() {
    assertSlot(layout, 5, 1, SlotKind.Wheel, 4, 4)
    assertEquals(ControlId.Horn, layout.slotAt(CellRect(5, 5, 1, 1))?.control)
    assertEquals(ControlId.Flasher, layout.slotAt(CellRect(6, 5, 1, 1))?.control)
    assertEquals(ControlId.Wipers, layout.slotAt(CellRect(7, 5, 1, 1))?.control)
    assertEquals(ControlId.HeadlightToggle, layout.slotAt(CellRect(8, 5, 1, 1))?.control)
    }

    @Test
    fun `block E matches the researched table`() {
    assertEquals(ControlId.CameraInterior, layout.slotAt(CellRect(5, 6, 1, 1))?.control)
    assertEquals(ControlId.CameraChasing, layout.slotAt(CellRect(5, 7, 1, 1))?.control)
    assertEquals(ControlId.CameraTopdown, layout.slotAt(CellRect(5, 8, 1, 1))?.control)
    assertEquals(ControlId.CameraRoof, layout.slotAt(CellRect(5, 9, 1, 1))?.control)
    assertEquals(ControlId.CameraLeanout, layout.slotAt(CellRect(5, 10, 1, 1))?.control)
    assertEquals(ControlId.QuickSave, layout.slotAt(CellRect(6, 6, 1, 1))?.control)
    assertEquals(ControlId.DashboardInfo, layout.slotAt(CellRect(6, 7, 1, 1))?.control)
    assertEquals(ControlId.NextCamera, layout.slotAt(CellRect(6, 8, 1, 1))?.control)
    assertEquals(ControlId.HudWidgets, layout.slotAt(CellRect(6, 9, 1, 1))?.control)
    assertEquals(ControlId.CruiseSetResume, layout.slotAt(CellRect(6, 10, 1, 1))?.control)
    assertEquals(ControlId.QuickInfo, layout.slotAt(CellRect(7, 6, 1, 1))?.control)
    assertEquals(ControlId.MirrorToggle, layout.slotAt(CellRect(7, 7, 1, 1))?.control)
    assertEquals(ControlId.Screenshot, layout.slotAt(CellRect(7, 8, 1, 1))?.control)
    assertEquals(ControlId.WidgetOptions, layout.slotAt(CellRect(7, 9, 1, 1))?.control)
    assertEquals(ControlId.Services, layout.slotAt(CellRect(7, 10, 1, 1))?.control)
    assertEquals(ControlId.Menu, layout.slotAt(CellRect(8, 6, 1, 1))?.control)
    assertEquals(ControlId.WorldMap, layout.slotAt(CellRect(8, 7, 1, 1))?.control)
    assertEquals(ControlId.PhotoMode, layout.slotAt(CellRect(8, 8, 1, 1))?.control)
    assertEquals(ControlId.GarageManager, layout.slotAt(CellRect(8, 9, 1, 1))?.control)
    assertEquals(ControlId.Activate, layout.slotAt(CellRect(8, 10, 1, 1))?.control)
    }

    @Test
    fun `block F matches the researched table`() {
    assertEquals(ControlId.EngineElectricity, layout.slotAt(CellRect(5, 11, 1, 1))?.control)
    assertSlot(layout, 5, 12, SlotKind.PedalGroup, 4, 3)
    assertEquals(ControlId.EngineStart, layout.slotAt(CellRect(6, 11, 1, 1))?.control)
    assertEquals(ControlId.ParkingBrake, layout.slotAt(CellRect(7, 11, 1, 1))?.control)
    assertEquals(ControlId.ShiftToNeutral, layout.slotAt(CellRect(8, 11, 1, 1))?.control)
    }

    @Test
    fun `six blocks tile the 8x15 grid without overlap`() {
        val blocks = DrivingLayout("blocks", DrivingLayout.blocks.map { LayoutSlot(it, SlotKind.Hole) })

        assertEquals(8 * 15, coveredCells(blocks).size)
    }

    @Test
    fun `sequential slots tile the 8x15 grid without overlap`() {
        assertEquals(8 * 15, coveredCells(layout).size)
    }

    @Test
    fun `slot kinds agree with their control and pedal fields`() {
        for (slot in layout.slots) {
            if (slot.isButton) {
                assertTrue("${slot.kind} at ${slot.rect} needs a control", slot.control != null)
            } else {
                assertTrue("${slot.kind} at ${slot.rect} carries no control", slot.control == null)
            }
            if (slot.kind != SlotKind.Pedal) {
                assertTrue("only pedals carry a pedal", slot.pedal == null)
            }
        }
    }

    @Test
    fun `controlAt resolves the slot covering a probed cell`() {
        assertEquals(ControlId.TurnSignalLeft, layout.controlAt(CellRect(4, 1, 1, 1)))
        // Pedal slots carry no ControlId.
        assertNull(layout.controlAt(CellRect(1, 5, 1, 1)))
        assertEquals(ControlId.TrailerAxle, layout.controlAt(CellRect(2, 1, 1, 1)))
    }

    // ---- TODO.md Dashboard fix 1: the gear cells are 2 rows x 1 col.

    @Test
    fun `gear cells are two rows by one col`() {
        assertSlot(layout, 1, 11, SlotKind.GearUp, 2, 1)
        assertSlot(layout, 3, 11, SlotKind.GearDown, 2, 1)
        assertEquals(ControlId.GearUp, layout.controlAt(CellRect(1, 11, 1, 1)))
        assertEquals(ControlId.GearDown, layout.controlAt(CellRect(3, 11, 1, 1)))
    }

    @Test
    fun `the column the gear cells freed is a hole`() {
        for (row in 1..4) {
            assertSlot(layout, row, 12, SlotKind.Hole, 1, 1)
        }
    }

    // ---- TODO.md Dashboard fix 2: accelerator and brake are one 4x3 group.

    @Test
    fun `accelerator and brake share one four by three group`() {
        assertSlot(layout, 5, 12, SlotKind.PedalGroup, 4, 3)
    }

    @Test
    fun `the column the pedal group freed is a hole`() {
        for (row in 5..8) {
            assertSlot(layout, row, 15, SlotKind.Hole, 1, 1)
        }
    }

    @Test
    fun `the wheel slot is a square flush with the bottom edge at 2400x1080`() {
        val cellWidth = 2400.0 / DrivingLayout.GRID_COLS
        val cellHeight = 1080.0 / DrivingLayout.GRID_ROWS
        val wheel = requireNotNull(layout.slotAt(CellRect(5, 2, 1, 1)))
        val slotWidth = wheel.rect.colSpan * cellWidth
        val slotHeight = wheel.rect.rowSpan * cellHeight

        // Four columns wide and the full block height, so a square of side ==
        // block height fits centered with equal margins, flush with the bottom.
        assertEquals(540.0, slotHeight, 0.01)
        assertEquals(640.0, slotWidth, 0.01)
        val diameter = slotHeight
        assertEquals(50.0, (slotWidth - diameter) / 2, 0.01)
        assertEquals(8, wheel.rect.rowStart + wheel.rect.rowSpan - 1)
    }

    @Test
    fun `the camera pad keeps its three by three slot`() {
        assertSlot(layout, 1, 13, SlotKind.CameraPad, 3, 3)
    }

    @Test
    fun `every preset tiles the 8x15 grid without overlap`() {
        for (preset in DrivingLayout.presets) {
            assertEquals("${preset.name} tiles", 8 * 15, coveredCells(preset).size)
        }
    }

    @Test
    fun `simple automatic holes the gear cells`() {
        assertSlot(DrivingLayout.simpleAutomatic, 1, 11, SlotKind.Hole, 2, 1)
        assertSlot(DrivingLayout.simpleAutomatic, 3, 11, SlotKind.Hole, 2, 1)
    }

    @Test
    fun `real automatic carries drive and reverse buttons`() {
        val real = DrivingLayout.realAutomatic

        assertEquals(ControlId.ShiftToDrive, real.controlAt(CellRect(1, 11, 1, 1)))
        assertEquals(ControlId.ShiftToReverse, real.controlAt(CellRect(3, 11, 1, 1)))
        assertEquals(0, real.slots.count { it.isGearCell })
    }

    @Test
    fun `h-shifter places the hole module and keeps the camera pad`() {
        val hShifter = DrivingLayout.hShifter

        for (row in 1..4) {
            for (col in 1..4) {
                assertEquals(
                    "hole at $row:$col",
                    SlotKind.Hole,
                    requireNotNull(hShifter.slotAt(CellRect(row, col, 1, 1))).kind,
                )
            }
        }
        assertEquals(
            0,
            hShifter.slots.count { it.kind == SlotKind.Pedal && it.pedal == PedalType.Clutch },
        )
        assertSlot(hShifter, 1, 13, SlotKind.CameraPad, 3, 3)
    }
}
