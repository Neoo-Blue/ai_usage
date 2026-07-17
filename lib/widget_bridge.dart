import 'package:home_widget/home_widget.dart';

import 'db.dart';

// Writes a compact snapshot the native home screen widget reads, then asks
// Android to repaint the placed widget. Safe to call often; failures swallowed.
Future<void> updateHomeWidget() async {
  try {
    final accounts = await Db.instance.allAccounts();
    if (accounts.isEmpty) {
      await HomeWidget.saveWidgetData('widget_title', 'AI Usage');
      await HomeWidget.saveWidgetData('widget_line1', 'No account yet');
      await HomeWidget.saveWidgetData('widget_line2', 'Open the app to connect');
    } else {
      final a = accounts.first;
      final metrics = await Db.instance.metricsFor(a.id);
      final metric = metrics.isNotEmpty ? metrics.first : null;
      await HomeWidget.saveWidgetData('widget_title', a.label);
      await HomeWidget.saveWidgetData(
        'widget_line1',
        '${a.provider.name} . ${a.status.name}',
      );
      await HomeWidget.saveWidgetData(
        'widget_line2',
        metric != null ? '${metric.metricType}: ${metric.display()}' : 'Tap sync for usage',
      );
    }
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.example.ai_usage.UsageWidgetProvider',
    );
  } catch (_) {
    // Widget not placed yet, or no widget host; nothing to do.
  }
}
