import 'package:flutter_test/flutter_test.dart';
import 'package:qamqor_vision/l10n/app_strings.dart';
import 'package:qamqor_vision/l10n/object_labels.dart';
import 'package:qamqor_vision/services/scene_narrator.dart';
import 'package:qamqor_vision/services/vision_service.dart';

void main() {
  const russian = AppLanguage.russian;
  const kazakh = AppLanguage.kazakh;

  group('SceneNarrator: предметы', () {
    test('перечисляет распознанное', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          labels: [
            RecognizedLabel('Table', 0.92),
            RecognizedLabel('Chair', 0.81),
          ],
        ),
        russian,
      );

      expect(phrase, 'Вижу: стол, стул.');
    });

    test('озвучивает на казахском', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(labels: [RecognizedLabel('Door', 0.9)]),
        kazakh,
      );

      expect(phrase, 'Көріп тұрмын: есік.');
    });

    test('не повторяет слово, если две метки переводятся одинаково', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          labels: [RecognizedLabel('Tree', 0.9), RecognizedLabel('Wood', 0.7)],
        ),
        russian,
      );

      expect(phrase, 'Вижу: дерево.');
    });

    test('пропускает метки, которых нет в словаре', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          labels: [
            RecognizedLabel('Table', 0.9),
            RecognizedLabel('Rugby', 0.8),
          ],
        ),
        russian,
      );

      expect(phrase, 'Вижу: стол.');
    });

    test('честно сообщает, когда сказать нечего', () {
      // Модель что-то нашла, но ни одну метку мы не умеем перевести.
      // Выдумывать предметы в такой ситуации нельзя.
      final phrase = SceneNarrator.describe(
        const SceneObservation(labels: [RecognizedLabel('Rugby', 0.9)]),
        russian,
      );

      expect(phrase, AppStrings.of(russian).nothingRecognized);
    });

    test('пустой снимок тоже даёт понятную фразу', () {
      expect(
        SceneNarrator.describe(const SceneObservation(), russian),
        AppStrings.of(russian).nothingRecognized,
      );
    });
  });

  group('SceneNarrator: препятствия', () {
    test('называет положение и близость', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          obstacles: [
            DetectedObstacle(ObstacleZone.center, ObstacleProximity.near, 0.4),
          ],
        ),
        russian,
      );

      expect(phrase, 'Препятствие по центру, близко.');
    });

    test('препятствие идёт раньше списка предметов', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          labels: [RecognizedLabel('Table', 0.9)],
          obstacles: [
            DetectedObstacle(ObstacleZone.left, ObstacleProximity.far, 0.1),
          ],
        ),
        russian,
      );

      expect(phrase, 'Препятствие слева, далеко. Вижу: стол.');
    });

    test('из нескольких препятствий называется самое крупное', () {
      // Перечислять все — значит утопить важное в шуме.
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          obstacles: [
            DetectedObstacle(ObstacleZone.left, ObstacleProximity.far, 0.05),
            DetectedObstacle(ObstacleZone.right, ObstacleProximity.near, 0.45),
            DetectedObstacle(ObstacleZone.center, ObstacleProximity.far, 0.2),
          ],
        ),
        russian,
      );

      expect(phrase, 'Препятствие справа, близко.');
    });

    test('препятствие озвучивается и на казахском', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          obstacles: [
            DetectedObstacle(ObstacleZone.right, ObstacleProximity.near, 0.5),
          ],
        ),
        kazakh,
      );

      expect(phrase, 'Кедергі оң жақта, жақын.');
    });

    test('препятствие спасает фразу, когда предметы не опознаны', () {
      final phrase = SceneNarrator.describe(
        const SceneObservation(
          labels: [RecognizedLabel('Rugby', 0.9)],
          obstacles: [
            DetectedObstacle(ObstacleZone.center, ObstacleProximity.near, 0.3),
          ],
        ),
        russian,
      );

      expect(phrase, 'Препятствие по центру, близко.');
    });
  });

  group('SceneNarrator: ошибки', () {
    test('каждая ошибка объясняется по-своему', () {
      final strings = AppStrings.of(russian);

      expect(
        SceneNarrator.errorFor(SceneError.permissionDenied, russian),
        strings.cameraDenied,
      );
      expect(
        SceneNarrator.errorFor(SceneError.noCamera, russian),
        strings.cameraMissing,
      );
      expect(
        SceneNarrator.errorFor(SceneError.failed, russian),
        strings.recognitionFailed,
      );
    });
  });

  group('ObjectLabels', () {
    test('метка ищется независимо от регистра и пробелов', () {
      expect(ObjectLabels.translate('  TABLE ', russian), 'стол');
    });

    test('неизвестная метка не переводится', () {
      expect(ObjectLabels.translate('quasar', russian), isNull);
    });

    test('каждая метка переведена на оба языка', () {
      expect(ObjectLabels.size, greaterThan(100));
      expect(ObjectLabels.translate('window', russian), 'окно');
      expect(ObjectLabels.translate('window', kazakh), 'терезе');
    });
  });
}
