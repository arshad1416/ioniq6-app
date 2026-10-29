package ca.arshad.ioniq6_companion

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val live = LiveUpdates(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ioniq6/live_updates").setMethodCallHandler { call, result ->
            when (call.method) {
                "charging" -> {
                    askForNotifications()
                    live.charging(
                        soc = call.argument<Int>("soc") ?: 0,
                        limit = call.argument<Int>("limit") ?: 90,
                        minutesLeft = call.argument<Int>("minutesLeft") ?: 0,
                        kw = call.argument<Double>("kw") ?: 0.0,
                    )
                    result.success(null)
                }
                "climate" -> {
                    askForNotifications()
                    live.climate(
                        target = call.argument<Double>("target") ?: 21.0,
                        cabin = call.argument<Double>("cabin"),
                        minutes = call.argument<Int>("minutes") ?: 10,
                    )
                    result.success(null)
                }
                "end" -> {
                    live.end(call.argument<String>("kind") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }
}
