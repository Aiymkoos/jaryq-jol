import '../services/speech_rate.dart';
import '../services/vision_service.dart';

/// Поддерживаемые языки интерфейса и голосового движка.
enum AppLanguage {
  kazakh('kk-KZ', 'Қазақша'),
  russian('ru-RU', 'Русский');

  const AppLanguage(this.localeTag, this.label);

  /// BCP 47 тег, который передаётся в движок синтеза речи.
  final String localeTag;

  /// Название языка на нём самом — для кнопки переключения.
  final String label;

  AppLanguage get toggled =>
      this == AppLanguage.kazakh ? AppLanguage.russian : AppLanguage.kazakh;
}

/// Строки интерфейса. Отдельного пакета локализации пока нет:
/// на двух языках и одном экране простая таблица читается яснее.
class AppStrings {
  const AppStrings._(this._values);

  final Map<_Key, String> _values;

  static const AppStrings _kazakh = AppStrings._({
    _Key.appTitle: 'Jaryq Jol',
    _Key.ocrNotReady: 'Мәтінді оқу әлі іске қосылған жоқ',
    _Key.describeButton: 'Айналаны сипаттау',
    _Key.readTextButton: 'Мәтінді оқу',
    _Key.repeatButton: 'Қайталау',
    _Key.stopButton: 'Тоқтату',
    _Key.languageButton: 'Тілді ауыстыру',
    _Key.speedButton: 'Сөйлеу жылдамдығы',
    _Key.speedSlow: 'баяу',
    _Key.speedNormal: 'қалыпты',
    _Key.speedFast: 'жылдам',
    _Key.nothingToRepeat: 'Әзірге қайталайтын ештеңе жоқ.',
    _Key.doubleTapHint: 'Айналаны сипаттау үшін экранды екі рет түртіңіз.',
    _Key.greeting: 'Сәлеметсіз бе. Jaryq Jol қосылды.',
    _Key.analyzing: 'Қарап тұрмын',
    _Key.seeIntro: 'Көріп тұрмын:',
    _Key.obstacle: 'Кедергі',
    _Key.zoneLeft: 'сол жақта',
    _Key.zoneCenter: 'ортада',
    _Key.zoneRight: 'оң жақта',
    _Key.proximityNear: 'жақын',
    _Key.proximityFar: 'алыс',
    _Key.nothingRecognized:
        'Не бар екенін ажырата алмадым. Телефонды қозғалтпай ұстаңыз немесе '
        'жарықты қосыңыз.',
    _Key.cameraDenied:
        'Камераға рұқсат жоқ. Қолданба параметрлерінен рұқсат беріңіз.',
    _Key.cameraMissing: 'Құрылғыда камера табылмады.',
    _Key.recognitionFailed: 'Тану сәтсіз аяқталды. Қайталап көріңіз.',
    _Key.readTextStub:
        'Мәтінді оқу әлі іске қосылған жоқ. Бұл — дыбыстық шығудың '
        'демонстрациясы.',
    _Key.stopped: 'Тоқтатылды.',
    _Key.languageSwitched: 'Тіл қазақ тіліне ауыстырылды.',
    _Key.voiceUnavailable:
        'Құрылғыда қазақ тілінің дауысы жоқ. Орыс тіліндегі дауыс қолданылады.',
    _Key.lastSpokenLabel: 'Соңғы айтылған:',
  });

