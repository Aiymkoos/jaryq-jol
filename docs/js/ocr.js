/* On-device Russian/Kazakh OCR. Keep full text or reject the whole result. */
const OCR = (() => {
  const MIN_WORD_CONFIDENCE = 60;
  let worker = null;
  let loading = null;

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

    return loading.catch(err => { loading = null; worker = null; throw err; });
  }

  /*
    Возвращает `{ text, confidence }`. Пустой `text` означает
    «разобрать не удалось» — это штатный ответ, а не ошибка.
  */
  async function read(canvas, onProgress) {
    const engine = await init(onProgress);
    const { data } = await engine.recognize(canvas);

    const words = (data.words || []).filter(w => (w.text || '').trim());
    const uncertain = words.some(w => !Number.isFinite(w.confidence) || w.confidence < MIN_WORD_CONFIDENCE);
    if (!Number.isFinite(data.confidence) || data.confidence < 65 || uncertain) {
      return { text: '', confidence: 0 };
    }
    return { text: (data.text || '').trim(), confidence: data.confidence / 100 };
  }

  return { read, init };
})();
