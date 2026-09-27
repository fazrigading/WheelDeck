package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.CellRect
import dev.fazrigading.wheeldeck.data.services.DrivingLayout
import kotlin.math.min

/// One cell of the global grid, in pixels.
data class CellSize(val width: Float, val height: Float)

/// A pixel box: left/top edge plus size.
data class PixelRect(val left: Float, val top: Float, val width: Float, val height: Float) {
    val right: Float get() = left + width
    val bottom: Float get() = top + height
}

/// Pixel geometry of the rotatable grid: the 8x15 cell grid, the six blocks, and
/// the padding between them.
object BlockGeometry {
    /// Gap between neighbouring blocks, on the sides that are not screen edges
    /// (TODO.md Dashboard 3). Blocks on an edge stay flush with it.
    const val BLOCK_PADDING_PX = 8f

    /// Horizontal gap between adjacent pedal bars inside a block. No other
    /// slot is inset: cells fill their rect.
    const val CELL_PADDING_PX = 8f

    /// One cell: the surface split into the global grid.
    fun cellSize(width: Float, height: Float) =
        CellSize(width = width / DrivingLayout.GRID_COLS, height = height / DrivingLayout.GRID_ROWS)
}

/// The pixel box of [rect] on a [width] x [height] surface. Cells fill their
/// rect exactly, so the box follows the screen-derived cell aspect (CON-001);
/// only the pedal bars take an inset, and that one is horizontal.
fun CellRect.toPixels(
    width: Float,
    height: Float,
    cell: CellSize = BlockGeometry.cellSize(width, height),
) = PixelRect(
    left = (colStart - 1) * cell.width,
    top = (rowStart - 1) * cell.height,
    width = colSpan * cell.width,
    height = rowSpan * cell.height,
)

/// The pixel box of [rect], padded between blocks but flush along the screen
/// edges (TODO.md Dashboard 3): a side already touching the grid edge gets no
/// padding, so the outer blocks bleed to the screen.
fun CellRect.toPaddedPixels(
    width: Float,
    height: Float,
    blockPadding: Float = BlockGeometry.BLOCK_PADDING_PX,
    cell: CellSize = BlockGeometry.cellSize(width, height),
): PixelRect {
    // Half on each side, so two neighbouring blocks end up exactly
    // [blockPadding] apart instead of double it, and the outermost block still
    // reaches the screen edge.
    val left = if (colStart == 1) 0f else blockPadding / 2
    val top = if (rowStart == 1) 0f else blockPadding / 2
    val right = if (colStart + colSpan - 1 == DrivingLayout.GRID_COLS) 0f else blockPadding / 2
    val bottom = if (rowStart + rowSpan - 1 == DrivingLayout.GRID_ROWS) 0f else blockPadding / 2
    return PixelRect(
        left = (colStart - 1) * cell.width + left,
        top = (rowStart - 1) * cell.height + top,
        width = colSpan * cell.width - left - right,
        height = rowSpan * cell.height - top - bottom,
    )
}

/// The wheel's box inside its slot: a square of side [maxSide] centred
/// horizontally and flush with the slot's bottom edge, so the graphic never
/// crops on a wide slot.
fun wheelBox(slot: PixelRect): PixelRect {
    val side = min(slot.width, slot.height)
    return PixelRect(
        left = slot.left + (slot.width - side) / 2,
        top = slot.bottom - side,
        width = side,
        height = side,
    )
}

/// The two bars of a pedal group, brake on the left and accelerator on the
/// right (TODO.md Dashboard 2). Each takes an equal share of the group, inset
/// from the screen edge by [gap] and separated by [gap], and both run the
/// group's full height so they stay flush with the screen's bottom edge.
fun pedalGroupBars(
    group: PixelRect,
    gap: Float = BlockGeometry.CELL_PADDING_PX,
): Pair<PixelRect, PixelRect> {
    val barWidth = (group.width - 3 * gap) / 2
    val brake = PixelRect(group.left + gap, group.top, barWidth, group.height)
    val accelerator = PixelRect(brake.right + gap, group.top, barWidth, group.height)
    return brake to accelerator
}
