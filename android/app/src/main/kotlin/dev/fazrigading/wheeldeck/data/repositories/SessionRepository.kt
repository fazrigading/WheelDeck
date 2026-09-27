package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.PairingController

/// Single source of truth for the pairing session.
///
/// Reuses [PairingController] (raw token store + client wiring) so ViewModels
/// depend on a repository, not on the service directly.
class SessionRepository(private val pairing: PairingController) {
    /// Loads the persisted token and restores it onto the client.
    suspend fun restoreSession(): String? = pairing.restoreSession()

    /// Sends the pairing code to the desktop for validation.
    fun submitPairingCode(code: String) = pairing.submitPairingCode(code)

    /// Drops the persisted session token so the next connect re-pairs.
    suspend fun forgetSession() = pairing.forgetSession()
}
