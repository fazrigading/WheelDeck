package dev.fazrigading.wheeldeck.data.services

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlin.math.PI

/// Captures and normalizes the phone's steering rotation.
///
/// Raw gyroscope yaw is centered and scaled here so the wheel widget and the
/// network client both consume an already-calibrated -1.0..1.0 value.
class SteeringSensor(
    private val rawAngleStream: Flow<Double>,
    private val maxRotationAngle: Double = PI / 4,
) {
    init {
        require(maxRotationAngle > 0) { "maxRotationAngle must be positive" }
    }

    private companion object {
        const val MIN_SENSITIVITY = 0.05
    }

    private var subscription: Job? = null
    private var center = 0.0
    private var lastRawAngle = 0.0
    private var sensitivity = 1.0
    private var onAngleChanged: ((Double) -> Unit)? = null

    /// Registers the callback that receives the normalized steering angle.
    fun onAngleChanged(callback: (Double) -> Unit) {
        onAngleChanged = callback
    }

    /// Starts sampling raw gyroscope yaw inside [scope].
    fun start(scope: CoroutineScope) {
        if (subscription != null) return
        subscription = scope.launch {
            rawAngleStream.collect { raw ->
                lastRawAngle = raw
                recompute()
            }
        }
    }

    /// Stops sampling and cancels the underlying subscription.
    fun stop() {
        subscription?.cancel()
        subscription = null
    }

    /// Captures the current orientation as straight ahead.
    fun setCenter() {
        center = lastRawAngle
        recompute()
    }

    /// Sets how much physical rotation maps to full lock. Higher values make
    /// the wheel respond more to the same rotation.
    fun setSensitivity(value: Double) {
        sensitivity = if (value < MIN_SENSITIVITY) MIN_SENSITIVITY else value
        recompute()
    }

    private fun recompute() {
        val delta = lastRawAngle - center
        val normalized = (delta * sensitivity / maxRotationAngle).coerceIn(-1.0, 1.0)
        onAngleChanged?.invoke(normalized)
    }
}
