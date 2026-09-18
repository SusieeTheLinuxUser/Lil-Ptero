package dev.susiee.lilptero

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Bridges the one-off "exempt this app from battery optimization" request
/// the background server monitor needs — Android has no Dart-reachable API
/// for it, only this Settings intent, so a plugin would be overkill.
class MainActivity : FlutterActivity() {
    private val channel = "dev.susiee.lilptero/battery_optimization"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            when (call.method) {
                "isIgnoringBatteryOptimizations" ->
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                "requestIgnoreBatteryOptimizations" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName"),
                        )
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
