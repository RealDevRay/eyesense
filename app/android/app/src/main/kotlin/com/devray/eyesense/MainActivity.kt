package com.devray.eyesense

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var hardware: MethodChannel? = null
    private var sensors: DeviceSensors? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        hardware = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eyesense/hardware")
        sensors = DeviceSensors(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onResume() {
        super.onResume()
        sensors?.resume()
    }

    override fun onPause() {
        sensors?.pause()
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sensors?.detach()
        sensors = null
        hardware = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            hardware?.invokeMethod("volumeKey", null)
        }
        return super.dispatchKeyEvent(event)
    }
}
