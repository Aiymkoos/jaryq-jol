import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/companion_screen.dart';
import 'services/settings_service.dart';
import 'services/vision_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const QamqorVisionApp());
}

class QamqorVisionApp extends StatelessWidget {
  const QamqorVisionApp({super.key, this.recognizer, this.settingsStore});

  /// Подменяются в тестах, чтобы обойтись без камеры и без диска.
  final SceneRecognizer? recognizer;
  final SettingsStore? settingsStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaryq Jol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: recognizer != null || settingsStore != null
          ? HomeScreen(recognizer: recognizer, settingsStore: settingsStore)
          : const CompanionScreen(),
    );
  }
}
