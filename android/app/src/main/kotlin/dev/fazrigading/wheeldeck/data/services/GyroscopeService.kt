package dev.fazrigading.wheeldeck.data.services

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flow
import kotlin.math.PI

/// One gyroscope sample: angular velocity in rad/s per axis.
data class GyroEvent(
    val x: Float = 0f,
    val y: Float = 0f,
    val z: Float = 0f,
)

/// Real gyro stream from the platform [SensorManager].
fun gyroscopeEvents(context: Context): Flow<GyroEvent> = callbackFlow {
    val manager = context.getSystemService(SensorManager::class.java)
    val sensor = manager?.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    if (manager == null || sensor == null) {
        // No gyroscope: an empty stream; callers treat steering as absent.
        close()
        return@callbackFlow
    }
    val listener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            trySend(GyroEvent(event.values[0], event.values[1], event.values[2]))
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }
    manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
    awaitClose { manager.unregisterListener(listener) }
}

/// Stateless wrapper over the platform gyroscope.
///
/// Integrates Z-axis angular velocity (rad/s) into a raw angle so
/// [SteeringSensor] consumes an already-integrated value. The injected
/// [eventStream]/[clock] seams keep this testable without sensors.
class GyroscopeService(
    private val eventStream: Flow<GyroEvent>,
    private val clock: () -> Double = { System.nanoTime() / 1_000_000_000.0 },
) {
    /// Raw integrated angle stream, clamped to ±pi to leave headroom around
    /// the pi/4 full-lock angle. Negated: positive gyro-z is counterclockwise
    /// on screen, but a right (clockwise) turn must read as positive steering.
    ///
    /// Cold: each collection starts a fresh integration, matching Dart's
    /// single-subscription stream.
    val rawAngles: Flow<Double> = flow {
        var rawGyroAngle = 0.0
        var lastGyroAt: Double? = null
        eventStream.collect { event ->
            val now = clock()
            val dt = (lastGyroAt?.let { now - it } ?: 0.016).coerceIn(0.0, 0.1)
            lastGyroAt = now
            rawGyroAngle -= event.z * dt
            emit(rawGyroAngle.coerceIn(-PI, PI))
        }
    }
}
