package dev.fazrigading.wheeldeck.domain.models

/// How a pairing challenge is answered.
enum class PairingMethod { Pin, QrScan }

/// A prompt for the user to enter a PIN or scan a QR code.
data class PairingChallenge(val method: PairingMethod)
