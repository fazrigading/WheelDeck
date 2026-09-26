package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.circularDelta
import dev.fazrigading.wheeldeck.data.services.mapRotationToSteering
import dev.fazrigading.wheeldeck.data.services.springBackDurationMs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.atan2

/// Touch state of the rotatable steering wheel, with no Compose in it.
///
/// Dragging around the center accumulates clockwise-positive rotation;
/// [degrees] of finger rotation (the selected lock-to-lock range) maps to full
/// steering via [mapRotationToSteering]. On release the wheel either holds its
/// angle or unwinds to zero at [dev.fazrigading.wheeldeck.data.services.SPRING_BACK_DEGREES_PER_SECOND]
/// — a constant rate at every lock-to-lock setting (TODO.md Controls).
///
/// The Composable only forwards pointer positions and renders
/// [accumulatedDegrees]; every rule lives here so it is testable without a
/// device.
class RotatableWheelModel(
    degrees: Int,
    private val springBack: Boolean,
    private val onChanged: (Double) -> Unit,
    scope: CoroutineScope,
    private val frameMs: Long = FRAME_MS,
) {
    init {
        require(degrees > 0) { "degrees must be positive" }
    }

    private val job = SupervisorJob(scope.coroutineContext[Job])
    private val scope = CoroutineScope(scope.coroutineContext + job)

    private val _state = MutableStateFlow(RotatableWheelState(degrees = degrees))

    /// Accumulated rotation, the steering it maps to, and the readout. The
    /// Composable collects this; [onChanged] carries the steering onward to the
    /// network.
    val state: StateFlow<RotatableWheelState> = _state.asStateFlow()

    /// Selected lock-to-lock range in degrees.
    val degrees: Int get() = _state.value.degrees

    /// Accumulated finger rotation, clockwise positive, clamped to half-range.
    val accumulatedDegrees: Double get() = _state.value.accumulatedDegrees

    /// Normalized steering for the current rotation, -1.0..1.0.
    val steering: Double get() = _state.value.steering

    private var lastTouchAngle: Double? = null
    private var springJob: Job? = null
    private var springStart = 0.0

    /// Changes the lock-to-lock range. Keeps the current rotation, re-clamped.
    fun setDegrees(value: Int) {
        require(value > 0) { "degrees must be positive" }
        _state.value = _state.value.copy(degrees = value).reclamped()
    }

    /// A new drag takes over from wherever the spring-back currently is.
    fun onTouchStart(x: Double, y: Double, size: Double) {
        cancelSpringBack()
        lastTouchAngle = touchAngle(x, y, size)
    }

    /// Accumulates the shortest-arc rotation since the last event. Clockwise
    /// motion decreases the math-convention angle, so it is negated to keep
    /// rotation — and steering — clockwise positive. Clamped to half-range:
    /// anything beyond is full lock, with no dead unwind.
    fun onTouchMove(x: Double, y: Double, size: Double) {
        val last = lastTouchAngle ?: return
        val now = touchAngle(x, y, size)
        _state.value = _state.value
            .withAccumulated(_state.value.accumulatedDegrees - circularDelta(last, now))
        lastTouchAngle = now
        onChanged(steering)
    }

    /// Ends the drag. With spring-back off the released angle is held and
    /// steering stays there until the driver drags back; with it on the wheel
    /// unwinds to zero and reports 0.0 on completion.
    fun onTouchEnd() {
        lastTouchAngle = null
        if (!springBack) {
            onChanged(steering)
            return
        }
        if (accumulatedDegrees == 0.0) {
            onChanged(0.0)
            return
        }
        cancelSpringBack()
        springStart = accumulatedDegrees
        val totalMs = springBackDurationMs(springStart)
        springJob = scope.launch {
            var elapsed = 0L
            while (elapsed < totalMs) {
                delay(frameMs)
                elapsed += frameMs
                val progress = (elapsed.toDouble() / totalMs).coerceIn(0.0, 1.0)
                // Linear, so the wheel really does unwind at a constant rate.
                _state.value = _state.value.withAccumulated(springStart * (1.0 - progress))
                // Report per frame, so the desktop's steering tracks the visual
                // instead of freezing at the released angle until completion.
                onChanged(steering)
            }
            springJob = null
            _state.value = _state.value.withAccumulated(0.0)
            onChanged(0.0)
        }
    }

    /// Stops the spring-back and drops the touch tracking. The wheel keeps its
    /// accumulated angle; a new drag resumes from there.
    fun dispose() {
        cancelSpringBack()
        lastTouchAngle = null
    }

    private fun cancelSpringBack() {
        springJob?.cancel()
        springJob = null
    }

    companion object {
        /// Animation frame interval of the return, matching the Dart app.
        const val FRAME_MS = 16L

        /// Angle in degrees of a touch at ([x], [y]) within a [size]-wide box,
        /// zero at three o'clock, positive anticlockwise.
        fun touchAngle(x: Double, y: Double, size: Double): Double =
            atan2(size / 2 - y, x - size / 2) * 180 / PI

    }

}

/// One frame of the rotatable wheel: how far it is turned, what that maps to,
/// and what the degree readout says.
data class RotatableWheelState(
    val degrees: Int,
    val accumulatedDegrees: Double = 0.0,
) {
    /// Normalized steering for [accumulatedDegrees], -1.0..1.0.
    val steering: Double get() = mapRotationToSteering(accumulatedDegrees, degrees)

    /// The degree readout shown on the wheel. Rounds halves away from zero, as
    /// the Dart app's `round()` does.
    val readout: String get() = "${roundHalfAwayFromZero(accumulatedDegrees)}\u00b0"

    /// Copy with a new rotation, clamped to half-range: past full lock the wheel
    /// stays pinned, with no dead unwind.
    fun withAccumulated(value: Double): RotatableWheelState {
        val halfRange = degrees / 2.0
        return copy(accumulatedDegrees = value.coerceIn(-halfRange, halfRange))
    }

    /// Re-applies the clamp after the lock-to-lock range changed.
    fun reclamped(): RotatableWheelState = withAccumulated(accumulatedDegrees)
}

/// Rounds half away from zero, matching Dart's `num.round()` rather than Kotlin's
/// half-up `round()`.
internal fun roundHalfAwayFromZero(value: Double): Int {
    val magnitude = kotlin.math.abs(value)
    val rounded = kotlin.math.floor(magnitude + 0.5)
    return if (value < 0) -rounded.toInt() else rounded.toInt()
}
