import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';

import '../network/discovery.dart';
import '../network/pairing.dart';
import '../network/wheeldeck_client.dart';

/// App-level state that owns the network layer and exposes reactive
/// connection state to the UI.
///
/// Wires together [WheelDeckClient], [ServerDiscovery], and
/// [PairingController] into a single [ChangeNotifier] so the UI can react to
/// status changes, discovery results, and pairing challenges without each
/// screen holding its own subscriptions.
class ConnectionCoordinator extends ChangeNotifier {
  ConnectionCoordinator._({
    required this.deviceId,
    required this.defaultHost,
    required this.defaultPort,
    required this.client,
    required this.discovery,
    required this.pairing,
  }) : _status = client.status {
    client.onConnectionStatusChanged(_onStatusChanged);
    client.onPairingRequired(_onPairingRequired);
  }

  factory ConnectionCoordinator({
    required String deviceId,
    String? defaultHost,
    int? defaultPort,
    Future<StreamChannel<dynamic>> Function(Uri uri)? connect,
    ServerResolver? resolver,
    SessionTokenStore? store,
  }) {
    final client = WheelDeckClient(
      deviceId: deviceId,
      connect: connect,
    );
    final discovery = ServerDiscovery(resolve: resolver);
    final pairing = PairingController(
      store: store ?? SharedPreferencesSessionTokenStore(),
      client: client,
    );

    return ConnectionCoordinator._(
      deviceId: deviceId,
      defaultHost: defaultHost,
      defaultPort: defaultPort ?? WheelDeckClient.defaultPort,
      client: client,
      discovery: discovery,
      pairing: pairing,
    );
  }

  final String deviceId;

  /// Default host shown in the manual entry field, if known.
  final String? defaultHost;

  /// Default port shown in the manual entry field.
  final int defaultPort;

  final WheelDeckClient client;
  final ServerDiscovery discovery;
  final PairingController pairing;

  List<DiscoveredServer> _servers = [];
  ConnectionStatus _status = ConnectionStatus.disconnected;
  PairingChallenge? _pairingChallenge;
  bool _pairingError = false;
  bool _pairingSubmitted = false;
  bool _isPaused = false;

  /// Current connection status, mirrored from [client].
  ConnectionStatus get status => _status;

  /// Servers found during the most recent discovery sweep.
  List<DiscoveredServer> get servers => List.unmodifiable(_servers);

  /// The active pairing challenge, if the desktop is waiting for a code.
  PairingChallenge? get pairingChallenge => _pairingChallenge;

  /// True when a submitted PIN was rejected and the prompt should show an error.
  bool get pairingError => _pairingError;

  /// True when the session is paused due to a lifecycle interruption (call,
  /// screen lock, or backgrounding). Input should not be sent while paused.
  bool get isPaused => _isPaused;

  /// Runs an mDNS discovery sweep and updates [servers].
  Future<void> refreshDiscovery() async {
    final servers = await discovery.discover();
    _servers = servers;
    notifyListeners();
  }

  /// Builds a manual target from user-entered host and optional port, then
  /// connects (restoring a prior session token first to skip re-pairing).
  Future<void> connectManual({
    required String host,
    int? port,
  }) =>
      connect(
        ServerDiscovery.manualTarget(host: host, port: port ?? defaultPort),
      );

  /// Connects to [target], restoring any persisted session token first.
  Future<void> connect(ConnectionTarget target) async {
    await pairing.restoreSession();
    await client.connect(target);
  }

  /// Closes the socket and returns to `disconnected`.
  Future<void> disconnect() => client.disconnect();

  /// Pauses the session due to a lifecycle interruption (call, screen lock,
  /// or backgrounding). Disconnects from the desktop so it neutralizes output.
  Future<void> pause() async {
    if (_isPaused) return;
    _isPaused = true;
    await client.disconnect();
    notifyListeners();
  }

  /// Resumes after a lifecycle interruption. Clears the pause flag so the UI
  /// can re-confirm calibration before sending input.
  void resume() {
    _isPaused = false;
    notifyListeners();
  }

  /// Sends the pairing code entered by the user.
  void submitPairingCode(String code) {
    _pairingSubmitted = true;
    _pairingError = false;
    pairing.submitPairingCode(code);
  }

  void _onStatusChanged(ConnectionStatus status) {
    if (status == _status) {
      return;
    }

    _status = status;
    if (status == ConnectionStatus.connected) {
      _pairingChallenge = null;
      _pairingError = false;
      _pairingSubmitted = false;
    }

    notifyListeners();
  }

  void _onPairingRequired(PairingChallenge challenge) {
    _pairingChallenge = challenge;
    _pairingError = _pairingSubmitted;
    notifyListeners();
  }
}
