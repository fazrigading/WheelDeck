package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.PI

/// Finger-drag circular steering wheel for rotatable mode.
///
/// Dragging around the center accumulates clockwise-positive rotation;
/// [degrees] of finger rotation maps to full steering. On release the wheel
/// unwinds to zero at a constant rate, or holds its angle when [springBack] is
/// off. All of that lives in [RotatableWheelModel]; this only forwards pointer
/// positions and draws the wheel, the progress arc, and the degree readout.
@Composable
fun RotatableWheel(
    degrees: Int,
    onChanged: (Double) -> Unit,
    modifier: Modifier = Modifier,
    diameter: Dp = 280.dp,
    springBack: Boolean = true,
) {
    val scope = rememberCoroutineScope()
    val model = remember {
        RotatableWheelModel(
            degrees = degrees,
            springBack = springBack,
            onChanged = onChanged,
            scope = scope,
        )
    }
    val wheel = model.state.collectAsState().value

    // A lock-to-lock change re-clamps in place; it must not drop the rotation.
    LaunchedEffect(model, degrees) { model.setDegrees(degrees) }
    DisposableEffect(model) { onDispose { model.dispose() } }

    Box(
        modifier = modifier
            .size(diameter)
            .pointerInput(model) {
                val sidePx = size.width.toDouble()
                detectDragGestures(
                    onDragStart = { offset ->
                        model.onTouchStart(offset.x.toDouble(), offset.y.toDouble(), sidePx)
                    },
                    onDrag = { change, _ ->
                        change.consume()
                        model.onTouchMove(
                            change.position.x.toDouble(),
                            change.position.y.toDouble(),
                            sidePx,
                        )
                    },
                    onDragEnd = { model.onTouchEnd() },
                    onDragCancel = { model.onTouchEnd() },
                )
            }
            .semantics { contentDescription = "Rotatable steering wheel" },
        contentAlignment = Alignment.Center,
    ) {
        // Rotation is 1:1 with the finger while dragging; the return drives the
        // same state per frame, so the visual and the reported steering stay
        // coherent.
        WheelGraphic(
            turns = wheel.accumulatedDegrees * PI / 180,
            modifier = Modifier.size(diameter),
        )
        RotationArc(steering = wheel.steering, modifier = Modifier.size(diameter))
        Text(
            text = wheel.readout,
            modifier = Modifier.align(Alignment.BottomCenter),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
