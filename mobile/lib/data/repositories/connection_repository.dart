import '../../input/dashboard_input.dart';
import '../../input/input_mapping.dart';
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

  /// Raw client for screens that still bind to it directly (settings,
  /// driving view during migration). New code should use this repository.
  WheelDeckClient get client => _client;

  /// Sends a `state` frame with the current input values.
  void sendState({
    required double steering,
    required double accelerator,
    required double brake,
    required double clutch,
  }) =>
      _client.sendState(
        steering: steering,
        accelerator: accelerator,
        brake: brake,
        clutch: clutch,
      );

  /// Sends a `button` frame for a dashboard control event.
  void sendButtonEvent(ControlId control, ActionType action) =>
      _client.sendButtonEvent(control, action);

  /// Sends the desired dashboard input mapping (`keyboard` or `gamepad`).
  void sendMappingMode(InputMapping mapping) =>
      _client.sendMappingMode(mapping);
}
