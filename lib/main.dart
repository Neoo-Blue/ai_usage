import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'home_screen.dart';
import 'widget_config_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await HomeWidget.setAppGroupId('group.com.example.ai_usage');
  } catch (_) {}
  runApp(const AiUsageApp());
}

class AiUsageApp extends StatelessWidget {
  const AiUsageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Usage',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      // The native widget configure Activity launches Flutter at this route.
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.path == '/widgetConfig') {
          return MaterialPageRoute(
            builder: (_) => WidgetConfigScreen(widgetId: uri.queryParameters['widgetId'] ?? ''),
          );
        }
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      },
    );
  }
}
