package com.example.ai_usage

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// The widget UI is rendered to an image by Flutter (home_widget renderFlutterWidget),
// so the native side just loads that image per appWidgetId. All theming, bars, and
// layout live in the Flutter canvas.
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
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
