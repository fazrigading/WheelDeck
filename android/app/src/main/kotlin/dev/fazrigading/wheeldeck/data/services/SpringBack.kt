package dev.fazrigading.wheeldeck.data.services

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.springBackDataStore by preferencesDataStore(name = "wheeldeck_spring_back")

/// Persists the rotatable wheel's spring-back toggle. A null [load] means the
/// user has never set it.
interface SpringBackStore {
    suspend fun load(): Boolean?
    suspend fun save(value: Boolean)
}

/// DataStore-backed store for the spring-back toggle.
class DataStoreSpringBackStore(context: Context) : SpringBackStore {
    private val dataStore = context.applicationContext.springBackDataStore
    private val key = booleanPreferencesKey(KEY)

    override suspend fun load(): Boolean? = dataStore.data.first()[key]

    override suspend fun save(value: Boolean) {
        dataStore.edit { it[key] = value }
    }

    companion object {
        const val KEY = "wheeldeck.spring_back"
    }
}

/// Whether the rotatable wheel animates back to zero on release. When off, the
/// wheel holds its released angle and steering stays there until the driver
/// drags it back. Gyro steering ignores it, and so do pedals — the pedal
/// release curve is [PedalInput]'s.
///
/// Applies the [FALLBACK] default over an unset store, so the setting layer
/// never has to know the default.
class SpringBack(private val store: SpringBackStore) {
    suspend fun load(): Boolean = store.load() ?: FALLBACK

    suspend fun save(value: Boolean) = store.save(value)

    companion object {
        const val FALLBACK = true
    }
}
