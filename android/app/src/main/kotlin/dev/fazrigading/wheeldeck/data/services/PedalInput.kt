package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.PedalState
import dev.fazrigading.wheeldeck.domain.models.PedalType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.pow

/// Easing applied to the spring-back progress; all three map 0.0..1.0 to
/// 0.0..1.0.
enum class ReleaseCurve {
    Linear,
    EaseOut,
    EaseInOut,
}

/// Maps touch drag positions to analog pedal pressure and animates the
/// spring-back release when a pedal is let go.
///
/// [state] is the observable source of truth — pedals, controllers, and the
/// state frame all read it. The release animation runs on the injected scope,
/// which defaults to the main dispatcher because emissions drive Compose
/// state, the same thread the Dart app's timers fired on.
class PedalInput(
    scope: CoroutineScope = CoroutineScope(Dispatchers.Main.immediate),
    private val releaseDurationMs: Long = 300,
    private val clock: () -> Double = { System.nanoTime() / 1_000_000_000.0 },
) {
    // Owns the job it launches in, so dispose() never touches the caller's
    // scope.
    private val job = SupervisorJob(scope.coroutineContext[Job])
    private val scope = CoroutineScope(scope.coroutineContext + job)

    private val _state = MutableStateFlow(PedalState.released)
    private val releaseJobs = PedalType.entries.associateWith { null as Job? }.toMutableMap()
    private var releaseCurve = ReleaseCurve.Linear

    /// Current pressures, each 0.0 (rest) .. 1.0 (full press).
    val state: StateFlow<PedalState> = _state.asStateFlow()

    /// Selects the spring-back curve used when a pedal is released.
    fun setReleaseCurve(curve: ReleaseCurve) {
        releaseCurve = curve
    }

    /// Reports the current pressure of a pedal in the 0.0..1.0 range.
    fun pressureOf(pedal: PedalType): Double = _state.value[pedal]

    /// Sets the pressure directly while the user drags the pedal bar.
    fun setPressure(pedal: PedalType, pressure: Double) {
        cancelRelease(pedal)
        _state.update { it.with(pedal, pressure.coerceIn(0.0, 1.0)) }
    }

    /// Releases the pedal so it springs back toward rest.
    fun release(pedal: PedalType) {
        val start = pressureOf(pedal)
        if (start <= 0.0) return
        cancelRelease(pedal)
        if (releaseDurationMs <= 0L) {
            _state.update { it.with(pedal, 0.0) }
            return
        }
        val startedAt = clock()
        val durationSec = releaseDurationMs / 1000.0
        releaseJobs[pedal] = scope.launch {
            while (true) {
                delay(RELEASE_TICK_MS)
                val progress = ((clock() - startedAt) / durationSec).coerceIn(0.0, 1.0)
                if (progress >= 1.0) break
                _state.update { it.with(pedal, start * (1.0 - applyCurve(progress))) }
            }
            _state.update { it.with(pedal, 0.0) }
        }
    }

    /// Cancels any active release animations and every animation after this
    /// call. The injected scope is left alone.
    fun dispose() {
        job.cancel()
        releaseJobs.clear()
    }

    private fun applyCurve(progress: Double): Double = when (releaseCurve) {
        ReleaseCurve.Linear -> progress
        ReleaseCurve.EaseOut -> 1.0 - (1.0 - progress).pow(2)
        ReleaseCurve.EaseInOut -> progress * progress * (3.0 - 2.0 * progress)
    }

    private fun cancelRelease(pedal: PedalType) {
        releaseJobs[pedal]?.cancel()
        releaseJobs[pedal] = null
    }

    private companion object {
        /// Frame interval of the release animation, matching the Dart app.
        const val RELEASE_TICK_MS = 16L
    }
}
