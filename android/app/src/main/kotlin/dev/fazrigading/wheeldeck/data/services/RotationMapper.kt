package dev.fazrigading.wheeldeck.data.services

import kotlin.math.abs
import kotlin.math.PI
import kotlin.math.roundToLong

/// Pure helpers for rotatable steering: no widgets, no storage.
///
/// [mapRotationToSteering] converts accumulated finger rotation (degrees,
/// signed: clockwise positive) to normalized steering -1.0..1.0, where half
/// of [degrees] (the lock-to-lock range) equals full lock. Overshoot clamps.
/// Releasing the wheel resets the accumulation to zero, which maps to 0.0.
///
/// [circularDelta] returns the signed shortest-arc difference from [from] to
/// [to] in degrees, wrapped to (-180, 180]. Used to accumulate circular drags
/// across the +/-180 seam without jumps.
fun mapRotationToSteering(accumulatedDegrees: Double, degrees: Int): Double {
    val halfRange = degrees / 2.0
    return (accumulatedDegrees / halfRange).coerceIn(-1.0, 1.0)
}

fun circularDelta(from: Double, to: Double): Double {
    var delta = (to - from) % 360
    if (delta > 180) delta -= 360
    if (delta <= -180) delta += 360
    return delta
}

/// Return speed for the rotatable wheel's spring-back to zero, in degrees per
/// second — constant, so the wheel unwinds at the same rate on a 180° lock and
/// a 2520° one (TODO.md Controls: the old fixed duration made high lock-to-lock
/// settings whip back far too fast).
///
/// The knob is a feel trade: 450°/s unwinds a full-lock 900° turn in a second.
/// Lower it if a slow unwind feels heavy.
const val SPRING_BACK_DEGREES_PER_SECOND = 450.0

/// Milliseconds the spring-back from [accumulatedDegrees] back to zero takes.
/// Proportional to the distance, so the return rate is the same whatever
/// [mapRotationToSteering]'s `degrees` is.
fun springBackDurationMs(accumulatedDegrees: Double): Long =
    (abs(accumulatedDegrees) / SPRING_BACK_DEGREES_PER_SECOND * 1000.0).roundToLong().coerceAtLeast(1L)

/// Sweep of the rotation indicator's fill, in radians clockwise from twelve
/// o'clock, for normalized [steering]. Zero steering fills nothing; full lock
/// fills a quarter turn toward the turned side.
fun rotationArcFillRadians(steering: Double): Double = (PI / 2) * steering.coerceIn(-1.0, 1.0)

/// Where the rotation indicator's fill starts, in radians. Twelve o'clock in a
/// y-down coordinate space.
const val ROTATION_ARC_START_RADIANS = 3 * PI / 2
