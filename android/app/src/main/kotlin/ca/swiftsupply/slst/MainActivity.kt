package ca.swiftsupply.slst

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val desktopModeChannel = "slst/desktop_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            desktopModeChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDesktopMode" -> result.success(isDesktopMode())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * True for Samsung DeX / Android desktop (UI_MODE_TYPE_DESK) and Samsung
     * SEM desktop flags. Plain phone/tablet touch sessions stay false.
     */
    private fun isDesktopMode(): Boolean {
        val uiMode = resources.configuration.uiMode
        val type = uiMode and Configuration.UI_MODE_TYPE_MASK
        if (type == Configuration.UI_MODE_TYPE_DESK) return true

        // Samsung DeX reflection (OEM fields; absent on AOSP/stock).
        return try {
            val configClass = Configuration::class.java
            val enabled = configClass.getField("SEM_DESKTOP_MODE_ENABLED").getInt(null)
            val mask = configClass.getField("SEM_DESKTOP_MODE_MASK").getInt(null)
            (uiMode and mask) == enabled
        } catch (_: Throwable) {
            false
        }
    }
}
