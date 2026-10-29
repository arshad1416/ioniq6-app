package ca.arshad.ioniq6_companion

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: range, charge and lock state, written by the app. */
class CarWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.car_widget).apply {
                setTextViewText(R.id.widget_range, widgetData.getString("range", "– km"))
                setTextViewText(R.id.widget_status, widgetData.getString("status", "Open the app to connect"))
                setProgressBar(R.id.widget_soc, 100, widgetData.getInt("soc", 0), false)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
