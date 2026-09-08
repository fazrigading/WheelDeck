package dev.fazrigading.wheeldeck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            window.attributes.colorMode = 1 // COLOR_MODE_SRGB
        }
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture
}
