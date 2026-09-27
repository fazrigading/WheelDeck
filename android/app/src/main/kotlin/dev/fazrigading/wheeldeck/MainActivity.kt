package dev.fazrigading.wheeldeck

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.fazrigading.wheeldeck.ui.core.AppShell
import dev.fazrigading.wheeldeck.ui.core.LifecycleObserver
import dev.fazrigading.wheeldeck.ui.core.theme.WheelDeckTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as WheelDeckApplication
        val coordinator = app.coordinator
        lifecycle.addObserver(LifecycleObserver(coordinator.viewModel))
        setContent {
            WheelDeckTheme {
                AppShell(coordinator)
            }
        }
    }
}
