package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.DashboardInput
import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.ui.core.ControlMode
import dev.fazrigading.wheeldeck.ui.core.ControlPress

/// Glyph each of the nine dpad cells renders, row-major.
private val DPAD_GLYPHS = listOf("↖", "↑", "↗", "←", "", "→", "↙", "↓", "↘")

/// What a dpad cell is: a direction that sends a control, the center cell, or an
/// inert cell (the arrow-mode diagonals, which carry no wire identifiers).
enum class CameraPadCellKind { Direction, Center, Inert }

/// The control a direction cell sends in [mode], or null where the cell is
/// inert: the diagonals in arrow mode, and the center's press in arrow mode
/// (recenter is a numpad-set key).
fun cameraPadControlAt(row: Int, col: Int, mode: CameraPadMode): ControlId? {
    val center = row == 1 && col == 1
    if (center) return if (mode == CameraPadMode.Numpad) ControlId.CameraPadRecenter else null
    val diagonal = (row == 0 || row == 2) && (col == 0 || col == 2)
    if (mode == CameraPadMode.Arrow && diagonal) return null
    return when (mode) {
        CameraPadMode.Numpad -> when (row to col) {
            0 to 0 -> ControlId.CameraPadUpLeft
            0 to 1 -> ControlId.CameraPadUp
            0 to 2 -> ControlId.CameraPadUpRight
            1 to 0 -> ControlId.CameraPadLeft
            1 to 2 -> ControlId.CameraPadRight
            2 to 0 -> ControlId.CameraPadDownLeft
            2 to 1 -> ControlId.CameraPadDown
            2 to 2 -> ControlId.CameraPadDownRight
            else -> null
        }
        CameraPadMode.Arrow -> when (row to col) {
            0 to 1 -> ControlId.CameraPadArrowUp
            1 to 0 -> ControlId.CameraPadArrowLeft
            1 to 2 -> ControlId.CameraPadArrowRight
            2 to 1 -> ControlId.CameraPadArrowDown
            else -> null
        }
    }
}

/// The kind of cell at ([row], [col]) in [mode].
fun cameraPadCellKind(row: Int, col: Int, mode: CameraPadMode): CameraPadCellKind = when {
    row == 1 && col == 1 -> CameraPadCellKind.Center
    cameraPadControlAt(row, col, mode) != null -> CameraPadCellKind.Direction
    else -> CameraPadCellKind.Inert
}

/// The label a dpad cell renders: the glyph for directions, `NUM`/`ARR` on the
/// center, empty for the inert cells.
fun cameraPadLabel(row: Int, col: Int, mode: CameraPadMode): String = when (cameraPadCellKind(row, col, mode)) {
    CameraPadCellKind.Center -> if (mode == CameraPadMode.Numpad) "NUM" else "ARR"
    CameraPadCellKind.Direction -> DPAD_GLYPHS[row * 3 + col]
    CameraPadCellKind.Inert -> ""
}

/// Whether a cell sends anything at all: the center always does (it is the hold
/// surface for the mode switch), the inert cells never do, and a direction cell
/// only when its binding is set.
fun cameraPadCellEnabled(
    control: ControlId?,
    kind: CameraPadCellKind,
    bindingFor: (ControlId) -> String,
) = kind == CameraPadCellKind.Center ||
    (control != null && !DashboardSendGate.isUnbound(bindingFor(control)))

/// The rotatable block C camera pad: a 3x3 of direction cells around a center
/// cell whose three-second hold switches the pad's key set. In numpad mode the
/// pad sends the numpad block; in arrow mode the arrow keys, with the diagonals
/// disabled (REQ-017).
///
/// The simple and analog shapes need `CameraControlType`, which lands with the
/// camera-type settings in Task 12.
@Composable
fun CameraPad(
    mode: CameraPadMode,
    input: DashboardInput,
    bindingFor: (ControlId) -> String,
    onModeSwitch: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        for (row in 0..2) {
            Row(Modifier.fillMaxWidth().weight(1f)) {
                for (col in 0..2) {
                    CameraPadCell(
                        label = cameraPadLabel(row, col, mode),
                        control = cameraPadControlAt(row, col, mode),
                        kind = cameraPadCellKind(row, col, mode),
                        input = input,
                        bindingFor = bindingFor,
                        onModeSwitch = onModeSwitch,
                        modifier = Modifier.weight(1f).fillMaxSize(),
                    )
                }
            }
        }
    }
}

/// One pad cell. The center is always live — it is the hold surface for the mode
/// switch — while inert direction cells render disabled. Unbound sends are
/// suppressed by the send gate.
@Composable
private fun CameraPadCell(
    label: String,
    control: ControlId?,
    kind: CameraPadCellKind,
    input: DashboardInput,
    bindingFor: (ControlId) -> String,
    onModeSwitch: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val center = kind == CameraPadCellKind.Center
    val press = remember(control, center) {
        ControlPress(
            mode = if (center) ControlMode.TapOrHold else ControlMode.Momentary,
            control = control,
            holdDurationMs = ControlPress.CAMERA_PAD_HOLD_MS,
            activate = { c, a -> input.activate(c, a) },
            onHoldCompleted = onModeSwitch,
            scope = scope,
        )
    }
    val pressed by press.pressed.collectAsState()
    val holdProgress by press.holdProgress.collectAsState()
    val live = cameraPadCellEnabled(control, kind, bindingFor)
    // Unbound direction cells render disabled: the send gate drops them, so a
    // live-looking key that never reaches the truck would be a lie.
    val inactive = kind == CameraPadCellKind.Inert || !live

    Box(
        modifier = modifier
            .padding(2.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(
                when {
                    inactive -> Color(0xFF37474F)
                    pressed -> Color(0xFFFFB300)
                    else -> Color(0xFF455A64)
                },
            )
            .border(
                width = if (pressed && live) 3.dp else 2.dp,
                color = if (pressed && live) Color(0xFFFFE082) else Color(0xFF90A4AE),
                shape = RoundedCornerShape(12.dp),
            )
            .semantics {
                contentDescription = when (kind) {
                    CameraPadCellKind.Center -> "Camera pad center"
                    CameraPadCellKind.Direction -> "Camera pad ${control?.wireValue}"
                    CameraPadCellKind.Inert -> "Camera pad disabled"
                }
            }
            .pointerInput(press) {
                if (inactive) return@pointerInput
                // A press gesture, not a drag: it reports down immediately and
                // distinguishes a real release from a cancelled one, which is
                // what the hold timing needs.
                detectTapGestures(
                    onPress = {
                        press.onPressDown()
                        if (tryAwaitRelease()) press.onPressUp() else press.onPressCancel()
                    },
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = if (pressed && live) Color.Black else Color.White,
        )
        if (center && pressed && holdProgress > 0f) {
            LinearProgressIndicator(
                progress = { holdProgress },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(3.dp),
            )
        }
    }
}
