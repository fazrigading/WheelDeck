package dev.fazrigading.wheeldeck.ui.core

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import dev.fazrigading.wheeldeck.data.services.LinkOpener
import kotlinx.coroutines.launch

/// Returns a callback that opens [url] outside the app and reports a failure to
/// the driver.
///
/// Both link-bearing screens need the same "launch, and if nothing handled it,
/// say so" shape, and a silent no-op looks like a broken app — so the report
/// lives here instead of being copied at each call site.
@Composable
fun rememberLinkLauncher(
    linkOpener: LinkOpener,
    snackbar: SnackbarHostState,
): (String) -> Unit {
    val scope = rememberCoroutineScope()
    return { url ->
        scope.launch {
            if (!linkOpener.open(url)) snackbar.showSnackbar("Could not open $url")
        }
    }
}
