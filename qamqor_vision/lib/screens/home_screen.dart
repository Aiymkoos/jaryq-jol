import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/scene_narrator.dart';
import '../services/settings_service.dart';
import '../services/speech_service.dart';
import '../services/vision_service.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';

/// Главный экран: описание обстановки, чтение текста, повтор, остановка речи,
/// скорость речи и переключение языка.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.recognizer, this.settingsStore});

  /// Подменяются в тестах, чтобы обойтись без камеры и без диска.
  final SceneRecognizer? recognizer;
  final SettingsStore? settingsStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechService _speech = SpeechService();
  late final SettingsStore _settingsStore =
      widget.settingsStore ?? PrefsSettingsStore();

  // Камера открывается лениво: держать её включённой, пока пользователь
  // ничего не снимает, значит зря сажать батарею.
  SceneRecognizer? _recognizerInstance;
  SceneRecognizer get _recognizer =>
      _recognizerInstance ??= widget.recognizer ?? CameraSceneRecognizer();

  AppSettings _settings = const AppSettings();
  String _lastSpoken = '';
  bool _isRecognizing = false;

  AppLanguage get _language => _settings.language;
  AppStrings get _strings => AppStrings.of(_language);

  @override
  void initState() {
    super.initState();
    _speech.addListener(_onSpeechChanged);
    _startUp();
  }

  Future<void> _startUp() async {
    final saved = await _settingsStore.load();
    if (!mounted) return;
    setState(() => _settings = saved);

    await _speech.init(language: saved.language, rate: saved.rate);
    if (!mounted) return;

    // Подсказку про двойной тап проговариваем при запуске: обнаружить жест
    // самостоятельно, не видя экрана, невозможно.
    await _say('${_strings.greeting} ${_strings.doubleTapHint}');
  }

  void _onSpeechChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _say(String text) async {
    setState(() => _lastSpoken = text);
    await _speech.speak(text);
  }

  Future<void> _describeScene() async {
    // Повторное нажатие во время съёмки сбросило бы кадр на полпути.
    if (_isRecognizing) return;
    setState(() => _isRecognizing = true);

    // Пользователь не видит индикатор загрузки, поэтому о начале работы
    // сообщаем голосом.
    await _say(_strings.analyzing);

    try {
      final observation = await _recognizer.describeScene();
      if (!mounted) return;
      await _say(SceneNarrator.describe(observation, _language));
    } on SceneRecognitionException catch (e) {
      if (!mounted) return;
      await _say(SceneNarrator.errorFor(e.kind, _language));
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
  }

  /// Повтор последней фразы: речь легко пропустить мимо ушей, а снимать
  /// кадр заново ради этого незачем.
  Future<void> _repeat() async {
    if (_lastSpoken.isEmpty) {
      await _say(_strings.nothingToRepeat);
      return;
    }
    await _speech.speak(_lastSpoken);
  }

  Future<void> _stop() async {
    await _speech.stop();
    if (mounted) setState(() => _lastSpoken = _strings.stopped);
  }

  Future<void> _switchLanguage() async {
    final next = _language.toggled;
    await _updateSettings(_settings.copyWith(language: next));
    await _speech.setLanguage(next);
    if (!mounted) return;

    final strings = AppStrings.of(next);
    await _say(
      _speech.usingFallbackVoice
          ? '${strings.languageSwitched} ${strings.voiceUnavailable}'
          : strings.languageSwitched,
    );
  }

  Future<void> _cycleSpeed() async {
    final next = _settings.rate.next;
    await _updateSettings(_settings.copyWith(rate: next));
    await _speech.setRate(next);
    if (!mounted) return;

    // Новую скорость произносим уже на ней самой — так пользователь
    // сразу слышит результат, а не только название.
    await _say('${_strings.speedButton}: ${_strings.speedName(next)}');
  }

  Future<void> _updateSettings(AppSettings next) async {
    setState(() => _settings = next);
    await _settingsStore.save(next);
  }

  @override
  void dispose() {
    _speech.removeListener(_onSpeechChanged);
    _speech.dispose();
    _recognizerInstance?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          Semantics(
            button: true,
            label:
                '${strings.speedButton}: ${strings.speedName(_settings.rate)}',
            excludeSemantics: true,
            child: IconButton(
              onPressed: _cycleSpeed,
              iconSize: 30,
              color: AppTheme.accent,
              icon: const Icon(Icons.speed),
            ),
          ),
          // Подпись языком, на который переключаемся, а не текущим:
          // кнопка отвечает на вопрос «что будет, если нажать».
          Semantics(
            button: true,
            label: '${strings.languageButton}: ${_language.toggled.label}',
            excludeSemantics: true,
            child: TextButton(
              onPressed: _switchLanguage,
              child: Text(
                _language.toggled.label,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DescribeTapArea(
                  hint: strings.doubleTapHint,
                  semanticLabel: '${strings.lastSpokenLabel} $_lastSpoken',
                  onDescribe: _describeScene,
                  child: _SpokenTextPanel(
                    label: strings.lastSpokenLabel,
                    text: _lastSpoken,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BigActionButton(
                label: strings.describeButton,
                icon: Icons.visibility,
                onPressed: _describeScene,
              ),
              const SizedBox(height: 12),
              BigActionButton(
                label: strings.readTextButton,
                icon: Icons.text_fields,
                filled: false,
                semanticHint: strings.ocrNotReady,
                onPressed: () => _say(strings.readTextStub),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: BigActionButton(
                      label: strings.repeatButton,
                      icon: Icons.replay,
                      filled: false,
                      onPressed: _repeat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Кнопка остановки нужна всегда: если её прятать во
                  // время молчания, пользователь не найдёт её на ощупь
                  // по памяти.
                  Expanded(
                    child: BigActionButton(
                      label: strings.stopButton,
                      icon: Icons.stop_circle,
                      filled: false,
                      onPressed: _speech.isSpeaking ? _stop : () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Панель занимает бо́льшую часть экрана и сама работает кнопкой:
/// не видя экрана, попасть пальцем в кнопку внизу трудно, а промахнуться
/// мимо половины экрана почти невозможно.
///
/// Двойной тап, а не одиночный: одиночным пользователь просто нащупывает
/// интерфейс. Для скринридеров рядом объявлено семантическое действие —
/// TalkBack и VoiceOver перехватывают жесты и до `GestureDetector`
/// их не доносят, поэтому одного жеста мало.
class _DescribeTapArea extends StatelessWidget {
  const _DescribeTapArea({
    required this.hint,
    required this.semanticLabel,
    required this.onDescribe,
    required this.child,
  });

  final String hint;
  final String semanticLabel;
  final VoidCallback onDescribe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: hint,
      onTap: onDescribe,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('describe-tap-area'),
        onDoubleTap: onDescribe,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

class _SpokenTextPanel extends StatelessWidget {
  const _SpokenTextPanel({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Дублирование речи на экране — для слабовидящих пользователей
            // с остатком зрения и для зрячих помощников рядом.
            Text(text, style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
      ),
    );
  }
}
