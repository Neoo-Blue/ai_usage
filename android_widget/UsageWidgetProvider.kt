package com.example.ai_usage

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Locale

// The themed bars are a Flutter rendered image. The reset countdown footer is
// native text, recomputed every minute by a self rescheduling alarm, so the
// countdown stays live without re-rendering the image. The refresh button opens
// the app, which fetches fresh percentages (that needs a real browser session).
class UsageWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ALARM_CODE = 4242
        const val ACTION_TICK = "com.example.ai_usage.WIDGET_TICK"
        const val PREFS = "HomeWidgetPreferences"
    }

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
            applyFooter(views, widgetData, widgetId)
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
        scheduleNextTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TICK) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, UsageWidgetProvider::class.java))
            val data = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.usage_widget)
                applyFooter(views, data, id)
                mgr.partiallyUpdateAppWidget(id, views)
            }
            if (ids.isNotEmpty()) scheduleNextTick(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onDisabled(context: Context) {
        val pi = PendingIntent.getBroadcast(
            context, ALARM_CODE,
            Intent(context, UsageWidgetProvider::class.java).setAction(ACTION_TICK),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
        super.onDisabled(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val w = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("widget_${appWidgetId}_w", w.toString())
            .putString("widget_${appWidgetId}_h", h.toString())
            .apply()
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun applyFooter(views: RemoteViews, data: SharedPreferences, widgetId: Int) {
        views.setTextViewText(R.id.widget_footer, computeFooter(data.getString("widget_${widgetId}_resets", "[]")))
        val color = data.getString("widget_${widgetId}_footcolor", null)
        if (color != null) {
            try {
                views.setTextColor(R.id.widget_footer, Color.parseColor(color))
            } catch (e: Exception) {
            }
        }
    }

    private fun scheduleNextTick(context: Context) {
        val pi = PendingIntent.getBroadcast(
            context, ALARM_CODE,
            Intent(context, UsageWidgetProvider::class.java).setAction(ACTION_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.set(AlarmManager.RTC, System.currentTimeMillis() + 60_000L, pi)
    }

    private fun computeFooter(json: String?): String {
        if (json.isNullOrEmpty()) return ""
        return try {
            val arr = JSONArray(json)
            val now = System.currentTimeMillis()
            var bestMs = Long.MAX_VALUE
            var bestLabel = ""
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val t = parseIso(o.optString("t")) ?: continue
                if (t > now && t < bestMs) {
                    bestMs = t
                    bestLabel = o.optString("l")
                }
            }
            if (bestLabel.isEmpty()) return ""
            val mins = (bestMs - now) / 60000L
            if (mins >= 60) "$bestLabel resets in ${mins / 60} hr ${mins % 60} min"
            else "$bestLabel resets in $mins min"
        } catch (e: Exception) {
            ""
        }
    }

    private fun parseIso(s: String?): Long? {
        if (s.isNullOrEmpty()) return null
        var v = s.trim()
            .replace("Z", "+0000")
            .replace(Regex("\\.\\d+"), "")
            .replace(Regex("([+-]\\d{2}):(\\d{2})$"), "$1$2")
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US)
            sdf.parse(v)?.time
        } catch (e: Exception) {
            null
        }
    }
}
