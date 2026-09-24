import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import 'vision_models.dart';

/// Снимает кадр с камеры и разбирает его моделями ML Kit на устройстве.
///
/// Работает офлайн: ни снимок, ни результат никуда не отправляются.
class CameraSceneRecognizer implements SceneRecognizer {
  CameraSceneRecognizer({double confidenceThreshold = 0.65})
    : _labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
      ),
      _detector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          // Классификация выключена: её категории слишком общие, чтобы
          // называть предмет вслух, а рамки нужны и без неё.
          classifyObjects: false,
          multipleObjects: true,
        ),
      );

  /// Объект считается близким, если занимает больше четверти кадра.
  static const double _nearAreaRatio = 0.25;

  /// Границы левой и правой третей кадра.
  static const double _leftEdge = 1 / 3;
  static const double _rightEdge = 2 / 3;

  final ImageLabeler _labeler;
  final ObjectDetector _detector;
  CameraController? _controller;

  @override
  Future<SceneObservation> describeScene() async {
    await _ensureCamera();

    XFile? shot;
    try {
      shot = await _controller!.takePicture();
      final input = InputImage.fromFilePath(shot.path);
      final size = await _imageSize(shot.path);

      final labels = await _labeler.processImage(input);
      final objects = await _detector.processImage(input);

      return SceneObservation(
        // ML Kit отдаёт метки по убыванию уверенности; берём первые
        // несколько, потому что длинный список на слух не удержать.
        labels: labels
            .take(4)
            .map((l) => RecognizedLabel(l.label, l.confidence))
            .toList(),
        obstacles: size == null
            ? const []
            : objects.map((o) => _toObstacle(o, size)).toList(),
      );
    } on CameraException catch (e) {
      throw SceneRecognitionException(_kindFor(e));
    } catch (_) {
      throw const SceneRecognitionException(SceneError.failed);
    } finally {
      final camera = _controller;
      _controller = null;
      await camera?.dispose();
      // Снимок нужен только на время распознавания. Хранить фотографии
      // квартиры пользователя приложению незачем.
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {
          // Файл мог быть уже убран системой — это не повод падать.
        }
      }
    }
  }

  DetectedObstacle _toObstacle(DetectedObject object, ui.Size size) {
    final box = object.boundingBox;

    final relativeCenter = box.center.dx / size.width;
    final zone = relativeCenter < _leftEdge
        ? ObstacleZone.left
        : relativeCenter > _rightEdge
        ? ObstacleZone.right
        : ObstacleZone.center;

    final areaRatio = (box.width * box.height) / (size.width * size.height);

    return DetectedObstacle(
      zone,
      areaRatio >= _nearAreaRatio
          ? ObstacleProximity.near
          : ObstacleProximity.far,
      areaRatio,
    );
  }

  /// Размер снимка нужен, чтобы перевести рамку в доли кадра: в пикселях
  /// она ничего не говорит о том, слева объект или справа.
  Future<ui.Size?> _imageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      return size.isEmpty ? null : size;
    } catch (_) {
      // Без размера положение не посчитать. Молча опускаем препятствия —
      // разметка кадра при этом остаётся рабочей.
      return null;
    }
  }

  Future<void> _ensureCamera() async {
    if (_controller != null) return;

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw SceneRecognitionException(_kindFor(e));
    }
    if (cameras.isEmpty) {
      throw const SceneRecognitionException(SceneError.noCamera);
    }

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      // Высокое разрешение точность меток почти не поднимает, а кадр
      // готовится заметно дольше — пользователь ждёт ответа.
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw SceneRecognitionException(_kindFor(e));
    }
    _controller = controller;
  }

  SceneError _kindFor(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('permission') || code.contains('denied')) {
      return SceneError.permissionDenied;
    }
    if (code.contains('nocamera') || code.contains('notfound')) {
      return SceneError.noCamera;
    }
    return SceneError.failed;
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    await _labeler.close();
    await _detector.close();
  }
}
