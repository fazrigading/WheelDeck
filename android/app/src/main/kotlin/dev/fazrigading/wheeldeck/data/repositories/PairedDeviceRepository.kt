package dev.fazrigading.wheeldeck.data.repositories

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.pairedDevicesDataStore by preferencesDataStore(name = "wheeldeck_paired_devices")

/// Persists paired device ids (`host:port`) so Connect can split paired vs new.
/// Fresh start — nothing migrates from the Flutter app's SharedPreferences.
class PairedDeviceRepository(context: Context, private val prefsKey: String = DEFAULT_KEY) {
    private val dataStore = context.applicationContext.pairedDevicesDataStore

    /// Live paired-id set; collects in ViewModels.
    val ids: Flow<Set<String>> = dataStore.data.map { prefs -> prefs[stringSetPreferencesKey(prefsKey)].orEmpty() }

    suspend fun load(): Set<String> = ids.first()

    fun idOf(server: DiscoveredServer) = idOfPair(server.host, server.port)

    fun idOfHostPort(host: String, port: Int) = idOfPair(host, port)

    suspend fun isPaired(server: DiscoveredServer): Boolean = idOf(server) in load()

    /// Adds `host:port` to the paired set if absent.
    suspend fun addPaired(host: String, port: Int) {
        val id = idOfHostPort(host, port)
        dataStore.edit { prefs ->
            val current = prefs[stringSetPreferencesKey(prefsKey)].orEmpty()
            if (id !in current) prefs[stringSetPreferencesKey(prefsKey)] = current + id
        }
    }

    companion object {
        const val DEFAULT_KEY = "wheeldeck.paired_devices"

        fun idOfPair(host: String, port: Int) = "$host:$port"

        /// Sync check against a cached set (for ViewModel hot path).
        fun isPairedSync(server: DiscoveredServer, cached: Set<String>) = idOfPair(server.host, server.port) in cached
    }
}
