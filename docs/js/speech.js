/*
  Синтез речи средствами браузера.

  Голос — единственный канал вывода для незрячего пользователя, поэтому
  здесь важнее не «красиво», а «никогда не молчит незаметно»: если голоса
  нужного языка нет, приложение говорит об этом, а не замолкает.
*/
const Speech = (() => {
  const RATES = { slow: 0.8, normal: 1.0, fast: 1.4 };

  let rate = 'normal';
  let lang = 'ru';
  let voices = [];
  let usingFallback = false;
  let speaking = false;
  let onChange = () => {};

  const supported =
    typeof window !== 'undefined' && 'speechSynthesis' in window;

  function loadVoices() {
    if (!supported) return;
    voices = window.speechSynthesis.getVoices() || [];
  }

  if (supported) {
    loadVoices();
    // В Safari и Chrome список голосов приходит асинхронно и в момент
    // загрузки страницы почти всегда пуст.
    window.speechSynthesis.addEventListener('voiceschanged', loadVoices);
  }

  /* Ищем голос по языку, а не по полному тегу: на устройствах встречается
     и `ru-RU`, и `ru_RU`, и просто `ru`. */
  function findVoice(tag) {
    const prefix = tag.slice(0, 2).toLowerCase();
    return voices.find((v) => (v.lang || '').toLowerCase().startsWith(prefix));
  }

  function hasVoice(tag) {
    // Пустой список означает «браузер ещё не отдал голоса», а не «голосов
    // нет». Считать это отсутствием языка значило бы ложно сообщать
    // о переходе на запасной голос при каждом запуске.
    if (voices.length === 0) return true;
    return Boolean(findVoice(tag));
  }

  function speak(text) {
    if (!supported || !text) return;

    // Без отмены браузер ставит фразы в очередь, и пользователь ждёт
    // окончания предыдущей, вместо того чтобы услышать новую.
    window.speechSynthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    const tag = I18N[lang].tag;
    const voice = findVoice(tag) || (usingFallback
      ? findVoice(I18N[I18N_OTHER[lang]].tag)
      : null);

    if (voice) utterance.voice = voice;
    utterance.lang = voice ? voice.lang : tag;
    utterance.rate = RATES[rate];
    utterance.volume = 1;
    utterance.pitch = 1;

    utterance.onend = finish;
    utterance.onerror = finish;

    speaking = true;
    onChange();
    window.speechSynthesis.speak(utterance);
  }

  function finish() {
    if (!speaking) return;
    speaking = false;
    onChange();
  }

  function stop() {
    if (supported) window.speechSynthesis.cancel();
    finish();
  }

  function setLanguage(next) {
    lang = next;
    loadVoices();
    usingFallback = !hasVoice(I18N[next].tag);
    onChange();
    return usingFallback;
  }

  function cycleRate() {
    rate = rate === 'slow' ? 'normal' : rate === 'normal' ? 'fast' : 'slow';
    onChange();
    return rate;
  }

  return {
    supported,
    speak,
    stop,
    setLanguage,
    cycleRate,
    get rate() { return rate; },
    get isSpeaking() { return speaking; },
    get usingFallbackVoice() { return usingFallback; },
    set onChange(fn) { onChange = fn; },
  };
})();
