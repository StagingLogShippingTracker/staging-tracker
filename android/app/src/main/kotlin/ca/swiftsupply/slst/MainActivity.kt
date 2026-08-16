package ca.swiftsupply.slst

import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val desktopModeChannel = "slst/desktop_mode"
    private val siblingAppsChannel = "slst/sibling_apps"

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            siblingAppsChannel,
        ).setMethodCallHandler { call, result ->
            val packageName = call.argument<String>("packageName").orEmpty()
            when (call.method) {
                "isInstalled" -> result.success(isSiblingInstalled(packageName))
                "launch" -> result.success(launchSibling(packageName))
                else -> result.notImplemented()
            }
        }
    }

    private fun isSiblingInstalled(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchSibling(packageName: String): Boolean {
        if (packageName.isEmpty()) return false
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
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
