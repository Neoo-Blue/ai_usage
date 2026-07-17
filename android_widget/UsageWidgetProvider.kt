package com.example.ai_usage

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// Classic AppWidget backed by home_widget's shared preferences. The Flutter side
// writes widget_title / widget_line1 / widget_line2, then calls updateWidget.
class UsageWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.usage_widget)
            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("widget_title", "AI Usage")
            )
            views.setTextViewText(
                R.id.widget_line1,
                widgetData.getString("widget_line1", "No account yet")
            )
            views.setTextViewText(
                R.id.widget_line2,
                widgetData.getString("widget_line2", "Open the app to connect")
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
