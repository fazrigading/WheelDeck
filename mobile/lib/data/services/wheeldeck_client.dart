import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/models/connection_status.dart';
import '../../domain/models/connection_target.dart'
    show ConnectionTarget, defaultWheelDeckPort;
import '../../domain/models/pairing_challenge.dart';
import '../../domain/models/pairing_method.dart';
import 'dashboard_input.dart';
import 'input_mapping.dart';

/// The mobile end of the WheelDeck WebSocket protocol: dials the desktop,
/// frames `state` and `button` messages, tracks a monotonic sequence number,
/// and reports connection status. Pairing, discovery, and heartbeat wire into
/// this class from their own modules.
class WheelDeckClient {
  WheelDeckClient({
    required this.deviceId,
    Future<StreamChannel<dynamic>> Function(Uri uri)? connect,
    this.heartbeatInterval = defaultHeartbeatInterval,
    this.reconnectInterval = defaultReconnectInterval,
  }) : _connect = connect ?? _defaultConnect;

  static const int defaultPort = defaultWheelDeckPort;
  static const Duration defaultHeartbeatInterval = Duration(seconds: 2);
  static const Duration defaultReconnectInterval = Duration(seconds: 3);

  final String deviceId;
  final Duration heartbeatInterval;
  final Duration reconnectInterval;
  final Future<StreamChannel<dynamic>> Function(Uri uri) _connect;

  StreamChannel<dynamic>? _channel;
  StreamSubscription<dynamic>? _subscription;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _seq = 0;
  String? _sessionToken;
  ConnectionTarget? _lastTarget;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  void Function(ConnectionStatus status)? _onConnectionStatusChanged;
  void Function(PairingChallenge challenge)? _onPairingRequired;
  void Function(String sessionToken)? _onPairingAccepted;

  /// The most recent status, for widgets that build from state.
  ConnectionStatus get status => _status;

  /// The last connection target, used to reconnect after a lifecycle pause.
  ConnectionTarget? get lastTarget => _lastTarget;

  /// Registers the callback that receives connection status transitions.
  void onConnectionStatusChanged(
    void Function(ConnectionStatus status) callback,
  ) {
    _onConnectionStatusChanged = callback;
  }

  /// Registers the callback that fires when the desktop rejects a pairing.
  void onPairingRequired(void Function(PairingChallenge challenge) callback) {
    _onPairingRequired = callback;
  }

  /// Registers the callback that fires when the desktop accepts a pairing and
  /// issues a session token.
  void onPairingAccepted(void Function(String sessionToken) callback) {
    _onPairingAccepted = callback;
  }

  /// Sets the session token issued after a successful pairing. Heartbeats carry
  /// it so the desktop can resolve the sending device.
  void setSessionToken(String? token) {
    _sessionToken = token;
  }

  /// Dials [target] and switches to `connected` once the socket is ready.
  /// When no session token is known, the desktop cannot authorize input yet,
  /// so the status becomes `pairingRequired` and a PIN challenge fires instead
  /// of going straight to `connected`.
  Future<void> connect(ConnectionTarget target) async {
    _lastTarget = target;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setStatus(ConnectionStatus.connecting);

    final uri = target.resolve(defaultPort: defaultPort);
    final channel = await _connect(uri);

    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (_) => _handleConnectionClosed(),
      onDone: _handleConnectionClosed,
    );

    _startHeartbeat();
    _sendHeartbeat();
    if (_sessionToken == null) {
      _setStatus(ConnectionStatus.pairingRequired);
      _onPairingRequired?.call(
        const PairingChallenge(method: PairingMethod.pin),
      );
    } else {
      _setStatus(ConnectionStatus.connected);
    }
  }

  /// Closes the socket and returns to `disconnected`.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastTarget = null;
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  /// Sends a `state` frame with an incrementing sequence number.
  void sendState({
    required double steering,
    required double accelerator,
    required double brake,
    required double clutch,
  }) {
    _send({
      'type': 'state',
      'seq': ++_seq,
      'steering': steering,
      'accelerator': accelerator,
      'brake': brake,
      'clutch': clutch,
    });
  }

  /// Sends a `button` frame using the wire values shared with the desktop.
  void sendButtonEvent(ControlId control, ActionType action) {
    _send({
      'type': 'button',
      'control': control.wireValue,
      'action': action.wireValue,
    });
  }

  /// Sends a `pair_request` for the current device.
  void submitPairingCode(String code) {
    _send({
      'type': 'pair_request',
      'device_id': deviceId,
      'code': code,
    });
  }

  /// Sends the desired dashboard input mapping (`keyboard` or `gamepad`).
  void sendMappingMode(InputMapping mapping) {
    _send({
      'type': 'mapping',
      'mode': mapping.wireValue,
    });
  }

  void _sendHeartbeat() {
    _send({
      'type': 'heartbeat',
      'session_token': ?_sessionToken,
    });
  }

  void _onMessage(dynamic data) {
    if (data is! String) {
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return;
    }

    if (decoded is! Map<String, dynamic>) {
      return;
    }

    switch (decoded['type']) {
      case 'pair_response':
        final accepted = decoded['accepted'] == true;
        if (accepted) {
          final sessionToken = decoded['session_token'];
          if (sessionToken is String) {
            _sessionToken = sessionToken;
            _onPairingAccepted?.call(sessionToken);
          }

          _setStatus(ConnectionStatus.connected);
        } else {
          _setStatus(ConnectionStatus.pairingRequired);
          _onPairingRequired?.call(
            const PairingChallenge(method: PairingMethod.pin),
          );
        }
    }
  }

  void _handleConnectionClosed() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    final target = _lastTarget;
    if (target == null) {
      _setStatus(ConnectionStatus.disconnected);
      return;
    }

    _setStatus(ConnectionStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectInterval, () {
      connect(target);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    channel.sink.add(jsonEncode(message));
  }

  void _setStatus(ConnectionStatus next) {
    if (_status == next) {
      return;
    }

    _status = next;
    _onConnectionStatusChanged?.call(next);
  }

  static Future<StreamChannel<dynamic>> _defaultConnect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return channel;
  }
}
