package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.DrivingLayout
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.LightStage
import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.ui.core.ControlMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Test

/// Port of the device-independent half of
/// mobile/test/ui/features/driving/signal_row_test.dart. That suite asserts where
/// the cells sit on screen (block A in rotatable mode, above the left pedal
/// column in gyro mode), which needs a device; what is checkable here is the
/// part that decides behaviour: the signals are the only turn-signal cells, they
/// toggle, they are bound in both mapping modes so they never ask for a
/// keybind, and the gate keeps them mutually exclusive and independent of
/// hazard.
class SignalRowTest {

    private val signals = listOf(ControlId.TurnSignalLeft, ControlId.TurnSignalRight)

    @Test
    fun `each signal is exactly one grid cell, in block A`() {
        val slots = DrivingLayout.sequential.slots
        for (signal in signals) {
            assertEquals(signal.wireValue, 1, slots.count { it.control == signal })
            assertTrue(
                signal.wireValue,
                slots.any { it.control == signal && DrivingLayout.blockA.contains(it.rect.rowStart, it.rect.colStart) },
            )
        }
    }

    @Test
    fun `signals toggle and are bound in both mapping modes`() {
        for (signal in signals) {
            assertEquals(signal.wireValue, ControlMode.Toggle, modeFor(signal, EngineStartMode.fallback))
            for (isGamepad in listOf(false, true)) {
                assertFalse(
                    signal.wireValue,
                    DashboardSendGate.isUnbound(GamePreset.Ets2.bindingFor(signal, isGamepad)),
                )
            }
        }
    }

    @Test
    fun `turning one signal on clears the other without sending it`() {
        val sent = mutableListOf<Pair<ControlId, ActionType>>()
        val gate = DashboardSendGate(
            send = { control, action -> sent += control to action },
            bindingFor = { GamePreset.Ets2.bindingFor(it, isGamepad = false) },
            scope = CoroutineScope(Dispatchers.Unconfined),
            autoBlink = false,
        )

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        gate.handle(ControlId.TurnSignalRight, ActionType.Toggle)

        assertEquals(
            listOf(
                ControlId.TurnSignalLeft to ActionType.Toggle,
                ControlId.TurnSignalRight to ActionType.Toggle,
            ),
            sent,
        )
        assertFalse(gate.state.value.leftOn)
        assertTrue(gate.state.value.rightOn)
    }

    @Test
    fun `hazard blinks independently of the signals`() {
        val gate = DashboardSendGate(
            send = { _, _ -> },
            bindingFor = { GamePreset.Ets2.bindingFor(it, isGamepad = false) },
            scope = CoroutineScope(Dispatchers.Unconfined),
            autoBlink = false,
        )

        gate.handle(ControlId.HazardLights, ActionType.Toggle)
        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)

        assertTrue(gate.state.value.hazardOn)
        assertTrue(gate.state.value.leftOn)
        // Hazard lights both arrows; the left signal still shows its own side.
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalRight))
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalLeft))
    }

    @Test
    fun `the headlight cycle runs off-parking-low on the phone`() {
        val sent = mutableListOf<ControlId>()
        val gate = DashboardSendGate(
            send = { control, _ -> sent += control },
            bindingFor = { GamePreset.Ets2.bindingFor(it, isGamepad = false) },
            scope = CoroutineScope(Dispatchers.Unconfined),
            autoBlink = false,
        )

        assertEquals(LightStage.Off, gate.state.value.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        assertEquals(LightStage.Parking, gate.state.value.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        assertEquals(LightStage.Low, gate.state.value.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        assertEquals(LightStage.Off, gate.state.value.lightStage)

        assertEquals(
            listOf(ControlId.LightsParking, ControlId.LightsLowbeam, ControlId.LightsOff),
            sent,
        )
    }

    @Test
    fun `high beam is independent of the light cycle`() {
        val sent = mutableListOf<ControlId>()
        val gate = DashboardSendGate(
            send = { control, _ -> sent += control },
            bindingFor = { GamePreset.Ets2.bindingFor(it, isGamepad = false) },
            scope = CoroutineScope(Dispatchers.Unconfined),
            autoBlink = false,
        )

        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        gate.handle(ControlId.HighBeamToggle, ActionType.Toggle)

        assertEquals(LightStage.Parking, gate.state.value.lightStage)
        assertEquals(listOf(ControlId.LightsParking, ControlId.HighBeamToggle), sent)
    }
}
