package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/// Where the tilt marker sits along the track, 0.0 at the left edge and 1.0 at
/// the right, for a normalized [angle] of -1.0..1.0. Out-of-range angles clamp
/// at full lock.
fun tiltMarkerFraction(angle: Double): Float =
    ((angle.coerceIn(-1.0, 1.0) + 1.0) / 2.0).toFloat()

/// Steering-angle track with a marker positioned by the normalized angle.
/// Shown in gyro mode, under the wheel when the dashboard is hidden and
/// top-center when it is shown.
@Composable
fun TiltReadout(
    angle: Double,
    modifier: Modifier = Modifier,
    trackWidth: Dp = 160.dp,
    trackHeight: Dp = 24.dp,
) {
    val fraction = tiltMarkerFraction(angle)
    Box(
        modifier = modifier
            .size(width = trackWidth, height = trackHeight)
            .clip(RoundedCornerShape(percent = 50))
            .background(Color(0xFF37474F))
            .border(2.dp, Color(0xFF90A4AE), RoundedCornerShape(percent = 50))
            .semantics { contentDescription = "Tilt readout" },
        contentAlignment = Alignment.Center,
    ) {
        // Center tick, so the marker's offset reads against a fixed reference.
        Box(
            Modifier
                .width(2.dp)
                .height(12.dp)
                .background(Color.White.copy(alpha = 0.3f)),
        )
        // Weighted spacers push the marker to its fraction without a custom
        // layout. At the extremes the marker's center sits one marker-radius in
        // from the edge, so the dot never clips.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(Modifier.weight(fraction.coerceAtLeast(0f)))
            Box(
                Modifier
                    .size(12.dp)
                    .clip(RoundedCornerShape(percent = 50))
                    .background(Color(0xFFFFB300))
                    .semantics { contentDescription = "Tilt marker" },
            )
            Spacer(Modifier.weight((1f - fraction).coerceAtLeast(0f)))
        }
    }
}
