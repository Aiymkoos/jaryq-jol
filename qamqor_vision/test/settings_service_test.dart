import 'package:flutter_test/flutter_test.dart';
import 'package:qamqor_vision/l10n/app_strings.dart';
import 'package:qamqor_vision/services/settings_service.dart';
import 'package:qamqor_vision/services/speech_rate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  group('PrefsSettingsStore', () {
    test('на первом запуске отдаёт значения по умолчанию', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = await PrefsSettingsStore().load();

      expect(settings.language, AppLanguage.russian);
      expect(settings.rate, SpeechRate.normal);
    });

    test('читает сохранённые язык и скорость', () async {
      SharedPreferences.setMockInitialValues({
        'language': 'kazakh',
        'speech_rate': 'fast',
      });

      final settings = await PrefsSettingsStore().load();

      expect(settings.language, AppLanguage.kazakh);
      expect(settings.rate, SpeechRate.fast);
    });

    test('сохранённое переживает перезапуск', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsSettingsStore();

      await store.save(
        const AppSettings(language: AppLanguage.kazakh, rate: SpeechRate.slow),
      );
      // Новый экземпляр — как после перезапуска приложения.
      final restored = await PrefsSettingsStore().load();

      expect(restored.language, AppLanguage.kazakh);
      expect(restored.rate, SpeechRate.slow);
    });

    test('непонятное значение не роняет запуск', () async {
      // Например, настройка от более новой версии приложения.
      SharedPreferences.setMockInitialValues({
        'language': 'klingon',
        'speech_rate': 'hyperspeed',
      });

      final settings = await PrefsSettingsStore().load();

      expect(settings.language, AppLanguage.russian);
      expect(settings.rate, SpeechRate.normal);
    });
  });

  group('SpeechRate', () {
    test('переключается по кругу', () {
      expect(SpeechRate.slow.next, SpeechRate.normal);
      expect(SpeechRate.normal.next, SpeechRate.fast);
      expect(SpeechRate.fast.next, SpeechRate.slow);
    });

    test('быстрая скорость действительно быстрее медленной', () {
      expect(SpeechRate.fast.value, greaterThan(SpeechRate.slow.value));
    });
  });
}
