package dev.fazrigading.wheeldeck.data.services

import org.junit.Assert.assertEquals
import org.junit.Test

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
}
