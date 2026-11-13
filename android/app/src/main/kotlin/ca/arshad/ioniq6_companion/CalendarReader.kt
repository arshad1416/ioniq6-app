package ca.arshad.ioniq6_companion

import android.content.ContentUris
import android.content.Context
import android.provider.CalendarContract.Events
import android.provider.CalendarContract.Instances

/** Reads upcoming events from the phone's calendars. Nothing leaves the phone. */
object CalendarReader {
    private val columns = arrayOf(
        Instances.EVENT_ID,
        Instances.BEGIN,
        Instances.END,
        Instances.TITLE,
        Instances.EVENT_LOCATION,
        Instances.ALL_DAY,
        Instances.CALENDAR_DISPLAY_NAME,
        Instances.DISPLAY_COLOR,
    )

    fun events(context: Context, from: Long, to: Long): List<Map<String, Any?>> {
        val uri = Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, to)
        }.build()
        val where = "${Instances.VISIBLE} = 1 AND ${Instances.STATUS} != ${Events.STATUS_CANCELED}"
        val out = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(uri, columns, where, null, "${Instances.BEGIN} ASC")?.use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "id" to c.getLong(0),
                    "begin" to c.getLong(1),
                    "end" to c.getLong(2),
                    "title" to c.getString(3),
                    "location" to c.getString(4),
                    "allDay" to (c.getInt(5) == 1),
                    "calendar" to c.getString(6),
                    "color" to if (c.isNull(7)) null else c.getInt(7),
                )
            }
        }
        return out
    }
}
