package dev.fazrigading.wheeldeck.ui.features.menu.views

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.fazrigading.wheeldeck.BuildConfig

/// The app hub: shown after onboarding whenever there is no live session.
///
/// Four calls to action in the thumb zone, weighted per Material's 60/30/10
/// hierarchy — Connect filled, Settings tonal, About and Donate outlined. Driving
/// is reached by connecting, so this is the resting state rather than a step in
/// the flow.
@Composable
fun MenuScreen(
    onConnect: () -> Unit,
    onSettings: () -> Unit,
    onAbout: () -> Unit,
    onDonate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // No Scaffold, so the window insets are applied here: under `enableEdgeToEdge`
    // the 96dp logo would otherwise sit under the status bar, as `SafeArea` prevents
    // in the Dart.
    Column(
        modifier = modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(32.dp))
        Box(
            modifier = Modifier
                .size(96.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.DirectionsCar,
                contentDescription = null,
                modifier = Modifier.size(56.dp),
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
        Spacer(Modifier.height(24.dp))
        Text(
            "WheelDeck",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Phone as wheel & dashboard for PC simulators",
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.weight(1f))
        MenuButton(Icons.Filled.Wifi, "Connect", onConnect, style = Emphasis.Primary)
        Spacer(Modifier.height(16.dp))
        MenuButton(Icons.Filled.Settings, "Settings", onSettings, style = Emphasis.Secondary)
        Spacer(Modifier.height(16.dp))
        MenuButton(Icons.Filled.Info, "About", onAbout)
        Spacer(Modifier.height(16.dp))
        MenuButton(Icons.Filled.Favorite, "Donate", onDonate)
        Spacer(Modifier.height(32.dp))
        Text(
            "v${BuildConfig.VERSION_NAME}  •  fazrigading",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
    }
}

/// One hub action, full width and at least 56dp tall so it stays a comfortable
/// target in landscape.
@Composable
private fun MenuButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: Emphasis = Emphasis.Tertiary,
) {
    val shape = RoundedCornerShape(16.dp)
    val content: @Composable () -> Unit = {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(20.dp))
            Text(
                "  $label",
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.bodyLarge,
            )
        }
    }
    val fill = modifier.fillMaxWidth()
    when (style) {
        Emphasis.Primary -> Button(onClick = onClick, modifier = fill, shape = shape, content = { content() })
        Emphasis.Secondary -> FilledTonalButton(onClick = onClick, modifier = fill, shape = shape, content = { content() })
        Emphasis.Tertiary -> OutlinedButton(onClick = onClick, modifier = fill, shape = shape, content = { content() })
    }
}

/// Material's 60/30/10 emphasis, which is why Connect, Settings, and the two
/// quieter entries do not all look alike.
private enum class Emphasis { Primary, Secondary, Tertiary }