  static const AppStrings _russian = AppStrings._({
    _Key.appTitle: 'Jaryq Jol',
    _Key.ocrNotReady: 'Чтение текста пока не реализовано',
    _Key.describeButton: 'Описать обстановку',
    _Key.readTextButton: 'Прочитать текст',
    _Key.repeatButton: 'Повторить',
    _Key.stopButton: 'Остановить',
    _Key.languageButton: 'Сменить язык',
    _Key.speedButton: 'Скорость речи',
    _Key.speedSlow: 'медленная',
    _Key.speedNormal: 'обычная',
    _Key.speedFast: 'быстрая',
    _Key.nothingToRepeat: 'Пока нечего повторять.',
    _Key.doubleTapHint: 'Дважды коснитесь экрана, чтобы описать обстановку.',
    _Key.greeting: 'Здравствуйте. Jaryq Jol запущен.',
    _Key.analyzing: 'Смотрю',
    _Key.seeIntro: 'Вижу:',
    _Key.obstacle: 'Препятствие',
    _Key.zoneLeft: 'слева',
    _Key.zoneCenter: 'по центру',
    _Key.zoneRight: 'справа',
    _Key.proximityNear: 'близко',
    _Key.proximityFar: 'далеко',
    _Key.nothingRecognized:
        'Не могу разобрать, что передо мной. Держите телефон неподвижно или '
        'включите свет.',
    _Key.cameraDenied:
        'Нет доступа к камере. Разрешите его в настройках приложения.',
    _Key.cameraMissing: 'Камера на устройстве не найдена.',
    _Key.recognitionFailed: 'Не удалось распознать. Попробуйте ещё раз.',
    _Key.readTextStub:
        'Чтение текста пока не реализовано. Это демонстрация голосового '
        'вывода.',
    _Key.stopped: 'Остановлено.',
    _Key.languageSwitched: 'Язык переключён на русский.',
    _Key.voiceUnavailable:
        'На устройстве нет казахского голоса. Используется русский.',
    _Key.lastSpokenLabel: 'Последнее озвученное:',
  });

  static AppStrings of(AppLanguage language) =>
      language == AppLanguage.kazakh ? _kazakh : _russian;

  String get appTitle => _values[_Key.appTitle]!;
  String get ocrNotReady => _values[_Key.ocrNotReady]!;
  String get describeButton => _values[_Key.describeButton]!;
  String get readTextButton => _values[_Key.readTextButton]!;
  String get repeatButton => _values[_Key.repeatButton]!;
  String get stopButton => _values[_Key.stopButton]!;
  String get languageButton => _values[_Key.languageButton]!;
  String get speedButton => _values[_Key.speedButton]!;
  String get nothingToRepeat => _values[_Key.nothingToRepeat]!;
  String get doubleTapHint => _values[_Key.doubleTapHint]!;

  /// Название скорости речи — для подписи кнопки и озвучки после переключения.
  String speedName(SpeechRate rate) => switch (rate) {
    SpeechRate.slow => _values[_Key.speedSlow]!,
    SpeechRate.normal => _values[_Key.speedNormal]!,
    SpeechRate.fast => _values[_Key.speedFast]!,
  };
  String get greeting => _values[_Key.greeting]!;
  String get analyzing => _values[_Key.analyzing]!;
  String get seeIntro => _values[_Key.seeIntro]!;
  String get obstacle => _values[_Key.obstacle]!;

  String zoneName(ObstacleZone zone) => switch (zone) {
    ObstacleZone.left => _values[_Key.zoneLeft]!,
    ObstacleZone.center => _values[_Key.zoneCenter]!,
    ObstacleZone.right => _values[_Key.zoneRight]!,
  };

  String proximityName(ObstacleProximity proximity) => switch (proximity) {
    ObstacleProximity.near => _values[_Key.proximityNear]!,
    ObstacleProximity.far => _values[_Key.proximityFar]!,
  };
  String get nothingRecognized => _values[_Key.nothingRecognized]!;
  String get cameraDenied => _values[_Key.cameraDenied]!;
  String get cameraMissing => _values[_Key.cameraMissing]!;
  String get recognitionFailed => _values[_Key.recognitionFailed]!;
  String get readTextStub => _values[_Key.readTextStub]!;
  String get stopped => _values[_Key.stopped]!;
  String get languageSwitched => _values[_Key.languageSwitched]!;
  String get voiceUnavailable => _values[_Key.voiceUnavailable]!;
  String get lastSpokenLabel => _values[_Key.lastSpokenLabel]!;
}

enum _Key {
  appTitle,
  ocrNotReady,
  describeButton,
  readTextButton,
  repeatButton,
  stopButton,
  languageButton,
  speedButton,
  speedSlow,
  speedNormal,
  speedFast,
  nothingToRepeat,
  doubleTapHint,
  greeting,
  analyzing,
  seeIntro,
  obstacle,
  zoneLeft,
  zoneCenter,
  zoneRight,
  proximityNear,
  proximityFar,
  nothingRecognized,
  cameraDenied,
  cameraMissing,
  recognitionFailed,
  readTextStub,
  stopped,
  languageSwitched,
  voiceUnavailable,
  lastSpokenLabel,
}
