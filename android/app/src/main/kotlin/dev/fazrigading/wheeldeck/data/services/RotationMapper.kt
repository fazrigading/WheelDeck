package dev.fazrigading.wheeldeck.data.services

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
