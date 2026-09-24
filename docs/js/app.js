/*
  Сборка экрана: обработчики кнопок, состояние, озвучка результата.
*/
(() => {
  const el = (id) => document.getElementById(id);

  const panelText = el('panel-text');
  const panelLabel = el('panel-label');
  const statusLine = el('status');
  const tapArea = el('tap-area');

  let lang = 'ru';
  let lastSpoken = '';
  let busy = false;
  let operation = 0;
  let greeted = false;

  const t = () => I18N[lang];

  /* --- Сохранение настроек ---
     Приватный режим и отключённые cookie ломают localStorage. Настройки —
     не то, из-за чего стоит не запустить приложение. */

  function saveSettings() {
    try {
      localStorage.setItem('lang', lang);
      localStorage.setItem('rate', Speech.rate);
    } catch (_) { /* без сохранения приложение работает так же */ }
  }

  function loadSettings() {
    try {
      const savedLang = localStorage.getItem('lang');
      if (savedLang && I18N[savedLang]) lang = savedLang;

      const savedRate = localStorage.getItem('rate');
      while (['slow', 'normal', 'fast'].includes(savedRate) && Speech.rate !== savedRate) Speech.cycleRate();
    } catch (_) { /* значения по умолчанию уже выставлены */ }
  }

  /* --- Вывод --- */

  function say(text) {
    lastSpoken = text;
    panelText.textContent = text;
    tapArea.setAttribute('aria-label', `${t().lastSpokenLabel} ${text}`);
    Speech.speak(text);
  }

  function status(text, isError = false) {
    statusLine.textContent = text;
    statusLine.classList.toggle('error', isError);
  }

  function setBusy(value) {
    busy = value;
    el('stop-btn').disabled = !value && !Speech.isSpeaking;
    ['describe-btn', 'read-btn', 'where-btn'].forEach((id) => {
      el(id).disabled = value;
    });
  }

  /* --- Перерисовка интерфейса после смены языка --- */

  function render() {
    const s = t();
    document.documentElement.lang = lang === 'kk' ? 'kk' : 'ru';

    panelLabel.textContent = s.lastSpokenLabel;
    el('tap-hint').textContent = s.doubleTapHint;
    tapArea.setAttribute('aria-label', `${s.lastSpokenLabel} ${lastSpoken}`);

    el('describe-btn').querySelector('.action-label').textContent = s.describeButton;
    el('read-btn').querySelector('.action-label').textContent = s.readTextButton;
    el('where-btn').querySelector('.action-label').textContent = s.whereButton;
    el('repeat-btn').querySelector('.action-label').textContent = s.repeatButton;
    el('stop-btn').querySelector('.action-label').textContent = s.stopButton;

    // Кнопка языка подписана тем языком, на который переключит, а не
    // текущим: она отвечает на вопрос «что будет, если нажать».
    const other = I18N[I18N_OTHER[lang]];
    el('lang-label').textContent = other.label;
    el('lang-btn').setAttribute('aria-label', `${s.languageButton}: ${other.label}`);

    const rateName = s[`speed${Speech.rate[0].toUpperCase()}${Speech.rate.slice(1)}`];
    el('speed-btn').setAttribute('aria-label', `${s.speedButton}: ${rateName}`);
    el('speed-icon').textContent =
      Speech.rate === 'slow' ? '›' : Speech.rate === 'normal' ? '››' : '›››';
  }

  /* --- Ошибки камеры --- */

  function cameraMessage(code) {
    const s = t();
    if (code === CameraError.DENIED) return s.cameraDenied;
    if (code === CameraError.MISSING) return s.cameraMissing;
    if (code === CameraError.INSECURE) return s.needsHttps;
    return s.cameraFailed;
  }

  function navMessage(code) {
    const s = t();
    if (code === NavError.DENIED) return s.locationDenied;
    if (code === NavError.OFFLINE) return s.offline;
    if (code === NavError.TIMEOUT || code === NavError.UNAVAILABLE) {
      return s.locationFailed;
    }
    return s.locationUnknown;
  }

  /* --- Действия --- */

  async function describeScene() {
    if (busy) return;
    const token = ++operation;
    setBusy(true);
    // Пользователь не видит индикатор загрузки, поэтому о начале работы
    // сообщаем голосом.
    say(t().analyzing);

    try {
      const canvas = await Camera.capture();
      if (token !== operation) return;
      status(t().loadingModel);
      const observation = await Vision.observe(canvas);
      if (token !== operation) return;
      status('');
      say(Vision.describe(observation, lang));
    } catch (err) {
      if (token !== operation) return;
      status('');
      say(typeof err === 'string' ? cameraMessage(err) : t().recognitionFailed);
    } finally {
      setBusy(false);
      status('');
    }
  }

  async function readText() {
    if (busy) return;
    const token = ++operation;
    setBusy(true);
    say(t().readingText);

    try {
      const canvas = await Camera.capture();
      if (token !== operation) return;
      status(t().loadingModel);

      const result = await OCR.read(canvas, (p) => {
        if (token === operation) status(`${Math.round(p * 100)}%`);
      });
      status('');

      if (token !== operation) return;
      say(result.text ? `${t().textIntro} ${result.text}` : t().noTextFound);
    } catch (err) {
      if (token !== operation) return;
      status('');
      say(typeof err === 'string' ? cameraMessage(err) : t().recognitionFailed);
    } finally {
      setBusy(false);
      status('');
    }
  }

  async function whereAmI() {
    if (busy) return;
    const token = ++operation;
    setBusy(true);
    say(t().locating);

    try {
      const place = await Navigation.whereAmI(lang);
      if (token !== operation) return;
      if (!place.text) {
        say(t().locationUnknown);
      } else {
        const warn = place.imprecise ? ` ${t().accuracyPoor}` : '';
        say(`${t().youAreAt} ${place.text}.${warn}`);
      }
    } catch (err) {
      if (token !== operation) return;
      say(navMessage(err));
    } finally {
      setBusy(false);
      status('');
    }
  }

  /* Повтор последней фразы: речь легко пропустить мимо ушей, а снимать
     кадр заново ради этого незачем. */
  function repeat() {
    if (!lastSpoken) {
      say(t().nothingToRepeat);
      return;
    }
    Speech.speak(lastSpoken);
  }

  function stop() {
    operation++;
    Camera.stop();
    status('');
    Speech.stop();
    panelText.textContent = t().stopped;
    lastSpoken = t().stopped;
  }

  function switchLanguage() {
    lang = I18N_OTHER[lang];
    const fallback = Speech.setLanguage(lang);
    saveSettings();
    render();
    say(fallback
      ? `${t().languageSwitched} ${t().voiceUnavailable}`
      : t().languageSwitched);
  }

  function cycleSpeed() {
    Speech.cycleRate();
    saveSettings();
    render();
    // Новую скорость произносим уже на ней самой — так пользователь
    // сразу слышит результат, а не только название.
    const s = t();
    const name = s[`speed${Speech.rate[0].toUpperCase()}${Speech.rate.slice(1)}`];
    say(`${s.speedButton}: ${name}`);
  }

  /* --- Запуск --- */

  function greetOnce() {
    if (greeted) return;
    greeted = true;
    say(`${t().greeting} ${t().doubleTapHint}`);
  }

  function init() {
    loadSettings();
    Speech.setLanguage(lang);
    Speech.onChange = () => {
      el('stop-btn').disabled = !busy && !Speech.isSpeaking;
    };
    render();
    el('stop-btn').disabled = true;

    el('describe-btn').addEventListener('click', describeScene);
    el('read-btn').addEventListener('click', readText);
    el('where-btn').addEventListener('click', whereAmI);
    el('repeat-btn').addEventListener('click', repeat);
    el('stop-btn').addEventListener('click', stop);
    el('lang-btn').addEventListener('click', switchLanguage);
    el('speed-btn').addEventListener('click', cycleSpeed);

    tapArea.addEventListener('dblclick', describeScene);
    // Скринридеры перехватывают жесты и до dblclick их не доносят:
    // в TalkBack и VoiceOver двойное касание приходит как обычный click
    // по элементу с ролью кнопки.
    tapArea.addEventListener('click', (e) => {
      if (e.detail === 0) describeScene();
    });
    tapArea.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        describeScene();
      }
    });

    // iOS и Chrome не дают синтезу речи заговорить до первого действия
    // пользователя. Приветствие поэтому ждёт любого касания, а подсказка
    // о жесте до этого момента доступна скринридеру из разметки.
    ['pointerdown', 'keydown'].forEach((evt) => {
      window.addEventListener(evt, greetOnce, { once: true });
    });

    if (!Speech.supported) {
      status('Синтез речи в этом браузере недоступен.', true);
    }
  }

  window.addEventListener('pagehide', stop);
  document.addEventListener('visibilitychange', () => { if (document.hidden) stop(); });
  init();
})();
