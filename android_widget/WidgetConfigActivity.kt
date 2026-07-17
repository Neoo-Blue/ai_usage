package com.example.ai_usage

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Launched by the launcher when a widget is dropped (android:configure). Runs the
// Flutter UI at /widgetConfig, and returns RESULT_OK with the appWidgetId so the
// launcher keeps the widget. Backing out leaves nothing on the home screen.
class WidgetConfigActivity : FlutterActivity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val channelName = "aiusage/widget_config"

    override fun onCreate(savedInstanceState: Bundle?) {
        setResult(RESULT_CANCELED)
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        super.onCreate(savedInstanceState)
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) finish()
    }

    override fun getInitialRoute(): String = "/widgetConfig?widgetId=$appWidgetId"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "finish" -> {
                        val out = Intent().putExtra(
                            AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId
                        )
                        setResult(RESULT_OK, out)
                        result.success(null)
                        finish()
                    }
                    "cancel" -> {
                        setResult(RESULT_CANCELED)
                        result.success(null)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
