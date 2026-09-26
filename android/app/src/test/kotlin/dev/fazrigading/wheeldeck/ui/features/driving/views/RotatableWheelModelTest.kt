package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.SPRING_BACK_DEGREES_PER_SECOND
import dev.fazrigading.wheeldeck.data.services.springBackDurationMs
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

/// Port of mobile/test/ui/features/driving/rotatable_wheel_test.dart, minus the
/// cases that only inspect rendered pixels (the arc's geometry is pinned in
/// RotationMapperTest instead) and the multi-touch case (one pointer model).
@OptIn(ExperimentalCoroutinesApi::class)
class RotatableWheelModelTest {

    private class Fixture(
        val scope: TestScope,
        degrees: Int = 900,
        springBack: Boolean = true,
    ) {
        val values = mutableListOf<Double>()
        val model = RotatableWheelModel(
            degrees = degrees,
            springBack = springBack,
            onChanged = { values += it },
            scope = scope.backgroundScope,
        )

        /// A touch on the wheel rim at [tDeg] clockwise from three o'clock.
        fun point(tDeg: Double, size: Double = 300.0) = Point(
            x = size / 2 + 100 * cos(Math.toRadians(tDeg)),
            y = size / 2 + 100 * sin(Math.toRadians(tDeg)),
        )

        /// Drags from three o'clock to [toDeg] around the rim in 15° steps.
        /// Positive [toDeg] is clockwise, negative counter-clockwise.
        fun dragTo(toDeg: Double, stepDeg: Double = 15.0, size: Double = 300.0) {
            val start = point(0.0, size)
            model.onTouchStart(start.x, start.y, size)
            val direction = if (toDeg >= 0) 1.0 else -1.0
            var t = stepDeg
            while (kotlin.math.abs(t) <= kotlin.math.abs(toDeg)) {
                val next = point(t, size)
                model.onTouchMove(next.x, next.y, size)
                t += stepDeg * direction
            }
        }

        data class Point(val x: Double, val y: Double)
    }

    @Test
    fun `clockwise drag steers right and release springs to zero`() = runTest {
        val f = Fixture(this)

        f.dragTo(60.0)
        assertTrue(f.values.isNotEmpty())
        assertTrue(f.values.all { it in -1.0..1.0 })
        assertTrue(f.values.last() > 0.0)
        assertTrue(f.model.state.value.readout != "0°")

        f.model.onTouchEnd()
        runCurrent()
        // The zero report lands when the return completes, not on release.
        assertTrue(f.values.last() > 0.0)

        advanceTimeBy(springBackDurationMs(f.model.accumulatedDegrees) + 100)
        runCurrent()

        assertEquals(0.0, f.values.last(), 1e-9)
        assertEquals("0°", f.model.state.value.readout)
    }

    @Test
    fun `spring-back off holds the released angle`() = runTest {
        val f = Fixture(this, springBack = false)

        f.dragTo(60.0)
        val held = f.values.last()
        assertTrue(held > 0.0)

        f.model.onTouchEnd()
        advanceTimeBy(2000)
        runCurrent()

        assertEquals(held, f.values.last(), 1e-9)
        assertTrue(f.model.state.value.readout != "0°")
    }

    @Test
    fun `a new drag cancels an in-flight spring-back`() = runTest {
        val f = Fixture(this)
        f.dragTo(60.0)
        f.model.onTouchEnd()
        advanceTimeBy(100)
        runCurrent()
        // Mid return: easing back to zero but not there yet.
        assertTrue(f.model.state.value.readout != "0°")
        val midFlight = f.model.accumulatedDegrees

        // The new drag takes over from the current angle.
        f.dragTo(120.0)
        advanceTimeBy(5000)
        runCurrent()

        assertTrue(f.model.state.value.readout != "0°")
        assertTrue(f.model.accumulatedDegrees >= midFlight)
        assertTrue(0.0 !in f.values)

        f.model.onTouchEnd()
        advanceTimeBy(5000)
        runCurrent()
        assertEquals(0.0, f.values.last(), 1e-9)
    }

    @Test
    fun `disposal mid-return stops the animation`() = runTest {
        val f = Fixture(this)
        f.dragTo(60.0)
        f.model.onTouchEnd()
        advanceTimeBy(32)
        runCurrent()
        val beforeDispose = f.values.size

        f.model.dispose()
        advanceTimeBy(5000)
        runCurrent()

        assertEquals(beforeDispose, f.values.size)
    }

