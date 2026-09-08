import 'package:flutter/foundation.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/server_discovery_repository.dart';
import '../../../../data/repositories/session_repository.dart';
import '../../../../domain/models/connection_status.dart';
import '../../../../domain/models/connection_target.dart';
import '../../../../domain/models/discovered_server.dart';
import '../../../../domain/models/pairing_challenge.dart';
import '../../../../data/services/wheeldeck_client.dart';

/// Presentation state for the connection/pairing flow.
///
/// Owns no transport: [ServerDiscoveryRepository], [ConnectionRepository], and
/// [SessionRepository] are injected via the constructor. Exposes immutable
/// snapshots; the View renders via `ListenableBuilder`.
class ConnectionViewModel extends ChangeNotifier {
  ConnectionViewModel({
    required ServerDiscoveryRepository discoveryRepository,
    required ConnectionRepository connectionRepository,
    required SessionRepository sessionRepository,
    int? defaultPort,
  })  : _discoveryRepository = discoveryRepository,
        _connectionRepository = connectionRepository,
        _sessionRepository = sessionRepository,
        defaultPort = defaultPort ?? WheelDeckClient.defaultPort,
        _status = connectionRepository.status {
    _connectionRepository.onStatusChanged(_onStatusChanged);
    _connectionRepository.onPairingRequired(_onPairingRequired);
  }

  final ServerDiscoveryRepository _discoveryRepository;
  final ConnectionRepository _connectionRepository;
  final SessionRepository _sessionRepository;

  /// Default port shown in the manual entry field.
  final int defaultPort;

  ConnectionStatus _status;
  PairingChallenge? _pairingChallenge;
  bool _pairingError = false;
  bool _pairingSubmitted = false;
  bool _isPaused = false;

  ConnectionStatus get status => _status;
  List<DiscoveredServer> get servers => _discoveryRepository.servers;
  PairingChallenge? get pairingChallenge => _pairingChallenge;
  bool get pairingError => _pairingError;
  bool get isPaused => _isPaused;

  /// Runs an mDNS discovery sweep and updates [servers].
  Future<void> refreshDiscovery() async {
    await _discoveryRepository.refresh();
    notifyListeners();
  }

  /// Builds a manual target from user-entered host and optional port.
  Future<void> connectManual({required String host, int? port}) => connect(
        ServerDiscoveryRepository.manualTarget(
          host: host,
          port: port ?? defaultPort,
        ),
      );

  /// Connects to [target], restoring any persisted session token first.
  Future<void> connect(ConnectionTarget target) async {
    await _sessionRepository.restoreSession();
    await _connectionRepository.connect(target);
  }

  /// Closes the socket and returns to `disconnected`.
  Future<void> disconnect() => _connectionRepository.disconnect();

  /// Pauses the session on lifecycle interruption. Disconnects so the desktop
  /// neutralizes output.
  Future<void> pause() async {
    if (_isPaused) return;
    _isPaused = true;
    await _connectionRepository.disconnect();
    notifyListeners();
  }

  /// Clears the pause flag so the UI can re-confirm calibration.
  void resume() {
    _isPaused = false;
    notifyListeners();
  }

  /// Sends the pairing code entered by the user.
  void submitPairingCode(String code) {
    _pairingSubmitted = true;
    _pairingError = false;
    _sessionRepository.submitPairingCode(code);
  }

  void _onStatusChanged(ConnectionStatus status) {
    if (status == _status) return;
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
