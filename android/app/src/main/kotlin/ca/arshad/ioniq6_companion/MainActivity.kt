package ca.arshad.ioniq6_companion

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingCalendarAsk: MethodChannel.Result? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ioniq6/installer").setMethodCallHandler { call, result ->
            if (call.method != "install") return@setMethodCallHandler result.notImplemented()
            try {
                Installer.install(this, call.argument<String>("path")!!)
                result.success(null)
            } catch (e: Exception) {
                result.error("install", e.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ioniq6/calendar").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(canReadCalendar())
                "requestPermission" -> when {
                    canReadCalendar() -> result.success(true)
                    pendingCalendarAsk != null -> result.success(false)
                    else -> {
                        pendingCalendarAsk = result
                        requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), CALENDAR_REQUEST)
                    }
                }
                "events" -> {
                    if (!canReadCalendar()) return@setMethodCallHandler result.error("permission", "No calendar access", null)
                    val from = call.argument<Number>("from")!!.toLong()
                    val to = call.argument<Number>("to")!!.toLong()
                    Thread {
                        val reply = try {
                            Result.success(CalendarReader.events(applicationContext, from, to))
                        } catch (e: Exception) {
                            Result.failure(e)
                        }
                        runOnUiThread {
                            reply.fold({ result.success(it) }, { result.error("calendar", it.message, null) })
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canReadCalendar() =
        checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_REQUEST) return
        pendingCalendarAsk?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingCalendarAsk = null
    }

    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    private companion object {
        const val CALENDAR_REQUEST = 7
    }
}
