package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/// Port of mobile/test/data/services/dashboard_send_gate_test.dart.
@OptIn(ExperimentalCoroutinesApi::class)
class DashboardSendGateTest {

    private val sent = mutableListOf<Pair<ControlId, ActionType>>()
    private val bindings = mutableMapOf<ControlId, String>()

    @Before
    fun setUp() {
        sent.clear()
        bindings.clear()
        ControlId.entries.forEach { bindings[it] = "K" }
    }

    private fun buildGate(
        scope: CoroutineScope = CoroutineScope(Dispatchers.Unconfined),
        autoBlink: Boolean = false,
    ) = DashboardSendGate(
        send = { control, action -> sent += control to action },
        bindingFor = { bindings.getValue(it) },
        scope = scope,
        autoBlink = autoBlink,
    )

    @Test
    fun `bound control sends through`() {
        val gate = buildGate()

        gate.handle(ControlId.Horn, ActionType.Press)

        assertEquals(listOf(ControlId.Horn to ActionType.Press), sent)
    }

    @Test
    fun `empty binding sends nothing`() {
        val gate = buildGate()
        bindings[ControlId.Horn] = ""

        gate.handle(ControlId.Horn, ActionType.Press)

        assertTrue(sent.isEmpty())
    }

    @Test
    fun `dash binding sends nothing`() {
        val gate = buildGate()
        bindings[ControlId.AudioNext] = "-"

        gate.handle(ControlId.AudioNext, ActionType.Press)
        gate.handle(ControlId.AudioNext, ActionType.Release)

        assertTrue(sent.isEmpty())
    }

    @Test
    fun `cycles parking to lowbeam to off with toggle pulses`() {
        val gate = buildGate()

        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)

        assertEquals(
            listOf(
                ControlId.LightsParking to ActionType.Toggle,
                ControlId.LightsLowbeam to ActionType.Toggle,
                ControlId.LightsOff to ActionType.Toggle,
            ),
            sent,
        )
    }

    @Test
    fun `wraps back to parking and tracks stage`() {
        val gate = buildGate()

        assertEquals(LightStage.Off, gate.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        assertEquals(LightStage.Parking, gate.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        assertEquals(LightStage.Low, gate.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        assertEquals(LightStage.Off, gate.lightStage)
        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)

        assertEquals(ControlId.LightsParking, sent.last().first)
    }

    @Test
    fun `unbound cycle step still advances state but sends nothing`() {
        val gate = buildGate()
        bindings[ControlId.LightsParking] = "-"

        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)

        assertTrue(sent.isEmpty())
        assertEquals(LightStage.Parking, gate.lightStage)
    }

    @Test
    fun `high-beam stays independent of the cycle`() {
        val gate = buildGate()

        gate.handle(ControlId.HeadlightToggle, ActionType.Toggle)
        gate.handle(ControlId.HighBeamToggle, ActionType.Toggle)

        assertEquals(ControlId.HighBeamToggle to ActionType.Toggle, sent.last())
        assertEquals(LightStage.Parking, gate.lightStage)
    }

    @Test
    fun `individual toggle sends and holds state`() {
        val gate = buildGate()

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)

        assertEquals(listOf(ControlId.TurnSignalLeft to ActionType.Toggle), sent)
        assertTrue(gate.leftOn)
        assertFalse(gate.rightOn)
    }

    @Test
    fun `signals send and hold their own state during hazard`() {
        val gate = buildGate()

        gate.handle(ControlId.HazardLights, ActionType.Toggle)
        assertEquals(listOf(ControlId.HazardLights to ActionType.Toggle), sent)
        assertTrue(gate.hazardOn)

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        assertEquals(2, sent.size)
        assertEquals(ControlId.TurnSignalLeft to ActionType.Toggle, sent.last())
        assertTrue(gate.leftOn)
        assertTrue(gate.hazardOn)

        // Both cells light on the shared phase while their states are held.
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalLeft))
        assertTrue(gate.signalVisualActive(ControlId.HazardLights))

        // Exclusion applies during hazard too: right replaces left silently.
        gate.handle(ControlId.TurnSignalRight, ActionType.Toggle)
        assertEquals(3, sent.size)
        assertEquals(ControlId.TurnSignalRight to ActionType.Toggle, sent.last())
        assertTrue(gate.rightOn)
        assertFalse(gate.leftOn)
        assertTrue(gate.hazardOn)

        gate.handle(ControlId.TurnSignalRight, ActionType.Toggle)
        assertEquals(4, sent.size)
        assertFalse(gate.rightOn)
        assertTrue(gate.hazardOn)

        // Left survives hazard clearing and blinks its own state afterward.
        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        assertEquals(5, sent.size)
        assertTrue(gate.leftOn)

        gate.handle(ControlId.HazardLights, ActionType.Toggle)
        assertEquals(6, sent.size)
        assertFalse(gate.hazardOn)
        assertTrue(gate.leftOn)
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalLeft))
        assertFalse(gate.signalVisualActive(ControlId.HazardLights))
        gate.advanceBlink()
        assertFalse(gate.signalVisualActive(ControlId.TurnSignalLeft))
        gate.advanceBlink()
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalLeft))
    }

    @Test
    fun `turning one signal on clears the other without sending it`() {
        val gate = buildGate()

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        assertTrue(gate.leftOn)

        gate.handle(ControlId.TurnSignalRight, ActionType.Toggle)
        assertEquals(2, sent.size)
        assertEquals(ControlId.TurnSignalRight to ActionType.Toggle, sent.last())
        assertTrue(gate.rightOn)
        assertFalse(gate.leftOn)
        assertFalse(gate.signalVisualActive(ControlId.TurnSignalLeft))

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        assertEquals(3, sent.size)
        assertEquals(ControlId.TurnSignalLeft to ActionType.Toggle, sent.last())
        assertTrue(gate.leftOn)
        assertFalse(gate.rightOn)
        assertFalse(gate.signalVisualActive(ControlId.TurnSignalRight))
    }

    @Test
    fun `hazard drives both visuals, individuals drive their own`() {
        val gate = buildGate()

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        // Lit immediately on activation, no dark first phase.
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalLeft))
        assertFalse(gate.signalVisualActive(ControlId.TurnSignalRight))

        gate.handle(ControlId.HazardLights, ActionType.Toggle)
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalLeft))
        assertTrue(gate.signalVisualActive(ControlId.TurnSignalRight))

        gate.advanceBlink()
        assertFalse(gate.signalVisualActive(ControlId.TurnSignalLeft))
        assertFalse(gate.signalVisualActive(ControlId.TurnSignalRight))
        assertFalse(gate.signalVisualActive(ControlId.HazardLights))
    }

    @Test
    fun `blink defaults to a 1_5Hz phase`() {
        assertEquals(1.5, DashboardSendGate.BLINK_FREQUENCY_HZ, 1e-9)
        assertEquals(333L, DashboardSendGate.DEFAULT_BLINK_PHASE_MS)
    }

    @Test
    fun `clearing the last signal drops the blink phase`() {
        val gate = buildGate()

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        assertTrue(gate.blinkOn)

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)

        assertFalse(gate.blinkOn)
    }

    @Test
    fun `autoBlink flips the phase every 333ms`() = runTest {
        val gate = buildGate(scope = backgroundScope, autoBlink = true)

        gate.handle(ControlId.TurnSignalLeft, ActionType.Toggle)
        assertTrue(gate.blinkOn)
        runCurrent()

        advanceTimeBy(333)
        runCurrent()
        assertFalse(gate.blinkOn)
        advanceTimeBy(333)
        runCurrent()
        assertTrue(gate.blinkOn)
    }
}
