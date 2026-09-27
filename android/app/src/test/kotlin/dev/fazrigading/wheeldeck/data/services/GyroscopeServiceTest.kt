package dev.fazrigading.wheeldeck.data.services

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.PI

class GyroscopeServiceTest {

    @Test
    fun `integrates z angular velocity into a raw angle`() = runTest {
        val events = MutableSharedFlow<GyroEvent>(extraBufferCapacity = 64)
        var now = 0.0
        val service = GyroscopeService(events, clock = { now })

        val angles = mutableListOf<Double>()
        val job = launch { service.rawAngles.collect { angles.add(it) } }
        runCurrent() // let the collector subscribe before emitting

        // First sample uses the 0.016s fallback dt. z = -2.0 (clockwise) must
        // read as positive steering.
        events.tryEmit(GyroEvent(z = -2.0f))
        now += 0.016
        events.tryEmit(GyroEvent(z = 0.0f))
        runCurrent()

        assertEquals(2, angles.size)
        assertEquals(0.032, angles[0], 1e-9)
        assertEquals(0.032, angles[1], 1e-9)

        job.cancel()
    }

    @Test
    fun `clamps dt spikes and the angle range`() = runTest {
        val events = MutableSharedFlow<GyroEvent>(extraBufferCapacity = 64)
        var now = 0.0
        val service = GyroscopeService(events, clock = { now })

        val angles = mutableListOf<Double>()
        val job = launch { service.rawAngles.collect { angles.add(it) } }
        runCurrent() // let the collector subscribe before emitting

        events.tryEmit(GyroEvent(z = -1000.0f))

        // A 10s gap clamps dt to 0.1s; the angle clamps to ±pi.
        now += 10.0
        events.tryEmit(GyroEvent(z = -1000.0f))
        runCurrent()

        assertEquals(PI, angles.last(), 1e-9)

        job.cancel()
    }
}
