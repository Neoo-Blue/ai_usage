import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'db.dart';
import 'models.dart';
import 'widget_canvas.dart';

double? _num(List<MetricRow> ms, String type) {
  for (final m in ms) {
    if (m.metricType == type) return m.numValue;
  }
  return null;
}

String? _text(List<MetricRow> ms, String type) {
  for (final m in ms) {
    if (m.metricType == type) return m.textValue;
  }
  return null;
}

// Renders the widget as a Flutter image (full design control), then tells the
// native widget to reload. Keyed per appWidgetId.
Future<void> pushWidgetSnapshot(String widgetId) async {
  try {
    final cfg = await Db.instance.widgetConfigById(widgetId);
    if (cfg == null) return;
    final account = cfg.accountId == null ? null : await Db.instance.accountById(cfg.accountId!);

    var title = 'AI Usage';
    String? subtitle = 'Open the app to connect';
    final bars = <UsageBarData>[];

    if (account != null) {
      final metrics = await Db.instance.metricsFor(account.id);
      title = account.label;
      final email = _text(metrics, 'account');
      final plan = _text(metrics, 'plan');
      subtitle = switch (cfg.headerMode) {
        WidgetHeaderMode.email => email ?? (plan != null ? 'plan: $plan' : null),
        WidgetHeaderMode.plan => plan != null ? 'plan: $plan' : null,
        WidgetHeaderMode.nickname => null,
      };
      void add(String label, String usedKey, String resetKey) {
        final pct = _num(metrics, usedKey);
        if (pct == null) return;
        bars.add(UsageBarData(label, pct, resetLabel(_text(metrics, resetKey))));
      }

      add('Current session', 'session_used', 'session_resets_at');
      add('Weekly, all models', 'weekly_used', 'weekly_resets_at');
      for (var i = 0; i < 4; i++) {
        final pct = _num(metrics, 'model${i}_used');
        if (pct == null) break;
        final label = _text(metrics, 'model${i}_label') ?? 'Weekly';
        bars.add(UsageBarData(label, pct, resetLabel(_text(metrics, 'model${i}_resets_at'))));
      }
      if (bars.isEmpty) subtitle ??= (plan != null ? 'plan: $plan' : 'Tap sync for usage');
    }

    // Fit the render to the widget's actual size when known (recorded on resize),
    // and drop the least important bars if the widget is short.
    var baseWidth = 340.0;
    final wStr = await HomeWidget.getWidgetData<String>('widget_${widgetId}_w');
    final w = double.tryParse(wStr ?? '');
    if (w != null && w > 80) baseWidth = w.clamp(150, 620).toDouble();

    var shown = bars;
    final hStr = await HomeWidget.getWidgetData<String>('widget_${widgetId}_h');
    final hDp = double.tryParse(hStr ?? '');
    if (hDp != null && hDp > 0 && bars.isNotEmpty) {
      final capacity = ((hDp - 44) / 46).floor().clamp(1, bars.length).toInt();
      if (capacity < bars.length) shown = bars.sublist(0, capacity);
    }

    final hasSub = subtitle != null && subtitle.isNotEmpty;
    final height = 60.0 + (hasSub ? 14 : 0) + (shown.isEmpty ? 26 : shown.length * 52);

    await HomeWidget.renderFlutterWidget(
      buildWidgetCanvas(theme: cfg.theme, title: title, subtitle: subtitle, bars: shown),
      key: 'widget_${widgetId}_img',
      logicalSize: Size(baseWidth, height),
      pixelRatio: 4.0,
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.example.ai_usage.UsageWidgetProvider',
    );
  } catch (_) {
    // Widget host not present or render unavailable; nothing to do.
  }
}

Future<void> refreshAllWidgets() async {
  try {
    for (final c in await Db.instance.allWidgetConfigs()) {
      await pushWidgetSnapshot(c.id);
    }
  } catch (_) {}
}
