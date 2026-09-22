/*
  Чтение текста с кадра — Tesseract.js прямо в браузере.

  В мобильной версии проекта эта функция была заблокирована: on-device
  движок ML Kit не знает кириллицы, а единственная обвязка Tesseract
  под Android собиралась через закрытый в 2021 году JCenter. В браузере
  обеих проблем нет — Tesseract тут подключается как обычная библиотека
  и работает без сервера и без ключей.

  Распознаются русский и казахский вместе: на упаковке лекарства или
  на вывеске языки соседствуют, а спрашивать незрячего человека,
  на каком языке текст, который он не видит, бессмысленно.
*/
const OCR = (() => {
  /* Слова ниже этого порога Tesseract выдаёт уверенно и неправильно —
     на смазанном кадре получается правдоподобный мусор. */
  const MIN_WORD_CONFIDENCE = 60;

  /* Если после фильтра выжило меньше половины слов, распознан, скорее
     всего, шум. Зачитать такое опаснее, чем честно промолчать:
     проверить результат глазами пользователь не может. */
  const MIN_SURVIVING_SHARE = 0.5;

  let worker = null;
  let loading = null;

  function isMeaningful(word) {
    const text = word.trim();
    if (text.length >= 2) return true;
    // Одиночная цифра осмысленна — это может быть дозировка.
    return /^\d$/.test(text);
  }

  async function init(onProgress) {
    if (worker) return worker;
    if (loading) return loading;

    loading = (async () => {
      worker = await Tesseract.createWorker(['rus', 'kaz'], 1, {
        logger: (m) => {
          if (onProgress && m.status === 'recognizing text') {
            onProgress(m.progress);
          }
        },
      });
      return worker;
    })();

    return loading;
  }

  /*
    Возвращает `{ text, confidence }`. Пустой `text` означает
    «разобрать не удалось» — это штатный ответ, а не ошибка.
  */
  async function read(canvas, onProgress) {
    const engine = await init(onProgress);
    const { data } = await engine.recognize(canvas);

    const words = (data.words || []).filter((w) => isMeaningful(w.text || ''));
    if (words.length === 0) return { text: '', confidence: 0 };

    const kept = words.filter((w) => w.confidence >= MIN_WORD_CONFIDENCE);
    if (kept.length / words.length < MIN_SURVIVING_SHARE) {
      return { text: '', confidence: 0 };
    }

    const text = kept.map((w) => w.text.trim()).join(' ').replace(/\s+/g, ' ');
    const confidence =
      kept.reduce((sum, w) => sum + w.confidence, 0) / kept.length / 100;

    return { text: text.trim(), confidence };
  }

  return { read, init };
})();
