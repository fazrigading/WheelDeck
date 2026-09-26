package dev.fazrigading.wheeldeck.data.services

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.settingsDataStore by preferencesDataStore(name = "wheeldeck_settings")

/// Typed key-value access to app settings, standing in for the Flutter app's
/// SharedPreferences. A null load means "never set", so each setting applies
/// its own default — see `SettingsRepository`.
///
/// Fresh start: nothing migrates from the Flutter app's SharedPreferences.
interface SettingsStore {
    suspend fun loadString(key: String): String?
    suspend fun saveString(key: String, value: String)
    suspend fun loadBool(key: String): Boolean?
    suspend fun saveBool(key: String, value: Boolean)
    suspend fun loadInt(key: String): Int?
    suspend fun saveInt(key: String, value: Int)
    suspend fun loadStringSet(key: String): Set<String>?
    suspend fun saveStringSet(key: String, value: Set<String>)
    suspend fun remove(key: String)
}

/// DataStore-backed settings store. One store for every key, matching how the
/// Dart app used a single SharedPreferences instance.
class DataStoreSettingsStore(context: Context) : SettingsStore {
    private val dataStore = context.applicationContext.settingsDataStore

    override suspend fun loadString(key: String): String? = dataStore.data.first()[stringPreferencesKey(key)]

    override suspend fun saveString(key: String, value: String) {
        dataStore.edit { it[stringPreferencesKey(key)] = value }
    }

    override suspend fun loadBool(key: String): Boolean? = dataStore.data.first()[booleanPreferencesKey(key)]

    override suspend fun saveBool(key: String, value: Boolean) {
        dataStore.edit { it[booleanPreferencesKey(key)] = value }
    }

    override suspend fun loadInt(key: String): Int? = dataStore.data.first()[intPreferencesKey(key)]

    override suspend fun saveInt(key: String, value: Int) {
        dataStore.edit { it[intPreferencesKey(key)] = value }
    }

    override suspend fun loadStringSet(key: String): Set<String>? =
        dataStore.data.first()[stringSetPreferencesKey(key)]

    override suspend fun saveStringSet(key: String, value: Set<String>) {
        dataStore.edit { it[stringSetPreferencesKey(key)] = value }
    }

    override suspend fun remove(key: String) {
        dataStore.edit { prefs ->
            prefs.remove(stringPreferencesKey(key))
            prefs.remove(booleanPreferencesKey(key))
            prefs.remove(intPreferencesKey(key))
            prefs.remove(stringSetPreferencesKey(key))
        }
    }
}
