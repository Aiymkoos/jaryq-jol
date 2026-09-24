/*
  Доступ к камере и снятие кадра.

  Кадр никуда не отправляется: и распознавание предметов, и чтение текста
  выполняются прямо в браузере. Снимок живёт только в памяти вкладки
  и не сохраняется ни на диск, ни на сервер.
*/
const CameraError = {
  DENIED: 'denied',
  MISSING: 'missing',
  INSECURE: 'insecure',
  FAILED: 'failed',
};

const Camera = (() => {
  let stream = null;
  let generation = 0;
  const video = () => document.getElementById('cam');
  const canvas = () => document.getElementById('frame');

  function classify(err) {
    const name = err && err.name;
    if (name === 'NotAllowedError' || name === 'SecurityError') {
      return CameraError.DENIED;
    }
    if (name === 'NotFoundError' || name === 'OverconstrainedError') {
      return CameraError.MISSING;
    }
    return CameraError.FAILED;
  }

  async function start() {
    if (stream) return;

    // getUserMedia существует только на https и на localhost. Без этой
    // проверки браузер выдаёт невнятный TypeError вместо понятной причины.
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw CameraError.INSECURE;
    }

    const token = generation;
    try {
      const acquired = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      });
      if (token !== generation) { acquired.getTracks().forEach(t => t.stop()); throw CameraError.FAILED; }
      stream = acquired;
    } catch (err) {
      throw classify(err);
    }

    const el = video();
    el.srcObject = stream;
    // playsinline выставлен и в разметке, и здесь: iOS Safari иначе
    // открывает поток на весь экран поверх интерфейса.
    el.setAttribute('playsinline', '');
    el.muted = true;

    try {
      await el.play();
    } catch (err) {
      throw classify(err);
    }

    await ready(el);
  }

  /* Первые кадры после play() бывают пустыми: размер потока ещё не
     известен, и снимок получился бы нулевым. */
  function ready(el) {
    if (el.videoWidth > 0) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(CameraError.FAILED), 6000);
      el.addEventListener('loadeddata', () => {
        clearTimeout(timer);
        resolve();
      }, { once: true });
    });
  }

  async function capture() {
    try {
      await start();
      const el = video(), cv = canvas();
      if (!el.videoWidth || !el.videoHeight) throw CameraError.FAILED;
      cv.width = el.videoWidth; cv.height = el.videoHeight;
      cv.getContext('2d').drawImage(el, 0, 0, cv.width, cv.height);
      return cv;
    } finally { stop(); }
  }

  function stop() {
    generation++;
    if (!stream) return;
    stream.getTracks().forEach((t) => t.stop());
    stream = null;
    video().srcObject = null;
  }

  return { start, capture, stop, element: video };
})();
