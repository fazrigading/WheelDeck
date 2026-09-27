package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.fazrigading.wheeldeck.data.services.ROTATION_ARC_START_RADIANS
import dev.fazrigading.wheeldeck.data.services.rotationArcFillRadians
import kotlin.math.PI

/// Full-lock visible wheel rotation, in radians.
const val DEFAULT_MAX_WHEEL_ROTATION = PI / 2

/// Turns of visible rotation for a normalized [angle]. Full lock maps to
/// [maxWheelRotation] radians so the graphic stays readable; out-of-range
/// angles clamp at full lock.
fun wheelTurns(angle: Double, maxWheelRotation: Double = DEFAULT_MAX_WHEEL_ROTATION): Double =
    (angle.coerceIn(-1.0, 1.0) * maxWheelRotation) / (2 * PI)

/// The on-screen steering wheel, rotating with the normalized steering angle
/// the gyro produces.
@Composable
fun WheelView(
    angle: Double,
    modifier: Modifier = Modifier,
    maxWheelRotation: Double = DEFAULT_MAX_WHEEL_ROTATION,
    size: Dp = 280.dp,
) {
    val turns by animateFloatAsState(
        targetValue = wheelTurns(angle, maxWheelRotation).toFloat(),
        label = "wheel-turns",
    )
    Box(modifier = modifier.size(size), contentAlignment = Alignment.Center) {
        WheelGraphic(turns = turns.toDouble(), modifier = Modifier.size(size))
    }
}

/// The wheel rim, spokes, and top marker. Shared by the gyro wheel and the
/// rotatable wheel.
@Composable
fun WheelGraphic(turns: Double = 0.0, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        rotate(degrees = turns.toFloat(), pivot = center) {
            val radius = size.minDimension / 2 - 8.dp.toPx()
            val center = Offset(size.width / 2, size.height / 2)
            val spokeReach = (radius - 20.dp.toPx()).coerceAtLeast(0f)

            drawCircle(
                color = Color(0xFF3A3A3A),
                radius = radius,
                center = center,
                style = Stroke(width = 18.dp.toPx()),
            )
            drawCircle(color = Color(0xFF1E1E1E), radius = radius - 14.dp.toPx(), center = center)
            val spoke = Color(0xFFB0B0B0)
            val spokeWidth = 6.dp.toPx()
            drawLine(spoke, center - Offset(spokeReach, 0f), center + Offset(spokeReach, 0f), spokeWidth)
            drawLine(spoke, center - Offset(0f, spokeReach), center + Offset(0f, spokeReach), spokeWidth)
            drawCircle(
                color = Color(0xFFE53935),
                radius = 6.dp.toPx(),
                center = center - Offset(0f, spokeReach),
            )
        }
    }
}

/// Progress arc over the top half of the ring, tracking steering. The fill
/// starts at twelve o'clock and grows toward the turned side; zero steering
/// fills nothing.
@Composable
fun RotationArc(steering: Double, modifier: Modifier = Modifier, strokeWidth: Dp = 4.dp) {
    Canvas(modifier = modifier) {
        val radius = size.minDimension / 2 - 8.dp.toPx()
        val center = Offset(size.width / 2, size.height / 2)
        val arcSize = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
        val topLeft = Offset(center.x - radius, center.y - radius)
        val width = strokeWidth.toPx()

        drawArc(
            color = Color(0xFF555555),
            startAngle = PI.toFloat(),
            sweepAngle = PI.toFloat(),
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(width = width, cap = androidx.compose.ui.graphics.StrokeCap.Round),
        )
        val fill = rotationArcFillRadians(steering).toFloat()
        if (fill == 0f) return@Canvas
        drawArc(
            color = Color(0xFFE53935),
            startAngle = ROTATION_ARC_START_RADIANS.toFloat(),
            sweepAngle = fill,
            useCenter = false,
            topLeft = topLeft,
            size = arcSize,
            style = Stroke(width = width, cap = androidx.compose.ui.graphics.StrokeCap.Round),
        )
    }
}
