package dev.fazrigading.wheeldeck.ui.core

import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of the press/hold cases in mobile/test/ui/features/driving/camera_pad_test.dart.
@OptIn(ExperimentalCoroutinesApi::class)
class ControlPressTest {

    private class Fixture(
        private val mode: ControlMode,
        private val control: ControlId? = ControlId.Horn,
        private val holdDurationMs: Long = 3000,
    ) {
        val events = mutableListOf<Pair<ControlId, ActionType>>()
        var holds = 0
        lateinit var press: ControlPress

        fun build(scope: kotlinx.coroutines.test.TestScope) {
            press = ControlPress(
                mode = mode,
                control = control,
                holdDurationMs = holdDurationMs,
                activate = { c, a -> events += c to a },
                onHoldCompleted = { holds++ },
                scope = scope.backgroundScope,
            )
        }
    }

    @Test
    fun `a momentary tap sends press then release`() = runTest {
        val f = Fixture(ControlMode.Momentary)
        f.build(this)

        f.press.onPressDown()
        f.press.onPressUp()

        assertEquals(
            listOf(ControlId.Horn to ActionType.Press, ControlId.Horn to ActionType.Release),
            f.events,
        )
    }

    @Test
    fun `a toggle cell sends one pulse and no press`() = runTest {
        val f = Fixture(ControlMode.Toggle)
        f.build(this)

        f.press.onPressDown()
        f.press.onTap()

        assertEquals(listOf(ControlId.Horn to ActionType.Toggle), f.events)
        assertFalse(f.press.pressed.value)
    }

    @Test
    fun `a three-second hold fires without a press and reports progress`() = runTest {
        val f = Fixture(ControlMode.TapOrHold)
        f.build(this)

        f.press.onPressDown()
        runCurrent()
        assertEquals(0f, f.press.holdProgress.value, 1e-6f)
        advanceTimeBy(1500)
        runCurrent()
        assertTrue(f.press.holdProgress.value > 0.3f)

        advanceTimeBy(1600)
        runCurrent()
        assertEquals(1, f.holds)
        assertTrue(f.events.isEmpty())
        assertEquals(1f, f.press.holdProgress.value, 1e-6f)

        f.press.onPressUp()
        assertTrue("the hold suppresses the press", f.events.isEmpty())
    }

    @Test
    fun `a hold released early sends the press and never fires the hold`() = runTest {
        val f = Fixture(ControlMode.TapOrHold)
        f.build(this)

        f.press.onPressDown()
        advanceTimeBy(1000)
        f.press.onPressUp()

        assertEquals(
            listOf(ControlId.Horn to ActionType.Press, ControlId.Horn to ActionType.Release),
            f.events,
        )
        assertEquals(0, f.holds)

        // The cancelled hold must not fire later.
        advanceTimeBy(3000)
        runCurrent()
        assertEquals(0, f.holds)
        assertEquals(0f, f.press.holdProgress.value, 1e-6f)
    }

    @Test
    fun `a hold dragged off the cell cancels without emitting`() = runTest {
        val f = Fixture(ControlMode.TapOrHold)
        f.build(this)

        f.press.onPressDown()
        advanceTimeBy(500)
        f.press.onPressCancel()
        advanceTimeBy(3000)
        runCurrent()

        assertTrue(f.events.isEmpty())
        assertEquals(0, f.holds)
        assertFalse(f.press.pressed.value)
    }

    @Test
    fun `a null control still holds but emits nothing`() = runTest {
        val f = Fixture(ControlMode.TapOrHold, control = null)
        f.build(this)

        f.press.onPressDown()
        advanceTimeBy(3100)
        runCurrent()
        assertEquals(1, f.holds)

        f.press.onPressDown()
        advanceTimeBy(500)
        f.press.onPressUp()
        assertTrue(f.events.isEmpty())
    }

    @Test
    fun `hold-confirm fires only on a completed hold`() = runTest {
        val f = Fixture(ControlMode.HoldConfirm, holdDurationMs = 500)
        f.build(this)

        f.press.onPressDown()
        advanceTimeBy(600)
        runCurrent()
        assertEquals(listOf(ControlId.Horn to ActionType.HoldConfirm), f.events)

        f.press.onPressUp()
        assertEquals(1, f.events.size)
    }

    @Test
    fun `a short tap on hold-confirm sends nothing`() = runTest {
        val f = Fixture(ControlMode.HoldConfirm, holdDurationMs = 500)
        f.build(this)

        f.press.onPressDown()
        advanceTimeBy(200)
        f.press.onPressUp()
        advanceTimeBy(600)
        runCurrent()

        assertTrue(f.events.isEmpty())
    }

    @Test
    fun `the hold timer does not outlive the cell`() = runTest {
        val f = Fixture(ControlMode.TapOrHold)
        f.build(this)

        f.press.onPressDown()
        advanceTimeBy(500)
        f.press.dispose()
        advanceTimeBy(3000)
        runCurrent()

        assertEquals(0, f.holds)
        assertTrue(f.events.isEmpty())
    }

    @Test
    fun `the toggle set matches the ported table exactly`() {
        val toggles = ControlId.entries
            .filter { ControlPress.modeFor(it) == ControlMode.Toggle }
            .toSet()

        assertEquals(
            setOf(
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
            ),
            toggles,
        )
        assertEquals(ControlMode.HoldConfirm, ControlPress.modeFor(ControlId.EngineStart))
        assertEquals(ControlMode.Momentary, ControlPress.modeFor(ControlId.Horn))
        assertEquals(ControlMode.Momentary, ControlPress.modeFor(ControlId.CameraPadRecenter))
    }

    @Test
    fun `a null control only holds in tap-or-hold mode`() {
        runTest {
            val momentary = Fixture(ControlMode.Momentary, control = null)
            momentary.build(this)
            momentary.press.onPressDown()

            assertFalse("a hole must not read as pressed", momentary.press.pressed.value)
            assertTrue(momentary.events.isEmpty())
        }
    }
}
