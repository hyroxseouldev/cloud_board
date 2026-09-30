package com.sunmkim.cloudboard

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var startupViewportConfigured = false

    override fun onPostResume() {
        super.onPostResume()
        if (!startupViewportConfigured && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12's system splash is centered across the whole window.
            // Apply after Flutter restores its default system-bar flags, before
            // the first draw. Later resumes keep the player's own UI mode.
            WindowCompat.setDecorFitsSystemWindows(window, false)
            startupViewportConfigured = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ClassNotifications.install(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sunmkim.cloudboard/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> result.success(isAndroidTv())
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4601 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            ClassNotifications.permissionGranted(this)
        }
    }

    private fun isAndroidTv(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }
}
