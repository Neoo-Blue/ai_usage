package com.example.ai_usage

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// The widget UI is rendered to an image by Flutter. The native side loads that
// image, wires the refresh button and body to open the app (which syncs and
// re-renders), and records the widget size so the next render can fit it.
class UsageWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.usage_widget)
            val imgPath = widgetData.getString("widget_${widgetId}_img", null)
            if (imgPath != null) {
                val bmp = BitmapFactory.decodeFile(imgPath)
                if (bmp != null) views.setImageViewBitmap(R.id.widget_image, bmp)
            }
            val openApp = PendingIntent.getActivity(
                context,
                widgetId,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            views.setOnClickPendingIntent(R.id.widget_refresh, openApp)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val w = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE).edit()
            .putString("widget_${appWidgetId}_w", w.toString())
            .putString("widget_${appWidgetId}_h", h.toString())
            .apply()
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }
}
