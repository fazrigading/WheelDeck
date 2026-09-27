package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.PedalState
import dev.fazrigading.wheeldeck.domain.models.PedalType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PedalInputTest {

    /// Records every pressure the state flow reports, per pedal, starting from
    /// rest. Repeated unchanged values collapse, so a frame list reads as the
    /// animation itself.
    private class Recorder(input: PedalInput, scope: CoroutineScope) {
        val frames = PedalType.entries.associateWith { mutableListOf(0.0) }

        init {
            scope.launch {
                input.state.collect { state ->
                    PedalType.entries.forEach { pedal ->
                        val recorded = frames.getValue(pedal)
                        if (recorded.last() != state[pedal]) recorded += state[pedal]
                    }
                }
            }
        }
    }

    /// Virtual clock so the release curve is measured against test time
    /// instead of the wall clock.
    private fun virtualClock(scope: TestScope) = { scope.testScheduler.currentTime / 1000.0 }

    @Test
    fun `setPressure clamps out-of-range values`() = runTest {
        val input = PedalInput(backgroundScope, clock = virtualClock(this))

        input.setPressure(PedalType.Accelerator, 1.8)
        input.setPressure(PedalType.Brake, -0.4)

        assertEquals(1.0, input.pressureOf(PedalType.Accelerator), 1e-9)
        assertEquals(0.0, input.pressureOf(PedalType.Brake), 1e-9)
    }

    @Test
    fun `pressures of different pedals are independent`() = runTest {
        val input = PedalInput(backgroundScope, clock = virtualClock(this))

        input.setPressure(PedalType.Accelerator, 0.5)
        input.setPressure(PedalType.Clutch, 0.25)

        assertEquals(PedalState(accelerator = 0.5, clutch = 0.25), input.state.value)
    }

    @Test
    fun `release from rest emits nothing`() = runTest {
        val input = PedalInput(backgroundScope, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()

        input.release(PedalType.Clutch)
        advanceTimeBy(500)
        runCurrent()

        assertEquals(listOf(0.0), recorder.frames.getValue(PedalType.Clutch))
    }

    @Test
    fun `linear release halves the pressure halfway and rests at the end`() = runTest {
        // 96ms is six 16ms ticks, so every frame lands on a known progress.
        val input = PedalInput(backgroundScope, releaseDurationMs = 96, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()
        input.setPressure(PedalType.Accelerator, 0.8)

        input.release(PedalType.Accelerator)
        advanceTimeBy(96)
        runCurrent()

        assertEquals(
            listOf(0.0, 0.8, 0.666667, 0.533333, 0.4, 0.266667, 0.133333, 0.0),
            rounded(recorder, PedalType.Accelerator),
        )
    }

    @Test
    fun `easeOut release decays faster than linear early on`() = runTest {
        val input = PedalInput(backgroundScope, releaseDurationMs = 96, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()
        input.setReleaseCurve(ReleaseCurve.EaseOut)
        input.setPressure(PedalType.Accelerator, 0.8)

        input.release(PedalType.Accelerator)
        advanceTimeBy(96)
        runCurrent()

        // 1 - (1 - p)^2 is already at 0.75 progress by the halfway tick, where
        // linear is at 0.5 — a quarter of the pressure is left.
        assertEquals(
            listOf(0.0, 0.8, 0.555556, 0.355556, 0.2, 0.088889, 0.022222, 0.0),
            rounded(recorder, PedalType.Accelerator),
        )
    }

    @Test
    fun `easeInOut release is slow at both ends`() = runTest {
        val input = PedalInput(backgroundScope, releaseDurationMs = 96, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()
        input.setReleaseCurve(ReleaseCurve.EaseInOut)
        input.setPressure(PedalType.Brake, 0.8)

        input.release(PedalType.Brake)
        advanceTimeBy(96)
        runCurrent()

        // p^2 * (3 - 2p): a quarter of the way through has barely moved.
        assertEquals(
            listOf(0.0, 0.8, 0.740741, 0.592593, 0.4, 0.207407, 0.059259, 0.0),
            rounded(recorder, PedalType.Brake),
        )
    }

    @Test
    fun `port defaults release over 300ms in 16ms steps`() = runTest {
        val input = PedalInput(backgroundScope, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()
        input.setPressure(PedalType.Accelerator, 1.0)

        input.release(PedalType.Accelerator)
        // 18 ticks at 16..288ms, all still off zero.
        advanceTimeBy(300)
        runCurrent()
        val midRelease = rounded(recorder, PedalType.Accelerator)
        advanceTimeBy(16)
        runCurrent()
        val finished = rounded(recorder, PedalType.Accelerator)

        assertEquals(20, midRelease.size)
        assertTrue(midRelease.last() > 0.0)
        assertTrue(midRelease.drop(1).zipWithNext().all { (a, b) -> a > b })
        // The 304ms tick reaches progress 1.0 and rests.
        assertEquals(21, finished.size)
        assertEquals(0.0, finished.last(), 1e-9)
    }

    @Test
    fun `zero release duration drops straight to rest`() = runTest {
        val input = PedalInput(backgroundScope, releaseDurationMs = 0, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()
        input.setPressure(PedalType.Brake, 0.6)

        input.release(PedalType.Brake)
        runCurrent()

        // Both writes land inside one frame, so a StateFlow consumer only ever
        // sees the pedal back at rest.
        assertEquals(PedalState.released, input.state.value)
        assertEquals(listOf(0.0), rounded(recorder, PedalType.Brake))
    }

    @Test
    fun `setPressure cancels an active release`() = runTest {
        val input = PedalInput(backgroundScope, releaseDurationMs = 96, clock = virtualClock(this))
        input.setPressure(PedalType.Accelerator, 0.8)
        input.release(PedalType.Accelerator)
        advanceTimeBy(32)
        runCurrent()

        input.setPressure(PedalType.Accelerator, 0.3)
        advanceTimeBy(200)
        runCurrent()

        assertEquals(0.3, input.pressureOf(PedalType.Accelerator), 1e-9)
    }

    @Test
    fun `dispose cancels an active release`() = runTest {
        val input = PedalInput(backgroundScope, releaseDurationMs = 96, clock = virtualClock(this))
        val recorder = Recorder(input, backgroundScope)
        runCurrent()
        input.setPressure(PedalType.Accelerator, 0.8)
        input.release(PedalType.Accelerator)
        advanceTimeBy(32)
        runCurrent()

        input.dispose()
        val afterDispose = recorder.frames.getValue(PedalType.Accelerator).size
        advanceTimeBy(200)
        runCurrent()

        assertEquals(afterDispose, recorder.frames.getValue(PedalType.Accelerator).size)
    }

    private fun rounded(recorder: Recorder, pedal: PedalType) =
        recorder.frames.getValue(pedal).map { Math.round(it * 1_000_000) / 1_000_000.0 }
}
