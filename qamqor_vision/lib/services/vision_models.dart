/// Распознанный предмет и уверенность модели от 0 до 1.
class RecognizedLabel {
  const RecognizedLabel(this.label, this.confidence);

  /// Метка ML Kit на английском — переводится через `ObjectLabels`.
  final String label;
  final double confidence;
}

/// Где предмет находится в кадре.
enum ObstacleZone { left, center, right }

/// Насколько предмет близко. Оценивается по доле кадра, которую он занимает,
/// поэтому это грубая прикидка, а не измеренное расстояние.
enum ObstacleProximity { near, far }

/// Препятствие: положение известно, а что это за предмет — нет.
///
/// Базовая модель детекции даёт рамку, но классифицирует слишком грубо,
/// чтобы называть предмет. Склеивать рамку с меткой из разметки кадра нельзя:
/// они друг с другом не связаны, и получилось бы «стол слева», когда слева
/// стул. Поэтому положение и содержимое сообщаются раздельно.
class DetectedObstacle {
  const DetectedObstacle(this.zone, this.proximity, this.areaRatio);

  final ObstacleZone zone;
  final ObstacleProximity proximity;

  /// Доля кадра, занятая объектом, от 0 до 1.
  final double areaRatio;
}

/// Что приложение увидело за один снимок.
class SceneObservation {
  const SceneObservation({this.labels = const [], this.obstacles = const []});

  final List<RecognizedLabel> labels;
  final List<DetectedObstacle> obstacles;

  /// Самое крупное препятствие — как правило, самое близкое и потому
  /// самое важное. Перечислять все значит утопить нужное в шуме.
  DetectedObstacle? get nearest {
    if (obstacles.isEmpty) return null;
    return obstacles.reduce((a, b) => a.areaRatio >= b.areaRatio ? a : b);
  }
}

/// Причина, по которой распознать не удалось.
enum SceneError { noCamera, permissionDenied, failed }

class SceneRecognitionException implements Exception {
  const SceneRecognitionException(this.kind);

  final SceneError kind;

  @override
  String toString() => 'SceneRecognitionException($kind)';
}

/// Источник описания обстановки.
///
/// Интерфейс отделён от реализации, чтобы экран можно было тестировать
/// без камеры: в тестах подставляется заглушка.
abstract class SceneRecognizer {
  Future<SceneObservation> describeScene();

  Future<void> dispose();
}
