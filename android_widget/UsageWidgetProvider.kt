package com.example.ai_usage

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

// Per widget rendering. Each placed widget stores its own theme and text lines
// under keys namespaced by the appWidgetId, written by the Flutter side.
class UsageWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val theme = widgetData.getString("widget_${widgetId}_theme", "minimalist") ?: "minimalist"
            val views = RemoteViews(context.packageName, R.layout.usage_widget)
            views.setTextViewText(
                R.id.widget_title,
                widgetData.getString("widget_${widgetId}_title", "AI Usage")
            )
            views.setTextViewText(
                R.id.widget_line1,
                widgetData.getString("widget_${widgetId}_line1", "Not set up")
            )
            views.setTextViewText(
                R.id.widget_line2,
                widgetData.getString("widget_${widgetId}_line2", "Remove and re-add to configure")
            )
            val barPct = widgetData.getString("widget_${widgetId}_bar", "0")?.toIntOrNull() ?: 0
            views.setProgressBar(R.id.widget_bar, 100, barPct, false)
            applyTheme(context, views, theme)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun applyTheme(context: Context, views: RemoteViews, theme: String) {
        var title = 0xFF111111.toInt()
        var body = 0xFF666666.toInt()
        when (theme) {
            "minimalist" -> {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.wbg_minimalist)
                title = 0xFF111111.toInt(); body = 0xFF666666.toInt()
            }
            "elegant" -> {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.wbg_elegant)
                title = 0xFF2E2A24.toInt(); body = 0xFF7A6A55.toInt()
            }
            "futuristic" -> {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.wbg_futuristic)
                title = 0xFF19E6C1.toInt(); body = 0xFF6FE9D6.toInt()
            }
            "neumorphic" -> {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.wbg_neumorphic)
                title = 0xFF3A3D4D.toInt(); body = 0xFF8A8D9A.toInt()
            }
            "retro" -> {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.wbg_retro)
                title = 0xFF00FF66.toInt(); body = 0xFFFFCC00.toInt()
            }
            "adaptive" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    views.setInt(
                        R.id.widget_root, "setBackgroundColor",
                        context.getColor(android.R.color.system_accent1_100)
                    )
                    title = context.getColor(android.R.color.system_neutral1_900)
                    body = context.getColor(android.R.color.system_neutral2_700)
                } else {
                    views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.wbg_minimalist)
                    title = 0xFF111111.toInt(); body = 0xFF666666.toInt()
                }
            }
            else -> {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg)
            }
        }
        views.setTextColor(R.id.widget_title, title)
        views.setTextColor(R.id.widget_line1, body)
        views.setTextColor(R.id.widget_line2, body)
    }
}
