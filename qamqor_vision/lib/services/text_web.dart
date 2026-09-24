import 'dart:convert';
import 'dart:js_interop';

import 'web_bridge.dart';
import 'text_models.dart';

class DeviceTextReader {
  Future<TextResult> read(bool kazakh) async {
    final result = jsonDecode(
      (await captureWeb(
        'text'.toJS,
        (kazakh ? 'kaz+rus' : 'rus+kaz').toJS,
      ).toDart).toDart,
    ) as Map<String, dynamic>;
    if (result['error'] != null) throw StateError(result['error'] as String);
    return TextResult(
      result['text'] as String,
      (result['confidence'] as num).toDouble(),
    );
  }
}
