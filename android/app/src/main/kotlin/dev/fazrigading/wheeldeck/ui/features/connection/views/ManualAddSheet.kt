package dev.fazrigading.wheeldeck.ui.features.connection.views

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import dev.fazrigading.wheeldeck.domain.models.DefaultWheelDeckPort
import dev.fazrigading.wheeldeck.ui.features.connection.view_models.ConnectionViewModel

/// M3 content for the manual IP + port entry sheet. Inputs filtered to digits/dot.
@Composable
internal fun ManualAddSheetContent(viewModel: ConnectionViewModel, onDismiss: () -> Unit) {
    var ip by remember { mutableStateOf("") }
    var port by remember { mutableStateOf(DefaultWheelDeckPort.toString()) }
    var ipError by remember { mutableStateOf<String?>(null) }

    fun validate(): Boolean {
        val value = ip.trim()
        if (value.isEmpty()) {
            ipError = "IP required"
            return false
        }
        val octets = value.split('.')
        if (octets.size != 4 || octets.any { it.isEmpty() }) {
            ipError = "Enter valid IP (e.g. 192.168.1.10)"
            return false
        }
        if (octets.any { (it.toIntOrNull() ?: -1) !in 0..255 }) {
            ipError = "Each octet 0-255"
            return false
        }
        ipError = null
        return true
    }

    fun connect() {
        if (!validate()) return
        onDismiss()
        viewModel.connectManual(host = ip.trim(), port = port.trim().toIntOrNull())
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .imePadding(),
    ) {
        Text("Add receiver manually", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(4.dp))
        Text("Enter the desktop IP shown on the desktop app.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(24.dp))
        OutlinedTextField(
            value = ip,
            onValueChange = {
                ip = it.filter { c -> c.isDigit() || c == '.' }
                ipError = null
            },
            label = { Text("IP address") },
            placeholder = { Text("192.168.1.10") },
            isError = ipError != null,
            supportingText = ipError?.let { err -> { Text(err) } },
            leadingIcon = { Icon(Icons.Filled.Language, contentDescription = null) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(
            value = port,
            onValueChange = { port = it.filter(Char::isDigit) },
            label = { Text("Port") },
            leadingIcon = { Icon(Icons.Filled.Tag, contentDescription = null) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(24.dp))
        Button(onClick = ::connect, modifier = Modifier.fillMaxWidth().height(48.dp)) {
            Icon(Icons.Filled.Wifi, contentDescription = null)
            Spacer(Modifier.height(8.dp))
            Text("Connect")
        }
        Spacer(Modifier.height(24.dp))
    }
}
