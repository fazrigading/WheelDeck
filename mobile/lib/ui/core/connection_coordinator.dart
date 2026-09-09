import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../data/repositories/connection_repository.dart';
import '../../data/repositories/server_discovery_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/connection_status.dart';
import '../../domain/models/connection_target.dart';
import '../../domain/models/discovered_server.dart';
import '../../domain/models/pairing_challenge.dart';
import '../../data/services/discovery.dart';
import '../../data/services/pairing.dart';
import '../../data/services/wheeldeck_client.dart';
import '../features/connection/view_models/connection_view_model.dart';

/// App-level facade that owns the network layer and exposes reactive
/// connection state to the UI.
///
/// The layered stack lives underneath: stateless services
/// ([WheelDeckClient], [ServerDiscovery], [PairingController]), repositories
/// ([ServerDiscoveryRepository], [ConnectionRepository], [SessionRepository]),
/// and [ConnectionViewModel]. This class keeps the pre-refactor public API so
/// existing screens and tests keep working while new code binds to
/// [viewModel] directly via `ListenableBuilder`.
class ConnectionCoordinator extends ChangeNotifier {
  ConnectionCoordinator._({
    required this.deviceId,
    required this.defaultHost,
    required this.client,
    required this.discovery,
    required this.pairing,
    required this._discoveryRepository,
    required this._connectionRepository,
    required this._sessionRepository,
    required this._viewModel,
  }) {
    _viewModel.addListener(notifyListeners);
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
    final discoveryRepository =
        ServerDiscoveryRepository(discovery: discovery);
    final connectionRepository = ConnectionRepository(client: client);
    final sessionRepository = SessionRepository(pairing: pairing);
    final resolvedPort = defaultPort ?? WheelDeckClient.defaultPort;
    final viewModel = ConnectionViewModel(
      discoveryRepository: discoveryRepository,
      connectionRepository: connectionRepository,
      sessionRepository: sessionRepository,
      defaultPort: resolvedPort,
    );

    return ConnectionCoordinator._(
      deviceId: deviceId,
      defaultHost: defaultHost,
      client: client,
      discovery: discovery,
      pairing: pairing,
      discoveryRepository: discoveryRepository,
      connectionRepository: connectionRepository,
      sessionRepository: sessionRepository,
      viewModel: viewModel,
    );
  }

  final String deviceId;

  /// Default host shown in the manual entry field, if known.
  final String? defaultHost;

  /// Default port shown in the manual entry field.
  int get defaultPort => _viewModel.defaultPort;

  final WheelDeckClient client;
  final ServerDiscovery discovery;
  final PairingController pairing;

  final ServerDiscoveryRepository _discoveryRepository;
  final ConnectionRepository _connectionRepository;
  final SessionRepository _sessionRepository;
  final ConnectionViewModel _viewModel;

  /// Layered stack for new code: bind with `ListenableBuilder`.
  ConnectionViewModel get viewModel => _viewModel;
  ServerDiscoveryRepository get discoveryRepository => _discoveryRepository;
  ConnectionRepository get connectionRepository => _connectionRepository;
  SessionRepository get sessionRepository => _sessionRepository;

  /// Current connection status, mirrored from [viewModel].
  ConnectionStatus get status => _viewModel.status;

  /// Servers found during the most recent discovery sweep.
  List<DiscoveredServer> get servers => _viewModel.servers;

  /// The active pairing challenge, if the desktop is waiting for a code.
  PairingChallenge? get pairingChallenge => _viewModel.pairingChallenge;

  /// True when a submitted PIN was rejected and the prompt should show an error.
  bool get pairingError => _viewModel.pairingError;

  /// True when the session is paused due to a lifecycle interruption (call,
  /// screen lock, or backgrounding). Input should not be sent while paused.
  bool get isPaused => _viewModel.isPaused;

  /// Runs an mDNS discovery sweep and updates [servers].
  Future<void> refreshDiscovery() => _viewModel.refreshDiscovery();

  /// Builds a manual target from user-entered host and optional port, then
  /// connects (restoring a prior session token first to skip re-pairing).
  Future<void> connectManual({
    required String host,
    int? port,
  }) =>
      _viewModel.connectManual(host: host, port: port);

  /// Connects to [target], restoring any persisted session token first.
  Future<void> connect(ConnectionTarget target) => _viewModel.connect(target);

  /// Closes the socket and returns to `disconnected`.
  Future<void> disconnect() => _viewModel.disconnect();

  /// Pauses the session due to a lifecycle interruption (call, screen lock,
  /// or backgrounding). Disconnects from the desktop so it neutralizes output.
  Future<void> pause() => _viewModel.pause();

  /// Resumes after a lifecycle interruption. Clears the pause flag so the UI
  /// can re-confirm calibration before sending input.
  void resume() => _viewModel.resume();

  /// Sends the pairing code entered by the user.
  void submitPairingCode(String code) => _viewModel.submitPairingCode(code);

  @override
  void dispose() {
    _viewModel.removeListener(notifyListeners);
    _viewModel.dispose();
    super.dispose();
  }
}
