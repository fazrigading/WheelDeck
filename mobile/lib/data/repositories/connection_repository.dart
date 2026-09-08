import '../../network/wheeldeck_client.dart';

/// Single source of truth for the WebSocket connection.
///
/// Thin pass-through over the [WheelDeckClient] service so ViewModels never
/// touch transport framing directly.
class ConnectionRepository {
  ConnectionRepository({required WheelDeckClient client}) : _client = client;

  final WheelDeckClient _client;

  ConnectionStatus get status => _client.status;
  ConnectionTarget? get lastTarget => _client.lastTarget;

  void onStatusChanged(void Function(ConnectionStatus status) callback) =>
      _client.onConnectionStatusChanged(callback);

  void onPairingRequired(void Function(PairingChallenge challenge) callback) =>
      _client.onPairingRequired(callback);

  void onPairingAccepted(void Function(String sessionToken) callback) =>
      _client.onPairingAccepted(callback);

  void setSessionToken(String? token) => _client.setSessionToken(token);

  Future<void> connect(ConnectionTarget target) => _client.connect(target);

  Future<void> disconnect() => _client.disconnect();
}
