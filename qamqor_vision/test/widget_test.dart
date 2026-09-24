// Тесты главного экрана.
//
// Синтез речи и камера живут на стороне платформы, поэтому канал
// `flutter_tts` подменяется заглушкой, а распознавание и хранилище настроек —
// фейками. Заглушка речи запоминает произнесённое: для этого приложения
// важно не только что нарисовано, но и что услышал пользователь.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qamqor_vision/l10n/app_strings.dart';
import 'package:qamqor_vision/main.dart';
import 'package:qamqor_vision/services/settings_service.dart';
import 'package:qamqor_vision/services/speech_rate.dart';
import 'package:qamqor_vision/services/vision_service.dart';

class FakeSceneRecognizer implements SceneRecognizer {
  FakeSceneRecognizer({
    this.observation = const SceneObservation(),
    this.error,
  });

  final SceneObservation observation;
  final SceneError? error;

  @override
  Future<SceneObservation> describeScene() async {
    final failure = error;
    if (failure != null) throw SceneRecognitionException(failure);
    return observation;
  }

  @override
  Future<void> dispose() async {}
}

class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([this.stored = const AppSettings()]);

  AppSettings stored;
  AppSettings? savedValue;

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async => savedValue = settings;
}

void main() {
  const channel = MethodChannel('flutter_tts');

  final russian = AppStrings.of(AppLanguage.russian);
  final kazakh = AppStrings.of(AppLanguage.kazakh);

  /// Всё, что приложение отправило в синтез речи.
  late List<String> spoken;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    spoken = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'speak') {
            final args = call.arguments;
            spoken.add(args is Map ? args['text'] as String : args as String);
          }
          if (call.method == 'isLanguageAvailable') return true;
          return 1;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    SceneRecognizer? recognizer,
    SettingsStore? settings,
  }) async {
    await tester.pumpWidget(
      QamqorVisionApp(
        recognizer: recognizer ?? FakeSceneRecognizer(),
        settingsStore: settings ?? FakeSettingsStore(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('стартует на русском и показывает все действия', (tester) async {
    await pumpApp(tester);

    expect(find.text(russian.describeButton), findsOneWidget);
    expect(find.text(russian.readTextButton), findsOneWidget);
    expect(find.text(russian.repeatButton), findsOneWidget);
    expect(find.text(russian.stopButton), findsOneWidget);
  });

  testWidgets('при запуске подсказывает жест голосом', (tester) async {
    // Найти двойной тап, не видя экрана, невозможно — о нём нужно сказать.
    await pumpApp(tester);

    expect(spoken.single, contains(russian.doubleTapHint));
  });

  testWidgets('описание обстановки перечисляет распознанное', (tester) async {
    await pumpApp(
      tester,
      recognizer: FakeSceneRecognizer(
        observation: const SceneObservation(
          labels: [
            RecognizedLabel('Table', 0.9),
            RecognizedLabel('Chair', 0.8),
          ],
        ),
      ),
    );

    await tester.tap(find.text(russian.describeButton));
    await tester.pumpAndSettle();

    expect(find.text('Вижу: стол, стул.'), findsOneWidget);
    expect(spoken.last, 'Вижу: стол, стул.');
  });

  testWidgets('препятствие называется раньше предметов', (tester) async {
    await pumpApp(
      tester,
      recognizer: FakeSceneRecognizer(
        observation: const SceneObservation(
          labels: [RecognizedLabel('Table', 0.9)],
          obstacles: [
            DetectedObstacle(ObstacleZone.center, ObstacleProximity.near, 0.4),
          ],
        ),
      ),
    );

    await tester.tap(find.text(russian.describeButton));
    await tester.pumpAndSettle();

    expect(spoken.last, 'Препятствие по центру, близко. Вижу: стол.');
  });

  testWidgets('двойной тап по экрану заменяет попадание в кнопку', (
    tester,
  ) async {
    await pumpApp(
      tester,
      recognizer: FakeSceneRecognizer(
        observation: const SceneObservation(
          labels: [RecognizedLabel('Door', 0.9)],
        ),
      ),
    );

    final area = find.byKey(const ValueKey('describe-tap-area'));
    final center = tester.getCenter(area);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    expect(spoken.last, 'Вижу: дверь.');
  });

  testWidgets('повтор проговаривает последнее заново', (tester) async {
    await pumpApp(tester);
    final greeting = spoken.last;
    spoken.clear();

    await tester.tap(find.text(russian.repeatButton));
    await tester.pumpAndSettle();

    expect(spoken.single, greeting);
  });

  testWidgets('отказ в доступе к камере объясняется словами', (tester) async {
    await pumpApp(
      tester,
      recognizer: FakeSceneRecognizer(error: SceneError.permissionDenied),
    );

    await tester.tap(find.text(russian.describeButton));
    await tester.pumpAndSettle();

    expect(find.text(russian.cameraDenied), findsOneWidget);
  });

  testWidgets('модель ничего не узнала — приложение это признаёт', (
    tester,
  ) async {
    await pumpApp(tester, recognizer: FakeSceneRecognizer());

    await tester.tap(find.text(russian.describeButton));
    await tester.pumpAndSettle();

    expect(find.text(russian.nothingRecognized), findsOneWidget);
  });

  testWidgets('чтение текста честно сообщает, что не реализовано', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text(russian.readTextButton));
    await tester.pumpAndSettle();

    expect(find.text(russian.readTextStub), findsOneWidget);
  });

  testWidgets('сохранённый язык применяется при запуске', (tester) async {
    await pumpApp(
      tester,
      settings: FakeSettingsStore(
        const AppSettings(language: AppLanguage.kazakh),
      ),
    );

    expect(find.text(kazakh.describeButton), findsOneWidget);
    expect(find.text(russian.describeButton), findsNothing);
  });

  testWidgets('переключение языка сохраняется', (tester) async {
    final store = FakeSettingsStore();
    await pumpApp(tester, settings: store);

    // Кнопка подписана языком, на который переключаемся.
    await tester.tap(find.text(AppLanguage.kazakh.label));
    await tester.pumpAndSettle();

    expect(find.text(kazakh.describeButton), findsOneWidget);
    expect(store.savedValue?.language, AppLanguage.kazakh);
  });

  testWidgets('скорость речи переключается и сохраняется', (tester) async {
    final store = FakeSettingsStore();
    await pumpApp(tester, settings: store);
    spoken.clear();

    await tester.tap(find.byIcon(Icons.speed));
    await tester.pumpAndSettle();

    expect(store.savedValue?.rate, SpeechRate.fast);
    // Новую скорость называем вслух — иначе результат не проверить на слух.
    expect(spoken.single, contains(russian.speedName(SpeechRate.fast)));
  });

  testWidgets('кнопки подписаны для скринридера', (tester) async {
    // Без этого дерево семантики в тестах не строится.
    final handle = tester.ensureSemantics();

    await pumpApp(tester);

    expect(find.bySemanticsLabel(russian.describeButton), findsOneWidget);
    expect(find.bySemanticsLabel(russian.readTextButton), findsOneWidget);
    expect(find.bySemanticsLabel(russian.repeatButton), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '${russian.languageButton}: ${AppLanguage.kazakh.label}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '${russian.speedButton}: ${russian.speedName(SpeechRate.normal)}',
      ),
      findsOneWidget,
    );

    handle.dispose();
  });
}
