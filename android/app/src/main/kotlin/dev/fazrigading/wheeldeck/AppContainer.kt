package dev.fazrigading.wheeldeck

import android.content.Context

/// Manual DI container, matching the Dart app's constructor-injection style.
/// Grows as services land: protocol client, discovery, stores.
class AppContainer(appContext: Context) {
    val appContext: Context = appContext.applicationContext
}
