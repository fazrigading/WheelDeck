package dev.fazrigading.wheeldeck.data.services

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// Task 14's only real logic: the hardcoded external URLs, and the GitHub stars
/// badge. Both are device-independent, so both are tested here; the screens that
/// render them need a device.
class ExternalLinksTest {

    @Test
    fun `every link is an absolute https URL`() {
        val urls = ExternalLinks.all.map { it.url } + ExternalLinks.REPO_URL

        for (url in urls) {
            assertTrue(url, url.startsWith("https://"))
            assertTrue(url, url.substringAfter("https://").isNotBlank())
            assertTrue("$url has no path or query", url.count { it == '/' } >= 3)
        }
    }

    @Test
    fun `no two links share a URL`() {
        val urls = ExternalLinks.all.map { it.url }

        assertEquals(urls.size, urls.toSet().size)
    }

    @Test
    fun `the repo and its API are the same repository`() {
        assertEquals("fazrigading/WheelDeck", ExternalLinks.REPO_API.substringAfter("/repos/"))
        assertEquals("fazrigading/WheelDeck", ExternalLinks.REPO_URL.substringAfter("github.com/"))
    }

    @Test
    fun `the donate links are the three the Dart app offers`() {
        assertEquals(
            listOf("buymeacoffee.com", "paypal.me", "ko-fi.com"),
            ExternalLinks.all.map { it.url.substringAfter("https://").substringBefore("/") },
        )
    }

    @Test
    fun `stars are read from the GitHub payload`() {
        assertEquals(1234, parseStars("""{"stargazers_count": 1234, "name": "WheelDeck"}"""))
    }

    @Test
    fun `an absent or mistyped count reads as unknown`() {
        assertNull(parseStars("""{"name": "WheelDeck"}"""))
        assertNull(parseStars("""{"stargazers_count": "many"}"""))
        assertNull(parseStars("not json at all"))
    }
}

class GitHubStarsTest {

    private fun server(): MockWebServer = MockWebServer().apply { start() }

    /// The real API URL pointed at the local server, so the request path under
    /// test is the production one.
    private fun sourceFor(server: MockWebServer) = OkHttpGitHubStars(
        ExternalLinks.REPO_API.replace("https://api.github.com", server.url("/").toString().trimEnd('/')),
    )

    @Test
    fun `a 200 returns the star count`() = runTest {
        val server = server()
        server.enqueue(MockResponse().setBody("""{"stargazers_count": 42}"""))
        val source = sourceFor(server)

        assertEquals(42, source.fetch())
        server.shutdown()
    }

    /// Offline, rate-limited, or a moved repo: the badge shows a dash rather than
    /// a wrong number, so the screen must not treat this as an error.
    @Test
    fun `a non-200 reads as unknown`() = runTest {
        val server = server()
        server.enqueue(MockResponse().setResponseCode(403).setBody("rate limited"))
        val source = sourceFor(server)

        assertNull(source.fetch())
        server.shutdown()
    }

    @Test
    fun `a malformed body reads as unknown`() = runTest {
        val server = server()
        server.enqueue(MockResponse().setBody("<html>nope</html>"))
        val source = sourceFor(server)

        assertNull(source.fetch())
        server.shutdown()
    }

    @Test
    fun `the request goes to the repository API path`() = runTest {
        val server = server()
        server.enqueue(MockResponse().setBody("""{"stargazers_count": 1}"""))
        val source = sourceFor(server)

        source.fetch()

        assertEquals(
            "/repos/fazrigading/WheelDeck",
            server.takeRequest().path,
        )
        server.shutdown()
    }
}
