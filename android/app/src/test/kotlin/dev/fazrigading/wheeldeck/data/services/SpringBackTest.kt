package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of mobile/test/data/services/spring_back_test.dart. Persistence moved
/// to the shared settings store, so the cases run through the repository.
class SpringBackTest {

    @Test
    fun `fresh install defaults to on`() = runTest {
        val repo = SettingsRepository(InMemorySettingsStore())

        assertTrue(repo.getSpringBack())
        assertTrue(SpringBack.FALLBACK)
    }

    @Test
    fun `round-trips off`() = runTest {
        val repo = SettingsRepository(InMemorySettingsStore())

        repo.setSpringBack(false)

        assertFalse(repo.getSpringBack())
    }

    @Test
    fun `reset to defaults restores on`() = runTest {
        val repo = SettingsRepository(InMemorySettingsStore(bools = mapOf(SpringBack.KEY to false)))

        repo.setSpringBack(SpringBack.FALLBACK)

        assertTrue(repo.getSpringBack())
    }

    @Test
    fun `a stored off is not overridden by the default`() = runTest {
        val repo = SettingsRepository(InMemorySettingsStore(bools = mapOf(SpringBack.KEY to false)))

        assertFalse(repo.getSpringBack())
    }
}
