package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.CellRect
import dev.fazrigading.wheeldeck.data.services.DrivingLayout
import dev.fazrigading.wheeldeck.data.services.SlotKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of the geometry cases in
/// mobile/test/ui/features/driving/block_grid_test.dart, plus the
/// inter-block padding the TODO.md fix adds. The rendered-widget cases need a
/// device; the numbers they assert come from here.
class BlockGeometryTest {

    /** Reference resolution from the plan: cell = 160x135, block = 800x540. */
    private val width = 2400f
    private val height = 1080f
    private val layout = DrivingLayout.sequential

    @Test
    fun `a 1x1 cell is 160x135 at the reference resolution`() {
        val cell = BlockGeometry.cellSize(width, height)

        assertEquals(160f, cell.width, 0.01f)
        assertEquals(135f, cell.height, 0.01f)
    }

    @Test
    fun `a button fills its cell exactly`() {
        val button = requireNotNull(layout.slotAt(CellRect(7, 5, 1, 1)))

        val box = button.rect.toPixels(width, height)

        assertEquals(160f, box.width, 0.01f)
        assertEquals(135f, box.height, 0.01f)
    }

    @Test
    fun `the corner cells sit flush against the screen edges`() {
        // TODO.md Dashboard 3: no padding alongside the screen, so the blocks
        // and the cells inside them reach the edge.
        val topLeft = requireNotNull(layout.slotAt(CellRect(1, 1, 1, 1))).rect.toPixels(width, height)
        val topRight = requireNotNull(layout.slotAt(CellRect(1, 15, 1, 1))).rect.toPixels(width, height)
        val bottomLeft = requireNotNull(layout.slotAt(CellRect(8, 1, 1, 1))).rect.toPixels(width, height)
        // The freed column is a hole, and a hole is flush with the edge too.
        val bottomRight = requireNotNull(layout.slotAt(CellRect(8, 15, 1, 1))).rect.toPixels(width, height)

        assertEquals(0f, topLeft.left, 0.01f)
        assertEquals(0f, topLeft.top, 0.01f)
        assertEquals(width, topRight.right, 0.01f)
        assertEquals(0f, topRight.top, 0.01f)
        assertEquals(0f, bottomLeft.left, 0.01f)
        assertEquals(height, bottomLeft.bottom, 0.01f)
        assertEquals(width, bottomRight.right, 0.01f)
        assertEquals(height, bottomRight.bottom, 0.01f)
    }

    @Test
    fun `the wheel box is square at the block height, centered, flush bottom`() {
        // Wheel slot: global rows 5-8, cols 1-4 -> 640x540 at the reference.
        val slot = CellRect(5, 1, 4, 4).toPixels(width, height)
        assertEquals(640f, slot.width, 0.01f)
        assertEquals(540f, slot.height, 0.01f)

        val box = wheelBox(slot)

        assertEquals(540f, box.width, 0.01f)
        assertEquals(540f, box.height, 0.01f)
        // Horizontally centered with equal margins.
        assertEquals(50f, box.left - slot.left, 0.01f)
        assertEquals(50f, slot.right - box.right, 0.01f)
        // Flush with the slot's bottom edge.
        assertEquals(slot.bottom, box.bottom, 0.01f)
    }

