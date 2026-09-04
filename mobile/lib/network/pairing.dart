import 'package:shared_preferences/shared_preferences.dart';

import 'wheeldeck_client.dart';

/// Persists the session token issued after a successful pairing.
abstract class SessionTokenStore {
  Future<String?> load();
  Future<void> save(String token);
}

/// Stores the token in the platform's shared preferences. Works across the
/// native targets and the iOS PWA (shared_preferences uses localStorage on web).
class SharedPreferencesSessionTokenStore implements SessionTokenStore {
  static const String _key = 'wheeldeck.session_token';

  @override
  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }
}

/// Drives the pairing flow: submits the entered or scanned code, persists the
/// issued session token, and restores it on later sessions so re-pairing can be
/// skipped.
class PairingController {
  PairingController({
    required this.store,
    required this.client,
  }) {
    client.onPairingAccepted(store.save);
  }

  final SessionTokenStore store;
  final WheelDeckClient client;

  /// Loads the session token persisted from a previous session, if any.
  Future<String?> restoreSession() => store.load();

  /// Sends the pairing code to the desktop for validation.
  void submitPairingCode(String code) => client.submitPairingCode(code);
}
