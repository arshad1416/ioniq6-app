package ca.arshad.ioniq6_companion

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle

/**
 * Android 16 Live Updates: promoted ongoing notifications that show on the
 * lock screen, at the top of the shade and in the status-bar chip (OxygenOS
 * also mirrors them in its Live Alert pill). Older Android gets a normal
 * ongoing notification with the same content.
 */
class LiveUpdates(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)

    init {
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Car activity", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Charging and climate while they run"
                setSound(null, null)
                enableVibration(false)
            },
        )
    }

    fun charging(soc: Int, limit: Int, minutesLeft: Int, kw: Double) {
        val left = if (minutesLeft >= 60) "${minutesLeft / 60} h ${minutesLeft % 60} min" else "$minutesLeft min"
        val text = buildString {
            append("$soc% → $limit% limit · $left left")
            if (kw > 0) append(" · ${"%.1f".format(kw)} kW")
        }
        val builder = base("IONIQ 6 · Charging", text, "$soc%")
        if (Build.VERSION.SDK_INT >= 36) {
            builder.setStyle(
                Notification.ProgressStyle()
                    .setStyledByProgress(false)
                    .setProgress(soc)
                    .setProgressSegments(
                        listOf(
                            Notification.ProgressStyle.Segment(limit).setColor(RED),
                            Notification.ProgressStyle.Segment(100 - limit).setColor(UNLIT),
                        ),
                    )
                    .setProgressPoints(listOf(Notification.ProgressStyle.Point(limit).setColor(Color.WHITE))),
            )
        } else {
            builder.setProgress(100, soc, false)
        }
        manager.notify(ID_CHARGING, builder.build())
    }

    fun climate(target: Double, cabin: Double?, minutes: Int) {
        val now = cabin?.let { "${it.toInt()} °C now · " } ?: ""
        val builder = base("IONIQ 6 · Climate on", "${now}warming to ${fmt(target)} °C · runs $minutes min", "${fmt(target)}°")
        manager.notify(ID_CLIMATE, builder.build())
    }

    fun end(kind: String) {
        when (kind) {
            "charging" -> manager.cancel(ID_CHARGING)
            "climate" -> manager.cancel(ID_CLIMATE)
        }
    }

    private fun base(title: String, text: String, chip: String): Notification.Builder {
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_car)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setColor(RED)
            .apply {
                if (Build.VERSION.SDK_INT >= 36) {
                    // Same as setRequestPromotedOngoing(true), which compileSdk 36 doesn't expose yet.
                    addExtras(Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
                    setShortCriticalText(chip)
                }
            }
    }

    private fun fmt(t: Double) = if (t % 1.0 == 0.0) t.toInt().toString() else t.toString()

    companion object {
        private const val CHANNEL = "car_live"
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
        private const val ID_CHARGING = 61
        private const val ID_CLIMATE = 62
        private val RED = Color.parseColor("#E8333C")
        private val UNLIT = Color.parseColor("#2C2C2E")
    }
}