    @Test
    fun `the pedal group splits into two flush-bottom bars with a gap between`() {
        // TODO.md Dashboard 2: one 4x3 group, global rows 5-8, cols 12-14.
        val group = CellRect(5, 12, 4, 3).toPixels(width, height)
        assertEquals(480f, group.width, 0.01f)
        assertEquals(540f, group.height, 0.01f)
        assertEquals(1080f, group.bottom, 0.01f)

        val (brake, accelerator) = pedalGroupBars(group)

        // Bars run the full block height, flush with the screen's bottom edge.
        assertEquals(group.height, brake.height, 0.01f)
        assertEquals(1080f, brake.bottom, 0.01f)
        assertEquals(group.height, accelerator.height, 0.01f)
        assertEquals(1080f, accelerator.bottom, 0.01f)
        // The 8px inset lives inside each bar, between adjacent slots.
        assertEquals(group.left + BlockGeometry.CELL_PADDING_PX, brake.left, 0.01f)
        assertEquals(group.right - BlockGeometry.CELL_PADDING_PX, accelerator.right, 0.01f)
        assertEquals(BlockGeometry.CELL_PADDING_PX, accelerator.left - brake.right, 0.01f)
        // Accelerator is right-most, and both stay inside the group.
        assertTrue(accelerator.right > brake.right)
        assertEquals(brake.width, accelerator.width, 0.01f)
    }

    @Test
    fun `blocks are padded apart but flush with the screen edges`() {
        // TODO.md Dashboard 3: gaps between blocks, none along the screen.
        val a = DrivingLayout.blockA.toPaddedPixels(width, height)
        val b = DrivingLayout.blockB.toPaddedPixels(width, height)
        val c = DrivingLayout.blockC.toPaddedPixels(width, height)
        val d = DrivingLayout.blockD.toPaddedPixels(width, height)

        // Top-left block: flush on the top and left edges, padded on the rest.
        assertEquals(0f, a.left, 0.01f)
        assertEquals(0f, a.top, 0.01f)
        assertEquals(width, c.right, 0.01f)
        assertEquals(height, d.bottom, 0.01f)
        // The top band is flush to the top edge, the bottom band to the bottom.
        assertEquals(0f, b.top, 0.01f)
        assertEquals(height, d.bottom, 0.01f)

        // Every neighbouring pair is separated by the padding.
        assertEquals(BlockGeometry.BLOCK_PADDING_PX, b.left - a.right, 0.01f)
        assertEquals(BlockGeometry.BLOCK_PADDING_PX, c.left - b.right, 0.01f)
        assertEquals(BlockGeometry.BLOCK_PADDING_PX, d.top - a.bottom, 0.01f)
    }

    @Test
    fun `an inner block is padded on all four sides`() {
        val e = DrivingLayout.blockE.toPaddedPixels(width, height)
        val half = BlockGeometry.BLOCK_PADDING_PX / 2

        assertEquals(5 * 160f + half, e.left, 0.01f)
        assertEquals(4 * 135f + half, e.top, 0.01f)
        assertEquals(10 * 160f - half, e.right, 0.01f)
        // Block E sits in the bottom band, so it is flush with the bottom edge.
        assertEquals(height, e.bottom, 0.01f)
        assertEquals(5 * 160f - 2 * half, e.width, 0.01f)
        // Only the top is inset: the bottom is the screen edge.
        assertEquals(135f * 4 - half, e.height, 0.01f)
    }

    @Test
    fun `the camera pad fills its three by three slot`() {
        val pad = requireNotNull(layout.slotAt(CellRect(1, 13, 1, 1)))
        assertEquals(SlotKind.CameraPad, pad.kind)

        val box = pad.rect.toPixels(width, height)

        assertEquals(3 * 160f, box.width, 0.01f)
        assertEquals(3 * 135f, box.height, 0.01f)
    }

    @Test
    fun `a hole takes the same cell box as a control`() {
        // TODO.md Dashboard 1 and 2 freed these cells; they must still occupy
        // their cell so the grid stays covered.
        val hole = requireNotNull(layout.slotAt(CellRect(1, 12, 1, 1)))
        val button = requireNotNull(layout.slotAt(CellRect(1, 10, 1, 1)))
        assertEquals(SlotKind.Hole, hole.kind)
        val holeBox = hole.rect.toPixels(width, height)
        val buttonBox = button.rect.toPixels(width, height)
        assertEquals(buttonBox.width, holeBox.width, 0.01f)
        assertEquals(buttonBox.height, holeBox.height, 0.01f)
    }
}
