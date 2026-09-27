package dev.fazrigading.wheeldeck.data.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Coffee
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Payments
import androidx.compose.ui.graphics.vector.ImageVector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/// One outbound link the About and Donate screens offer. The icon lives here
/// rather than in the screen so a route cannot be added without one, and so the
/// same glyph does not stand in for two different services.
data class ExternalLink(
    val label: String,
    val url: String,
    /// A short line under the label explaining what tapping it does.
    val description: String,
    val icon: ImageVector,
)

/// The hardcoded outbound URLs. Data, not composables, so a typo in one of them
/// is a test failure rather than a broken button nobody notices.
object ExternalLinks {
    const val REPO_URL = "https://github.com/fazrigading/WheelDeck"
    const val REPO_API = "https://api.github.com/repos/fazrigading/WheelDeck"

    /// The three donation routes, in the order the Dart app lists them.
    val all = listOf(
        ExternalLink(
            "Buy Me a Coffee",
            "https://buymeacoffee.com/fazrigading",
            "One-time support — the fastest way to say thanks",
            Icons.Filled.Coffee,
        ),
        ExternalLink(
            "PayPal",
            "https://paypal.me/fazrigading",
            "Direct transfer via PayPal",
            Icons.Filled.Payments,
        ),
        ExternalLink(
            "Ko-fi",
            "https://ko-fi.com/fazrigading",
            "Support with a monthly or one-off tip",
            Icons.Filled.Favorite,
        ),
    )
}

/// Opens a URL outside the app, behind a seam so the screens can be driven in a
/// test without an `Intent`.
interface LinkOpener {
    /// Returns true when something handled the URL. False means the caller should
    /// tell the driver it could not be opened, rather than failing silently.
    suspend fun open(url: String): Boolean
}

/// The platform [LinkOpener]: `Intent.ACTION_VIEW`, which hands the URL to
/// whatever app the driver uses for it. No browser is assumed to be installed.
///
/// `FLAG_ACTIVITY_NEW_TASK` is required, not optional: the coordinator holds the
/// *application* context so the opener outlives any Activity, and `startActivity`
/// from a non-Activity context throws without that flag.
class AndroidLinkOpener(private val context: Context) : LinkOpener {
    override suspend fun open(url: String): Boolean = withContext(Dispatchers.Main) {
        try {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (_: Exception) {
            // No https handler, a malformed URL, a background-activity restriction.
            // Every one of them is the same thing to the driver: the link did not
            // open, and they are told so.
            false
        }
    }
}

/// Where the About screen's star count comes from. Separate from the screen so
/// the failure path — offline, rate-limited, repo renamed — is testable.
interface GitHubStarsSource {
    /// The star count, or null when it could not be read. Null is not an error:
    /// the About screen shows a dash and nothing else changes.
    suspend fun fetch(): Int?
}

/// Reads `stargazers_count` from a GitHub repository payload. Returns null for
/// anything unexpected rather than throwing, so a proxy error page cannot crash
/// the screen.
fun parseStars(body: String): Int? = try {
    Json.parseToJsonElement(body).jsonObject["stargazers_count"]?.jsonPrimitive?.content?.toInt()
} catch (_: Exception) {
    null
}

/// [GitHubStarsSource] over the GitHub API, ported from the Dart About screen:
/// a five-second timeout, and a failure that leaves the badge as a placeholder.
class OkHttpGitHubStars(
    private val apiUrl: String = ExternalLinks.REPO_API,
    private val client: OkHttpClient = defaultClient(),
) : GitHubStarsSource {
    override suspend fun fetch(): Int? = try {
        client.newCall(Request.Builder().url(apiUrl).build()).execute().use { response ->
            if (response.isSuccessful) parseStars(response.body?.string().orEmpty()) else null
        }
    } catch (_: Exception) {
        null
    }

    companion object {
        fun defaultClient() = OkHttpClient.Builder()
            .callTimeout(5, TimeUnit.SECONDS)
            .build()
    }
}
