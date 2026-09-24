import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_strings.dart';
import 'speech_rate.dart';

export 'speech_rate.dart';

/// Обёртка над синтезом речи устройства.
///
/// Экран не работает с [FlutterTts] напрямую: озвучивать результат нужно
/// из нескольких мест, и настройки голоса должны остаться в одном.
class SpeechService extends ChangeNotifier {
  SpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(_onDone);
    _tts.setCancelHandler(_onDone);
    _tts.setErrorHandler((dynamic _) => _onDone());
  }

  final FlutterTts _tts;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  /// Язык, выбранный пользователем.
  AppLanguage _language = AppLanguage.russian;
  AppLanguage get language => _language;

  SpeechRate _rate = SpeechRate.normal;
  SpeechRate get rate => _rate;

  /// True, если на устройстве нет голоса для выбранного языка и речь
  /// озвучивается запасным. Казахский голос установлен далеко не везде,
  /// поэтому молчать в этом случае нельзя — пользователь не увидит ошибку.
  bool _usingFallbackVoice = false;
  bool get usingFallbackVoice => _usingFallbackVoice;

  Future<void> init({
    AppLanguage language = AppLanguage.russian,
    SpeechRate rate = SpeechRate.normal,
  }) async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await setRate(rate);
    await setLanguage(language);
  }

  Future<void> setRate(SpeechRate rate) async {
    _rate = rate;
    await _tts.setSpeechRate(rate.value);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    _usingFallbackVoice = false;

    if (await _isAvailable(language.localeTag)) {
      await _tts.setLanguage(language.localeTag);
    } else {
      _usingFallbackVoice = true;
      final fallback = language.toggled.localeTag;
      if (await _isAvailable(fallback)) {
        await _tts.setLanguage(fallback);
      }
    }
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    // Без остановки движок на части платформ ставит фразы в очередь,
    // и пользователь ждёт окончания предыдущей.
    await stop();
    _isSpeaking = true;
    notifyListeners();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _onDone();
  }

  Future<bool> _isAvailable(String localeTag) async {
    try {
      return await _tts.isLanguageAvailable(localeTag) == true;
    } catch (_) {
      // На вебе и части десктопных сборок метод не реализован.
      return true;
    }
  }

  void _onDone() {
    if (!_isSpeaking) return;
    _isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
