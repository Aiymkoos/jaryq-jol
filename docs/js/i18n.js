/*
  Строки интерфейса на казахском и русском.

  Отдельной библиотеки локализации нет: на двух языках и одном экране
  простая таблица читается яснее, чем формат сообщений с плюрализацией.
*/
const I18N = {
  ru: {
    tag: 'ru-RU',
    label: 'Русский',

    appTitle: 'Jaryq Jol',
    describeButton: 'Описать обстановку',
    readTextButton: 'Прочитать текст',
    whereButton: 'Где я',
    repeatButton: 'Повторить',
    stopButton: 'Остановить',
    languageButton: 'Сменить язык',
    speedButton: 'Скорость речи',
    lastSpokenLabel: 'Последнее озвученное:',

    speedSlow: 'медленная',
    speedNormal: 'обычная',
    speedFast: 'быстрая',

    greeting: 'Здравствуйте. Jaryq Jol запущен.',
    doubleTapHint: 'Дважды коснитесь экрана, чтобы описать обстановку.',
    analyzing: 'Смотрю',
    readingText: 'Читаю текст',
    locating: 'Определяю, где вы находитесь',
    loadingModel: 'Готовлю распознавание, это занимает несколько секунд',
    stopped: 'Остановлено.',
    nothingToRepeat: 'Пока нечего повторять.',

    seeIntro: 'Вижу:',
    obstacle: 'Препятствие',
    zoneLeft: 'слева',
    zoneCenter: 'по центру',
    zoneRight: 'справа',
    proximityNear: 'близко',
    proximityFar: 'далеко',

    nothingRecognized:
      'Не могу разобрать, что передо мной. Улучшите освещение и повторите снимок.',
    noTextFound: 'Текста не вижу. Поднесите ближе или включите свет.',
    textUnreadable: 'Текст есть, но разобрать его я не могу.',
    textIntro: 'Текст:',

    cameraDenied: 'Нет доступа к камере. Разрешите его в настройках браузера.',
    cameraMissing: 'Камера не найдена.',
    cameraFailed: 'Не удалось получить изображение с камеры.',
    recognitionFailed: 'Не удалось распознать. Попробуйте ещё раз.',
    needsHttps: 'Камера работает только на защищённом соединении.',

    locationDenied:
      'Нет доступа к геопозиции. Разрешите его в настройках браузера.',
    locationFailed: 'Не удалось определить местоположение.',
    locationUnknown: 'Определить адрес не получилось.',
    youAreAt: 'Вы находитесь:',
    accuracyPoor:
      'Точность определения низкая, адрес может быть указан неверно.',
    offline: 'Нет интернета. Определение адреса работает только онлайн.',

    languageSwitched: 'Язык переключён на русский.',
    voiceUnavailable:
      'На устройстве нет казахского голоса. Используется русский.',
  },

  kk: {
    tag: 'kk-KZ',
    label: 'Қазақша',

    appTitle: 'Jaryq Jol',
    describeButton: 'Айналаны сипаттау',
    readTextButton: 'Мәтінді оқу',
    whereButton: 'Мен қайдамын',
    repeatButton: 'Қайталау',
    stopButton: 'Тоқтату',
    languageButton: 'Тілді ауыстыру',
    speedButton: 'Сөйлеу жылдамдығы',
    lastSpokenLabel: 'Соңғы айтылған:',

    speedSlow: 'баяу',
    speedNormal: 'қалыпты',
    speedFast: 'жылдам',

    greeting: 'Сәлеметсіз бе. Jaryq Jol қосылды.',
    doubleTapHint: 'Айналаны сипаттау үшін экранды екі рет түртіңіз.',
    analyzing: 'Қарап тұрмын',
    readingText: 'Мәтінді оқып тұрмын',
    locating: 'Қайда тұрғаныңызды анықтап жатырмын',
    loadingModel: 'Тануды дайындап жатырмын, бірнеше секунд кетеді',
    stopped: 'Тоқтатылды.',
    nothingToRepeat: 'Әзірге қайталайтын ештеңе жоқ.',

    seeIntro: 'Көріп тұрмын:',
    obstacle: 'Кедергі',
    zoneLeft: 'сол жақта',
    zoneCenter: 'ортада',
    zoneRight: 'оң жақта',
    proximityNear: 'жақын',
    proximityFar: 'алыс',

    nothingRecognized:
      'Не бар екенін ажырата алмадым. Жарықты жақсартып, суретті қайталаңыз.',
    noTextFound: 'Мәтінді көріп тұрған жоқпын. Жақынырақ ұстаңыз.',
    textUnreadable: 'Мәтін бар, бірақ оны ажырата алмадым.',
    textIntro: 'Мәтін:',

    cameraDenied: 'Камераға рұқсат жоқ. Браузер параметрлерінен рұқсат беріңіз.',
    cameraMissing: 'Камера табылмады.',
    cameraFailed: 'Камерадан сурет алу мүмкін болмады.',
    recognitionFailed: 'Тану сәтсіз аяқталды. Қайталап көріңіз.',
    needsHttps: 'Камера тек қорғалған қосылымда жұмыс істейді.',

    locationDenied:
      'Геолокацияға рұқсат жоқ. Браузер параметрлерінен рұқсат беріңіз.',
    locationFailed: 'Орналасқан жерді анықтау мүмкін болмады.',
    locationUnknown: 'Мекенжайды анықтау мүмкін болмады.',
    youAreAt: 'Сіз мына жерде тұрсыз:',
    accuracyPoor: 'Дәлдік төмен, мекенжай дұрыс болмауы мүмкін.',
    offline: 'Интернет жоқ. Мекенжайды анықтау тек онлайн жұмыс істейді.',

    languageSwitched: 'Тіл қазақ тіліне ауыстырылды.',
    voiceUnavailable:
      'Құрылғыда қазақ тілінің дауысы жоқ. Орыс тіліндегі дауыс қолданылады.',
  },
};

const I18N_OTHER = { ru: 'kk', kk: 'ru' };
