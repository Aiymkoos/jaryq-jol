import 'dart:convert';
import 'dart:js_interop';

import 'web_bridge.dart';
import 'vision_models.dart';

class CameraSceneRecognizer implements SceneRecognizer {
  CameraSceneRecognizer({double confidenceThreshold = 0.65});
  @override
  Future<SceneObservation> describeScene() async {
    try {
      final r = jsonDecode(
        (await captureWeb('scene'.toJS, 'rus'.toJS).toDart).toDart,
      ) as Map<String, dynamic>;
      if (r['error'] != null) throw StateError(r['error'] as String);
      return SceneObservation(
        labels: (r['labels'] as List)
            .map(
              (dynamic l) => RecognizedLabel(
                l['label'] as String,
                (l['confidence'] as num).toDouble(),
              ),
            )
            .toList(),
        obstacles: (r['obstacles'] as List)
            .map(
              (dynamic o) => DetectedObstacle(
                ObstacleZone.values[o['zone'] as int],
                (o['area'] as num) >= 0.25
                    ? ObstacleProximity.near
                    : ObstacleProximity.far,
                (o['area'] as num).toDouble(),
              ),
            )
            .toList(),
      );
    } catch (_) {
      throw const SceneRecognitionException(SceneError.failed);
    }
  }

  @override
  Future<void> dispose() async {}
}
