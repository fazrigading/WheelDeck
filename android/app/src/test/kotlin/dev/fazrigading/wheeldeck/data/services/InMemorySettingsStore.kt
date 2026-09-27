package dev.fazrigading.wheeldeck.data.services

/// In-memory [SettingsStore] for tests: a fresh instance is a fresh install,
/// pre-seed it to simulate stored settings.
class InMemorySettingsStore(
    strings: Map<String, String> = emptyMap(),
    bools: Map<String, Boolean> = emptyMap(),
    ints: Map<String, Int> = emptyMap(),
    stringSets: Map<String, Set<String>> = emptyMap(),
) : SettingsStore {
    private val storedStrings = strings.toMutableMap()
    private val storedBools = bools.toMutableMap()
    private val storedInts = ints.toMutableMap()
    private val storedStringSets = stringSets.mapValues { it.value.toSet() }.toMutableMap()

    override suspend fun loadString(key: String): String? = storedStrings[key]

    override suspend fun saveString(key: String, value: String) {
        storedStrings[key] = value
    }

    override suspend fun loadBool(key: String): Boolean? = storedBools[key]

    override suspend fun saveBool(key: String, value: Boolean) {
        storedBools[key] = value
    }

    override suspend fun loadInt(key: String): Int? = storedInts[key]

    override suspend fun saveInt(key: String, value: Int) {
        storedInts[key] = value
    }

    override suspend fun loadStringSet(key: String): Set<String>? = storedStringSets[key]

    override suspend fun saveStringSet(key: String, value: Set<String>) {
        storedStringSets[key] = value.toSet()
    }

    override suspend fun remove(key: String) {
        storedStrings.remove(key)
        storedBools.remove(key)
        storedInts.remove(key)
        storedStringSets.remove(key)
    }
}
