import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import 'speech_rate.dart';

/// Настройки, которые переживают перезапуск приложения.
class AppSettings {
  const AppSettings({
    this.language = AppLanguage.russian,
    this.rate = SpeechRate.normal,
  });

  final AppLanguage language;
  final SpeechRate rate;

  AppSettings copyWith({AppLanguage? language, SpeechRate? rate}) =>
      AppSettings(language: language ?? this.language, rate: rate ?? this.rate);
}

/// Хранилище настроек.
///
/// Язык обязан сохраняться: казахоязычному пользователю иначе пришлось бы
/// переключать его при каждом запуске.
abstract class SettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class PrefsSettingsStore implements SettingsStore {
  static const _languageKey = 'language';
  static const _rateKey = 'speech_rate';

  @override
  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSettings(
        language: _readEnum(
          prefs.getString(_languageKey),
          AppLanguage.values,
          AppLanguage.russian,
        ),
        rate: _readEnum(
          prefs.getString(_rateKey),
          SpeechRate.values,
          SpeechRate.normal,
        ),
      );
    } catch (_) {
      // Настройки — не то, из-за чего стоит не запустить приложение.
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, settings.language.name);
      await prefs.setString(_rateKey, settings.rate.name);
    } catch (_) {
      // Потеря настроек не должна ломать текущую сессию.
    }
  }

  /// Разбор сохранённого значения. Незнакомое имя — например, из более
  /// новой версии приложения — заменяется значением по умолчанию.
  T _readEnum<T extends Enum>(String? stored, List<T> values, T fallback) {
    if (stored == null) return fallback;
    for (final value in values) {
      if (value.name == stored) return value;
    }
    return fallback;
  }
}
