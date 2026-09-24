import '../l10n/app_strings.dart';
import '../l10n/object_labels.dart';
import 'vision_service.dart';

/// Собирает из результатов моделей фразу, которую услышит пользователь.
///
/// Вынесено из экрана отдельно: это чистая функция, её можно проверить
/// тестами без камеры и без синтеза речи.
class SceneNarrator {
  SceneNarrator._();

  static String describe(SceneObservation observation, AppLanguage language) {
    final strings = AppStrings.of(language);
    final parts = <String>[];

    // Препятствие идёт первым: если на пути что-то есть, это важнее списка
    // предметов в кадре.
    final obstacle = observation.nearest;
    if (obstacle != null) {
      parts.add(
        '${strings.obstacle} ${strings.zoneName(obstacle.zone)}, '
        '${strings.proximityName(obstacle.proximity)}.',
      );
    }

    // Множество убирает повторы: разные метки модели переводятся одним
    // словом — например, «tree» и «wood» это оба «дерево».
    final names = observation.labels
        .map((l) => ObjectLabels.translate(l.label, language))
        .whereType<String>()
        .toSet();
    if (names.isNotEmpty) {
      parts.add('${strings.seeIntro} ${names.join(', ')}.');
    }

    // Пусто и когда модели ничего не нашли, и когда все метки оказались
    // вне словаря. Для пользователя разницы нет: описать нечем.
    if (parts.isEmpty) return strings.nothingRecognized;

    return parts.join(' ');
  }

  static String errorFor(SceneError error, AppLanguage language) {
    final strings = AppStrings.of(language);
    return switch (error) {
      SceneError.permissionDenied => strings.cameraDenied,
      SceneError.noCamera => strings.cameraMissing,
      SceneError.failed => strings.recognitionFailed,
    };
  }
}
