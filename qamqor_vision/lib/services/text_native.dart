import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'text_models.dart';

class DeviceTextReader {
  Future<TextResult> read(bool kazakh) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('no_camera');
    final camera = CameraController(
      cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      ),
      ResolutionPreset.high,
      enableAudio: false,
    );
    XFile? shot;
    try {
      await camera.initialize();
      shot = await camera.takePicture();
      final r = await const MethodChannel('jaryq_jol/ocr')
          .invokeMapMethod<String, dynamic>('recognize', {
            'path': shot.path,
            'language': kazakh ? 'kaz+rus' : 'rus+kaz',
          });
      return TextResult(
        r?['text'] as String? ?? '',
        (r?['confidence'] as num? ?? 0).toDouble(),
      );
    } finally {
      await camera.dispose();
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
    }
  }
}
