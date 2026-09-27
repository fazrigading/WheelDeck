package dev.fazrigading.wheeldeck.data.services

/// Whether the rotatable wheel animates back to zero on release. When off, the
/// wheel holds its released angle and steering stays there until the driver
/// drags it back. Gyro steering ignores it, and so do pedals — the pedal
/// release curve is [PedalInput]'s.
object SpringBack {
    const val KEY = "wheeldeck.spring_back"
    const val FALLBACK = true
}
