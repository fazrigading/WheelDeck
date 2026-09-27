package dev.fazrigading.wheeldeck.ui.core

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import dev.fazrigading.wheeldeck.ui.features.connection.view_models.ConnectionViewModel

/// Watches OS-level lifecycle events and pauses/resumes the session through
/// the [ConnectionViewModel].
class LifecycleObserver(private val viewModel: ConnectionViewModel) : DefaultLifecycleObserver {
    override fun onPause(owner: LifecycleOwner) {
        viewModel.pause()
    }

    override fun onResume(owner: LifecycleOwner) {
        viewModel.resume()
    }
}
