package dev.fazrigading.wheeldeck.ui.core

import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/// How a control reacts to a touch. Single source of truth for every cell.
enum class ControlMode {
    /// Tap sends one toggle pulse; no press or release.
    Toggle,

    /// Tap sends press then release; a hold longer than
    /// [ControlPress.holdDurationMs] still only sends the release.
    Momentary,

    /// Only a completed hold sends `hold_confirm`; a short tap sends nothing.
    HoldConfirm,

    /// A short tap sends press and release; a completed hold fires
    /// [ControlPress.onHoldCompleted] instead and suppresses the press.
    TapOrHold,
}

/// Pointer state of one control cell, with no Compose in it.
///
/// Owns the press/release/hold timing so the grid and the camera pad can both
/// render it: a Composable forwards pointer down/up/cancel and draws
/// [pressed] and [holdProgress].
class ControlPress(
    private val mode: ControlMode,
    private val control: ControlId?,
    private val holdDurationMs: Long = DEFAULT_HOLD_MS,
    private val activate: (ControlId, ActionType) -> Unit,
    private val onHoldCompleted: (() -> Unit)? = null,
    scope: CoroutineScope,
    private val frameMs: Long = FRAME_MS,
) {
    private val job = SupervisorJob(scope.coroutineContext[Job])
    private val scope = CoroutineScope(scope.coroutineContext + job)

    private val _pressed = MutableStateFlow(false)
    private val _holdProgress = MutableStateFlow(0f)

    /// True while a finger is on the cell and the press has not resolved.
    val pressed: StateFlow<Boolean> = _pressed.asStateFlow()

    /// Hold completion progress, 0.0..1.0. Only moves in [ControlMode.TapOrHold].
    val holdProgress: StateFlow<Float> = _holdProgress.asStateFlow()

    private var holdFired = false
    private var holdJob: Job? = null

    /// Toggle cells fire on tap; the others are driven by press down/up.
    fun onTap() {
        if (mode != ControlMode.Toggle) return
        val control = control ?: return
        activate(control, ActionType.Toggle)
    }

    /// Pointer down inside the cell.
    fun onPressDown() {
        if (mode == ControlMode.Toggle) return
        // A cell with no control (a layout hole, or the arrow-mode center) only
        // holds when the hold itself is the point; otherwise nothing happens.
        if (control == null && mode != ControlMode.TapOrHold) return
        _pressed.value = true
        holdFired = false
        when (mode) {
            ControlMode.TapOrHold -> {
                // A null control still holds: the center camera-pad cell
                // switches key set in arrow mode too, where recenter has no
                // wire id. An early release there sends nothing.
                _holdProgress.value = 0f
                holdJob = scope.launch {
                    var elapsed = 0f
                    while (elapsed < holdDurationMs) {
                        delay(frameMs)
                        elapsed += frameMs
                        val progress = (elapsed.toDouble() / holdDurationMs)
                            .coerceIn(0.0, 1.0)
                            .toFloat()
                        _holdProgress.value = progress
                        if (progress >= 1f) break
                    }
                    fireHold()
                }
            }
            ControlMode.HoldConfirm -> {
                val control = control ?: return
                holdJob = scope.launch {
                    delay(holdDurationMs)
                    if (_pressed.value) activate(control, ActionType.HoldConfirm)
                }
            }
            else -> {
                val control = control ?: return
                activate(control, ActionType.Press)
            }
        }
    }

    /// Pointer up inside the cell.
    fun onPressUp() {
        val wasPressed = _pressed.value
        cancelHold()
        if (!wasPressed) return
        _pressed.value = false

        when (mode) {
            ControlMode.TapOrHold -> {
                if (!holdFired) {
                    // A short tap is a complete press-and-release, so the game
                    // never sees a stuck key.
                    val control = control ?: return
                    activate(control, ActionType.Press)
                    activate(control, ActionType.Release)
                }
            }
            ControlMode.Momentary -> {
                val control = control ?: return
                activate(control, ActionType.Release)
            }
            ControlMode.HoldConfirm, ControlMode.Toggle -> Unit
        }
    }

    /// The gesture left the cell: a tap-or-hold press is cancelled outright, so
    /// no press and no hold reach the game. Other modes settle as a release.
    fun onPressCancel() {
        if (mode != ControlMode.TapOrHold) {
            onPressUp()
            return
        }
        cancelHold()
        _pressed.value = false
    }

    /// Stops the hold timer and clears the progress bar. Terminal for this cell.
    fun dispose() {
        job.cancel()
        _holdProgress.value = 0f
    }

    private fun fireHold() {
        if (holdFired || !_pressed.value) return
        holdFired = true
        _holdProgress.value = 1f
        holdJob = null
        onHoldCompleted?.invoke()
    }

    private fun cancelHold() {
        holdJob?.cancel()
        holdJob = null
        _holdProgress.value = 0f
    }

    companion object {
        /// Hold window of a camera-pad center cell: three seconds (REQ-017).
        const val CAMERA_PAD_HOLD_MS = 3000L

        /// Default hold window elsewhere, matching the Dart app.
        const val DEFAULT_HOLD_MS = 500L

        /// Progress tick interval, matching the animation frame.
        const val FRAME_MS = 16L

        /// Which mode a control uses.
        fun modeFor(control: ControlId): ControlMode = when (control) {
            ControlId.TurnSignalLeft,
            ControlId.TurnSignalRight,
            ControlId.HeadlightToggle,
            ControlId.HighBeamToggle,
            ControlId.CruiseToggle,
            ControlId.HazardLights,
            ControlId.BeaconLights,
            ControlId.Trailer,
            ControlId.LiftDropAxle,
            ControlId.EngineBrake,
            ControlId.DifferentialLock,
            -> ControlMode.Toggle

            ControlId.EngineStart -> ControlMode.HoldConfirm
            else -> ControlMode.Momentary
        }
    }
}
