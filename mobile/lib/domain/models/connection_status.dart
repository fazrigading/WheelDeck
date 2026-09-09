/// Where a connection attempt stands. Mirrors the states in
/// `docs/mobile-interface.md`.
enum ConnectionStatus {
  disconnected,
  discovering,
  connecting,
  pairingRequired,
  connected,
  reconnecting,
}
