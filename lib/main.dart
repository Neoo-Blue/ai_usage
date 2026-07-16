import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required for the iOS widget bridge. Harmless on Android. The group id must
  // match the iOS App Group entitlement once the native widget is added.
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
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
