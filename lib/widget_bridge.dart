import 'package:home_widget/home_widget.dart';

import 'db.dart';

// Builds and pushes the snapshot for one placed widget, keyed by its appWidgetId,
// based on that widget's stored account, theme, and metric selection.
Future<void> pushWidgetSnapshot(String widgetId) async {
  try {
    final cfg = await Db.instance.widgetConfigById(widgetId);
    if (cfg == null) return;

    final account = cfg.accountId == null ? null : await Db.instance.accountById(cfg.accountId!);
    var title = 'AI Usage';
    var line1 = 'Not set up';
    var line2 = 'Open the app to connect';

    if (account != null) {
      final metrics = await Db.instance.metricsFor(account.id);
      final selected = cfg.metricTypes;
      // The synced email (if any) headlines line1; it is not a selectable metric.
      String? email;
      for (final m in metrics) {
        if (m.metricType == 'account') email = m.textValue;
      }
      final shown = metrics
          .where((m) =>
              m.metricType != 'account' && (selected.isEmpty || selected.contains(m.metricType)))
          .toList();
      title = account.label;
      line1 = (email != null && email.isNotEmpty)
          ? email
          : '${account.provider.name} . ${account.status.name}';
      if (shown.isNotEmpty) {
        line2 = shown.take(2).map((m) => '${m.metricType}: ${m.display()}').join('   ');
      } else if (account.planName != null) {
        line2 = 'plan: ${account.planName}';
      } else {
        line2 = 'Tap sync for usage';
      }
    }

    await HomeWidget.saveWidgetData('widget_${widgetId}_theme', cfg.theme.name);
    await HomeWidget.saveWidgetData('widget_${widgetId}_title', title);
    await HomeWidget.saveWidgetData('widget_${widgetId}_line1', line1);
    await HomeWidget.saveWidgetData('widget_${widgetId}_line2', line2);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.example.ai_usage.UsageWidgetProvider',
    );
  } catch (_) {
    // Widget host not present; nothing to do.
  }
}

// Refresh every placed widget (called after a sync or list change).
Future<void> refreshAllWidgets() async {
  try {
    for (final c in await Db.instance.allWidgetConfigs()) {
      await pushWidgetSnapshot(c.id);
    }
  } catch (_) {}
}
