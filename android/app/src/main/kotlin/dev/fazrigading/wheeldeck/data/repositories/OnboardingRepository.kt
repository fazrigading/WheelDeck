package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.SettingsStore

/// Single source of truth for first-run onboarding completion.
///
/// Owns the completion flag so the routing shell and the onboarding flow never
/// touch the settings store directly.
class OnboardingRepository(private val store: SettingsStore) {

    /// True once the user finished or skipped onboarding.
    suspend fun isComplete(): Boolean = store.loadBool(KEY) ?: false

    /// Persists onboarding completion.
    suspend fun setComplete() = store.saveBool(KEY, true)

    companion object {
        const val KEY = "wheeldeck.onboarding_complete"
    }
}
