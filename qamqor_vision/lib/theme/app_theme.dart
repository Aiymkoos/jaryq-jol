import 'package:flutter/material.dart';

/// Высококонтрастная тема по стандарту WCAG 2.1.
///
/// Пара «тёмно-синий фон / ярко-жёлтый текст» даёт коэффициент контрастности
/// около 11:1 при минимуме 4.5:1 для уровня AA и 7:1 для AAA.
class AppTheme {
  AppTheme._();

  /// Основной фон приложения.
  static const Color background = Color(0xFF0A1E3D);

  /// Поверхность карточек и панелей — чуть светлее фона.
  static const Color surface = Color(0xFF143257);

  /// Акцентный цвет: текст, иконки, границы.
  static const Color accent = Color(0xFFFFD400);

  /// Текст поверх акцентного цвета.
  static const Color onAccent = Color(0xFF0A1E3D);

  /// Минимальный размер зоны нажатия. WCAG 2.1 (2.5.5) требует 44dp,
  /// здесь взят увеличенный размер: пользователь не видит границы кнопки
  /// и нажимает примерно.
  static const double minTouchTarget = 88.0;

  static ThemeData build() {
    const colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      surface: surface,
      onSurface: accent,
      error: Color(0xFFFF6B6B),
      onError: onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: accent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: accent,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Крупные начертания: слабовидящие пользователи часто различают
      // силуэт текста, но не мелкие детали.
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: accent,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: accent, fontSize: 22, height: 1.4),
        bodyMedium: TextStyle(color: accent, fontSize: 20, height: 1.4),
        labelLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
