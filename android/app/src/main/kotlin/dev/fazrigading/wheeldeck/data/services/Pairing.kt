package dev.fazrigading.wheeldeck.data.services

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private val Context.sessionTokenDataStore by preferencesDataStore(name = "wheeldeck_session")

/// Persists the session token issued after a successful pairing.
interface SessionTokenStore {
    suspend fun load(): String?
    suspend fun save(token: String)
}

/// Stores the token in DataStore Preferences.
class DataStoreSessionTokenStore(context: Context) : SessionTokenStore {
    private val dataStore = context.applicationContext.sessionTokenDataStore

    override suspend fun load(): String? =
        dataStore.data.first()[stringPreferencesKey(KEY)]

    override suspend fun save(token: String) {
        dataStore.edit { it[stringPreferencesKey(KEY)] = token }
    }

    companion object {
        const val KEY = "wheeldeck.session_token"
    }
}

/// Drives the pairing flow: submits the entered or scanned code, persists the
/// issued session token, and restores it on later sessions so re-pairing can be
/// skipped.
class PairingController(
    private val store: SessionTokenStore,
    private val client: WheelDeckClient,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
) {
    init {
        client.onPairingAccepted { token -> scope.launch { store.save(token) } }
    }

    /// Loads the session token persisted from a previous session and restores it
    /// onto the client so the next connection can skip pairing.
    suspend fun restoreSession(): String? {
        val token = store.load()
        if (token != null) {
            client.setSessionToken(token)
        }
        return token
    }

    /// Sends the pairing code to the desktop for validation.
    fun submitPairingCode(code: String) = client.submitPairingCode(code)
}
