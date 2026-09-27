package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.domain.models.PedalType

/// Analog pressure for a touch [offsetY] down a bar [height] tall: 0.0 at the
/// top, 1.0 at the bottom, clamped outside the bar.
fun pedalPressureFromOffset(offsetY: Float, height: Float): Double =
    if (height <= 0f) 0.0 else (offsetY / height).coerceIn(0f, 1f).toDouble()

/// Applies a drag touch to a pedal: maps it to pressure and reports it. Shared
/// by the bar's drag start and its updates, and by the grid's slot-sized
/// renderers.
fun dragPedalTo(
    pedal: PedalType,
    offsetY: Float,
    height: Float,
    onDrag: (PedalType, Double) -> Unit,
): Double = pedalPressureFromOffset(offsetY, height).also { onDrag(pedal, it) }

/// The pedal's hue: blue accelerator, red brake, yellow clutch. Bars are
/// hue-coded instead of labeled.
fun pedalColor(pedal: PedalType): Color = when (pedal) {
    PedalType.Accelerator -> Color(0xFF1E88E5)
    PedalType.Brake -> Color(0xFFE53935)
    PedalType.Clutch -> Color(0xFFFDD835)
}

/// Default bar order, left to right.
val defaultPedalOrder = listOf(PedalType.Clutch, PedalType.Brake, PedalType.Accelerator)

/// Three vertical draggable pedal bars driving [input]. The filled portion grows
/// downward from the top as pressure increases; release springs back.
@Composable
fun PedalPanel(
    input: PedalInput,
    modifier: Modifier = Modifier,
    layout: List<PedalType> = defaultPedalOrder,
) {
    val pedals by input.state.collectAsState()
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        layout.forEach { pedal ->
            PedalBar(
                pedal = pedal,
                pressure = pedals[pedal],
                onDrag = input::setPressure,
                onRelease = input::release,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/// A single vertical pedal bar.
@Composable
fun PedalBar(
    pedal: PedalType,
    pressure: Double,
    onDrag: (PedalType, Double) -> Unit,
    onRelease: (PedalType) -> Unit,
    modifier: Modifier = Modifier,
) {
    val hue = pedalColor(pedal)
    // While dragging, the finger owns the fill: the spring-back animation must
    // not fight the gesture.
    var dragPressure by remember { mutableStateOf<Double?>(null) }
    val shown = (dragPressure ?: pressure).coerceIn(0.0, 1.0)

    Box(
        modifier = modifier
            .fillMaxHeight()
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xFF2A2A2A))
            .background(hue.copy(alpha = 0.25f))
            .semantics { contentDescription = "Pedal ${pedal.name}" }
            .pointerInput(pedal) {
                val barHeight = size.height.toFloat()
                detectVerticalDragGestures(
                    onDragStart = { offset ->
                        dragPressure = dragPedalTo(pedal, offset.y, barHeight, onDrag)
                    },
                    onVerticalDrag = { change, _ ->
                        change.consume()
                        dragPressure = dragPedalTo(pedal, change.position.y, barHeight, onDrag)
                    },
                    onDragEnd = {
                        dragPressure = null
                        onRelease(pedal)
                    },
                    onDragCancel = {
                        dragPressure = null
                        onRelease(pedal)
                    },
                )
            },
    ) {
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .fillMaxHeight(shown.toFloat())
                .background(hue),
        )
    }
}
