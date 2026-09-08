import '../services/pairing.dart';

/// Single source of truth for the pairing session.
///
/// Reuses [PairingController] (raw token store + client wiring) so ViewModels
/// depend on a repository, not on the service directly.
class SessionRepository {
  SessionRepository({required this._pairing});

  final PairingController _pairing;

  /// Loads the persisted token and restores it onto the client.
  Future<String?> restoreSession() => _pairing.restoreSession();

  /// Sends the pairing code to the desktop for validation.
  void submitPairingCode(String code) => _pairing.submitPairingCode(code);
}