    @Test
    fun `accumulation clamps at half-range (full lock)`() = runTest {
        val f = Fixture(this, degrees = 180)

        // A 150-degree clockwise arc: past half of the 180 range, so steering
        // and readout must clamp at full lock instead of overshooting.
        f.dragTo(150.0)

        assertEquals(1.0, f.values.last(), 1e-9)
        assertEquals("90°", f.model.state.value.readout)

        f.model.onTouchEnd()
        advanceTimeBy(2000)
        runCurrent()
        assertEquals(0.0, f.values.last(), 1e-9)
    }

    @Test
    fun `counter-clockwise drag steers left`() = runTest {
        val f = Fixture(this)

        f.dragTo(-60.0)

        assertTrue(f.values.isNotEmpty())
        assertTrue(f.values.last() < 0.0)

        f.model.onTouchEnd()
        advanceTimeBy(2000)
        runCurrent()
        assertEquals(0.0, f.values.last(), 1e-9)
    }

    @Test
    fun `return to zero runs at the same rate on a 180 and a 2520 lock`() = runTest {
        // TODO.md Controls: the old fixed 700ms made high lock-to-lock settings
        // whip back. Both settings must unwind the same 90 degrees at the same
        // speed, so the return takes the same time.
        val narrow = Fixture(this, degrees = 180)
        val wide = Fixture(this, degrees = 2520)

        listOf(narrow, wide).forEach { f ->
            f.model.onTouchStart(250.0, 150.0, 300.0)
            // 90 degrees clockwise: a quarter turn for the 180 lock, a sliver
            // for the 2520 one — but the same distance to unwind.
            var t = 15.0
            while (t <= 90.0) {
                val p = f.point(t)
                f.model.onTouchMove(p.x, p.y, 300.0)
                t += 15.0
            }
        }
        assertEquals(90.0, narrow.model.accumulatedDegrees, 1e-6)
        assertEquals(90.0, wide.model.accumulatedDegrees, 1e-6)

        narrow.model.onTouchEnd()
        wide.model.onTouchEnd()
        val expectedMs = springBackDurationMs(90.0)

        advanceTimeBy(expectedMs - 1)
        runCurrent()
        assertTrue("still short of zero at ${expectedMs - 1}ms", narrow.model.accumulatedDegrees > 0.0)
        assertTrue(wide.model.accumulatedDegrees > 0.0)

        advanceTimeBy(32)
        runCurrent()
        assertEquals(0.0, narrow.model.accumulatedDegrees, 1e-9)
        assertEquals(0.0, wide.model.accumulatedDegrees, 1e-9)
    }

    @Test
    fun `the return covers its distance at a constant rate`() = runTest {
        val f = Fixture(this, degrees = 2520)
        f.dragTo(180.0)
        f.model.onTouchEnd()
        val start = f.model.accumulatedDegrees
        val totalMs = springBackDurationMs(start)

        // A third of the way in, a third of the distance must be left.
        advanceTimeBy((totalMs / 3).toLong())
        runCurrent()
        val travelledFraction = 1.0 - (f.model.accumulatedDegrees / start)

        assertEquals(1.0 / 3.0, travelledFraction, 0.05)
        assertEquals(
            start / (totalMs / 1000.0),
            SPRING_BACK_DEGREES_PER_SECOND,
            1.0,
        )
    }

    @Test
    fun `a full-lock release on a 2520 lock takes proportionally longer`() = runTest {
        val f = Fixture(this, degrees = 2520)

        f.dragTo(1800.0)
        assertEquals(1260.0, f.model.accumulatedDegrees, 1e-6)
        f.model.onTouchEnd()
        val totalMs = springBackDurationMs(1260.0)

        advanceTimeBy(totalMs - 32)
        runCurrent()
        assertTrue(f.model.accumulatedDegrees > 0.0)

        advanceTimeBy(64)
        runCurrent()
        assertEquals(0.0, f.model.accumulatedDegrees, 1e-9)
    }

    @Test
    fun `releasing an untouched wheel reports center once`() = runTest {
        val f = Fixture(this)

        f.model.onTouchEnd()

        // The desktop needs the centered report even when nothing moved.
        assertEquals(listOf(0.0), f.values)
    }
}
