package dev.fazrigading.wheeldeck

import android.content.Context
import dev.fazrigading.wheeldeck.data.services.WheelDeckClient

/// Manual DI container, matching the Dart app's constructor-injection style.
/// Grows as services land: protocol client, discovery, stores.
class AppContainer(appContext: Context) {
    val appContext: Context = appContext.applicationContext
    val wheelDeckClient: WheelDeckClient by lazy {
        WheelDeckClient(deviceId = "android-${appContext.packageName}")
    }
}
