package dev.fazrigading.wheeldeck.domain.models

/// Where a connection attempt stands. Mirrors the states in
/// `docs/mobile-interface.md`.
enum class ConnectionStatus {
    Disconnected,
    Connecting,
    PairingRequired,
    Connected,
    Reconnecting,
}
