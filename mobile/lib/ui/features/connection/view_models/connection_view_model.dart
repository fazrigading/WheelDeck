import 'package:flutter/foundation.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/paired_device_repository.dart';
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
    required this._discoveryRepository,
    required ConnectionRepository connectionRepository,
    required this._sessionRepository,
    PairedDeviceRepository? pairedDeviceRepository,
    int? defaultPort,
  })  : _pairedDeviceRepository =
            pairedDeviceRepository ?? PairedDeviceRepository(),
        _connectionRepository = connectionRepository,
        defaultPort = defaultPort ?? WheelDeckClient.defaultPort,
        _status = connectionRepository.status {
    _connectionRepository.onStatusChanged(_onStatusChanged);
    _connectionRepository.onPairingRequired(_onPairingRequired);
    _loadPaired();
  }

  final ServerDiscoveryRepository _discoveryRepository;
  final ConnectionRepository _connectionRepository;
  final SessionRepository _sessionRepository;
  final PairedDeviceRepository _pairedDeviceRepository;

  /// Default port shown in the manual entry field.
  final int defaultPort;

  ConnectionStatus _status;
  PairingChallenge? _pairingChallenge;
  bool _pairingError = false;
  bool _pairingSubmitted = false;
  bool _isPaused = false;
  Set<String> _pairedIds = {};

  ConnectionStatus get status => _status;
  List<DiscoveredServer> get servers => _discoveryRepository.servers;

  /// Previously paired (host:port seen in successful connection).
  List<DiscoveredServer> get pairedServers => servers
      .where((s) => PairedDeviceRepository.isPairedSync(s, _pairedIds))
      .toList();

  /// Discovered but not yet paired.
  List<DiscoveredServer> get unpairedServers => servers
      .where((s) => !PairedDeviceRepository.isPairedSync(s, _pairedIds))
      .toList();

  /// Cached paired ids for quick checks.
  Set<String> get pairedIds => _pairedIds;

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

  /// Pauses the session on lifecycle interruption. Keeps the WebSocket open
  /// for fast reconnect — the driving view stops sending input instead.
  Future<void> pause() async {
    if (_isPaused) return;
    _isPaused = true;
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

  Future<void> _loadPaired() async {
    try {
      final ids = await _pairedDeviceRepository.load();
      _pairedIds = ids.toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _rememberPaired(ConnectionTarget? target) async {
    final host = target?.ipAddress;
    final port = target?.port ?? defaultPort;
    if (host == null || host.isEmpty) return;
    try {
      await _pairedDeviceRepository.addPaired(host, port);
      _pairedIds = {..._pairedIds, PairedDeviceRepository.idOfHostPort(host, port)};
      notifyListeners();
    } catch (_) {}
  }

  void _onStatusChanged(ConnectionStatus status) {
    if (status == _status) return;
    _status = status;
    if (status == ConnectionStatus.connected) {
      _pairingChallenge = null;
      _pairingError = false;
      _pairingSubmitted = false;
      // Remember paired device on successful connect
      _rememberPaired(_connectionRepository.lastTarget);
    }
    notifyListeners();
  }

  void _onPairingRequired(PairingChallenge challenge) {
    _pairingChallenge = challenge;
    _pairingError = _pairingSubmitted;
    notifyListeners();
  }
}
