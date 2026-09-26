package dev.fazrigading.wheeldeck.data.services

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of mobile/test/data/services/spring_back_test.dart.
class SpringBackTest {

    private class FakeStore(initial: Boolean? = null) : SpringBackStore {
        var stored: Boolean? = initial
        override suspend fun load(): Boolean? = stored
        override suspend fun save(value: Boolean) {
            stored = value
        }
    }

    @Test
    fun `fresh install defaults to on`() = runTest {
        assertTrue(SpringBack(FakeStore()).load())
        assertTrue(SpringBack.FALLBACK)
    }

    @Test
    fun `round-trips off`() = runTest {
        val springBack = SpringBack(FakeStore())

        springBack.save(false)

        assertFalse(springBack.load())
    }

    @Test
    fun `reset to defaults restores on`() = runTest {
        val springBack = SpringBack(FakeStore(initial = false))

        springBack.save(SpringBack.FALLBACK)

        assertTrue(springBack.load())
    }

    @Test
    fun `a stored off is not overridden by the default`() = runTest {
        assertFalse(SpringBack(FakeStore(initial = false)).load())
    }
}
