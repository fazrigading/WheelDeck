package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/// Headlight stage of the phone-held cycle: each headlight-toggle tap advances
/// it and sends the matching wire id as a toggle pulse.
enum class LightStage { Off, Parking, Low }

/// Observable snapshot of the gate's held state. Blink phase rides along
/// because the signal visuals read it.
data class DashboardGateState(
    val lightStage: LightStage = LightStage.Off,
    val leftOn: Boolean = false,
    val rightOn: Boolean = false,
    val hazardOn: Boolean = false,
    val blinkOn: Boolean = false,
)

/// Phone-held dashboard state machine on the send path.
///
/// Three jobs, one seam:
/// - Drops controls whose per-mode binding is empty (`""` or `"-"`): the
///   phone sends nothing, in both mapping modes.
/// - Holds the headlight cycle OFF-Parking-Low-OFF: each [ControlId.HeadlightToggle]
///   tap advances the stage and sends the matching distinct id
///   ([ControlId.LightsParking] / [ControlId.LightsLowbeam] / [ControlId.LightsOff])
///   as a toggle pulse. High beam passes through untouched.
/// - Holds turn/hazard state with a ~1.5Hz blink phase. Hazard and the
///   individual signals are independent: signals send and blink their own
///   state during hazard. Left and right are mutually exclusive — turning one
///   on clears the other without sending the cleared control's event (ETS2
///   cancels the opposite signal itself).
class DashboardSendGate(
    private val send: (ControlId, ActionType) -> Unit,
    private val bindingFor: (ControlId) -> String,
    scope: CoroutineScope,
    private val autoBlink: Boolean = true,
    private val blinkPhaseMs: Long = DEFAULT_BLINK_PHASE_MS,
) {
    private val _state = MutableStateFlow(DashboardGateState())
    private val job = SupervisorJob(scope.coroutineContext[Job])
    private val scope = CoroutineScope(scope.coroutineContext + job)
    private var blinkJob: Job? = null

    /// Held state, including the current blink phase (true = signals lit).
    val state: StateFlow<DashboardGateState> = _state.asStateFlow()

    val lightStage: LightStage get() = _state.value.lightStage
    val leftOn: Boolean get() = _state.value.leftOn
    val rightOn: Boolean get() = _state.value.rightOn
    val hazardOn: Boolean get() = _state.value.hazardOn
    val blinkOn: Boolean get() = _state.value.blinkOn

    /// Routes one dashboard event: gates, translates, or suppresses it.
    fun handle(control: ControlId, action: ActionType) {
        when (control) {
            ControlId.HeadlightToggle -> {
                val next = when (_state.value.lightStage) {
                    LightStage.Off -> LightStage.Parking
                    LightStage.Parking -> LightStage.Low
                    LightStage.Low -> LightStage.Off
                }
                _state.update { it.copy(lightStage = next) }
                sendIfBound(cycleId(), ActionType.Toggle)
                return
            }
            ControlId.LightsOff -> _state.update { it.copy(lightStage = LightStage.Off) }
            ControlId.LightsParking -> _state.update { it.copy(lightStage = LightStage.Parking) }
            ControlId.LightsLowbeam -> _state.update { it.copy(lightStage = LightStage.Low) }
            ControlId.TurnSignalLeft, ControlId.TurnSignalRight -> if (action == ActionType.Toggle) {
                // Independent of hazard; turning one on clears the other and
                // sends nothing for the cleared side — ETS2 cancels it in game.
                if (control == ControlId.TurnSignalLeft) {
                    _state.update { state ->
                        val left = !state.leftOn
                        state.copy(leftOn = left, rightOn = if (left) false else state.rightOn)
                    }
                } else {
                    _state.update { state ->
                        val right = !state.rightOn
                        state.copy(rightOn = right, leftOn = if (right) false else state.leftOn)
                    }
                }
                syncBlinkTimer()
            }
            ControlId.HazardLights -> if (action == ActionType.Toggle) {
                _state.update { it.copy(hazardOn = !it.hazardOn) }
                syncBlinkTimer()
            }
            else -> Unit
        }
        sendIfBound(control, action)
    }

    /// Whether the signal visual for [control] is lit right now. Hazard drives
    /// both sides; individuals show only their own held state.
    fun signalVisualActive(control: ControlId): Boolean {
        val state = _state.value
        if (!state.blinkOn) return false
        return when (control) {
            ControlId.TurnSignalLeft -> state.hazardOn || state.leftOn
            ControlId.TurnSignalRight -> state.hazardOn || state.rightOn
            ControlId.HazardLights -> state.hazardOn
            else -> false
        }
    }

    /// Flips the blink phase. Driven by the timer; public so tests can drive it.
    fun advanceBlink() = _state.update { it.copy(blinkOn = !it.blinkOn) }

    /// Whether [control]'s per-mode binding is set, i.e. the gate lets it
    /// through.
    fun shouldSend(control: ControlId) = !isUnbound(bindingFor(control))

    /// Cancels the blink timer and every timer after this call.
    fun dispose() {
        job.cancel()
    }

    private fun cycleId() = when (_state.value.lightStage) {
        LightStage.Parking -> ControlId.LightsParking
        LightStage.Low -> ControlId.LightsLowbeam
        LightStage.Off -> ControlId.LightsOff
    }

    private fun sendIfBound(control: ControlId, action: ActionType) {
        if (!shouldSend(control)) return
        send(control, action)
    }
    private fun syncBlinkTimer() {
        val state = _state.value
        val active = state.leftOn || state.rightOn || state.hazardOn
        blinkJob?.cancel()
        blinkJob = null
        if (!active) {
            if (state.blinkOn) _state.update { it.copy(blinkOn = false) }
            return
        }
        // Light immediately on activation; the timer alternates from there.
        if (!state.blinkOn) _state.update { it.copy(blinkOn = true) }
        if (autoBlink) {
            blinkJob = scope.launch {
                while (isActive) {
                    delay(blinkPhaseMs)
                    advanceBlink()
                }
            }
        }
    }

    companion object {
        /// Full on-off blink rate in Hz.
        const val BLINK_FREQUENCY_HZ = 1.5

        /// Phase duration matching [BLINK_FREQUENCY_HZ] (1.5Hz = 667ms cycle).
        const val DEFAULT_BLINK_PHASE_MS = 333L

        /// Empty (`""`) or dash (`"-"`) means unbound: the phone sends nothing.
        fun isUnbound(binding: String) = binding.isEmpty() || binding == "-"
    }
}
