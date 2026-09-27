package dev.fazrigading.wheeldeck.ui.features.settings.views

import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.window.DialogProperties

/// Per-control key/button binder, shared by the Keybind Configuration page and the
/// driving grid's unbound affordance. [onSave] receives the trimmed value; empty
/// means unbound and the phone then sends nothing.
///
/// **TODO.md Dashboard 5:** the keyboard must float and the dashboard behind must
/// not resize. Two settings do it, and the second is the one that matters:
///
/// - [DialogProperties.decorFitsSystemWindows] is false, so the dialog lays out
///   against the raw window and the IME inset is reported to it at all;
/// - the content carries [Modifier.imePadding], so it lifts above the keyboard
///   instead of hiding behind it.
///
/// The dialog's own window is deliberately left on its inherited
/// `softInputMode`. While a dialog holds IME focus the activity window is not the
/// resize target, so the dashboard keeps its height either way — and setting a
/// legacy `SOFT_INPUT_ADJUST_NOTHING` on the dialog window can suppress
/// `WindowInsets.ime` on API 30+, which would defeat the `imePadding` that is
/// doing the work. The activity itself declares `adjustResize` so the settings
/// list scrolls above the keyboard.
@Composable
fun BindingEditDialog(
    title: String,
    current: String,
    isGamepad: Boolean,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var value by remember { mutableStateOf(current) }
    val keyboard = LocalSoftwareKeyboardController.current

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.imePadding(),
        properties = DialogProperties(decorFitsSystemWindows = false),
        title = { Text("Edit $title") },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                label = { Text(if (isGamepad) "Button" else "Key") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.None,
                    autoCorrectEnabled = false,
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                ),
            )
        },
        confirmButton = {
            TextButton(
                onClick = {
                    keyboard?.hide()
                    onSave(value.trim())
                },
            ) { Text("Save") }
        },
        dismissButton = {
            TextButton(
                onClick = {
                    keyboard?.hide()
                    onDismiss()
                },
            ) { Text("Cancel") }
        },
    )

}
