package dev.fazrigading.wheeldeck.data.services

import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.PI

class RotationMapperTest {

    @Test
    fun `zero drag maps to centered`() {
        assertEquals(0.0, mapRotationToSteering(0.0, 900), 1e-9)
    }

    @Test
    fun `half-range drag hits full lock`() {
        assertEquals(1.0, mapRotationToSteering(450.0, 900), 1e-9)
        assertEquals(-1.0, mapRotationToSteering(-450.0, 900), 1e-9)
    }

    @Test
    fun `scales with selected degree`() {
        assertEquals(1.0, mapRotationToSteering(90.0, 180), 1e-9)
        assertEquals(1.0, mapRotationToSteering(1260.0, 2520), 1e-9)
        assertEquals(0.5, mapRotationToSteering(225.0, 900), 1e-9)
    }

    @Test
    fun `clamps beyond full lock`() {
        assertEquals(1.0, mapRotationToSteering(1000.0, 900), 1e-9)
        assertEquals(-1.0, mapRotationToSteering(-2000.0, 900), 1e-9)
    }

    @Test
    fun `wraps across the plus minus 180 seam`() {
        assertEquals(20.0, circularDelta(170.0, -170.0), 1e-9)
        assertEquals(-20.0, circularDelta(-170.0, 170.0), 1e-9)
    }

    @Test
    fun `plain deltas pass through`() {
        assertEquals(35.0, circularDelta(10.0, 45.0), 1e-9)
        assertEquals(-35.0, circularDelta(45.0, 10.0), 1e-9)
    }

    @Test
    fun `spring back to zero runs at the same rate at every lock-to-lock`() {
        // TODO.md Controls: the fixed 700ms made a 2520° wheel whip back. The
        // same 90° of rotation must take the same time on a 180° lock and a
        // 2520° one.
        assertEquals(springBackDurationMs(90.0), springBackDurationMs(90.0))
        assertEquals(200L, springBackDurationMs(90.0))
        assertEquals(200L, springBackDurationMs(-90.0))
    }

    @Test
    fun `spring back duration scales with the distance travelled`() {
        val atFullLock900 = springBackDurationMs(450.0)
        val atFullLock2520 = springBackDurationMs(1260.0)

        // Both are the same rate, so the longer travel takes proportionally
        // longer: 1260° is 2.8x the 450° of a 900° lock.
        assertEquals(1000L, atFullLock900)
        assertEquals(2800L, atFullLock2520)
        assertEquals(
            SPRING_BACK_DEGREES_PER_SECOND,
            1260.0 / (atFullLock2520 / 1000.0),
            1e-9,
        )
    }

    @Test
    fun `an already centered wheel needs no spring back`() {
        assertEquals(1L, springBackDurationMs(0.0))
    }

    @Test
    fun `the rotation arc fills a quarter turn toward the turned side`() {
        assertEquals(0.0, rotationArcFillRadians(0.0), 1e-9)
        assertEquals(PI / 2, rotationArcFillRadians(1.0), 1e-9)
        assertEquals(-PI / 2, rotationArcFillRadians(-1.0), 1e-9)
        // Out-of-range steering fills the same quarter, not more.
        assertEquals(PI / 2, rotationArcFillRadians(3.0), 1e-9)
    }
}
