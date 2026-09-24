/*
  Распознавание обстановки — COCO-SSD через TensorFlow.js, в браузере.

  В отличие от базового детектора ML Kit в мобильной версии, эта модель
  отдаёт рамку и класс предмета из одного прохода. Поэтому здесь можно
  говорить «стул слева», не рискуя перепутать: рамка и название пришли
  вместе и относятся к одному объекту. В мобильной версии классификация
  была отключена именно из-за этого риска.
*/
const Vision = (() => {
  /* Объект считается близким, если занимает больше четверти кадра.
     Это грубая прикидка по площади, а не измеренное расстояние. */
  const NEAR_AREA_RATIO = 0.25;

  /* Границы левой и правой третей кадра. */
  const LEFT_EDGE = 1 / 3;
  const RIGHT_EDGE = 2 / 3;

  /* Ниже этого порога объект отбрасывается совсем. */
  const MIN_SCORE = 0.5;

  /* Назвать предмет можно только при высокой уверенности. Между
     «стул по центру» и «препятствие по центру» пользователь не может
     перепроверить разницу глазами, поэтому при сомнении говорится
     только положение. */
  const NAMING_SCORE = 0.62;

  let model = null;
  let loading = null;

  async function init() {
    if (model) return model;
    if (loading) return loading;

    loading = cocoSsd.load({ base: 'lite_mobilenet_v2' }).then((m) => {
      model = m;
      return m;
    });
    return loading.catch(err => { loading = null; throw err; });
  }

  function toObstacle(prediction, width, height) {
    const [x, y, w, h] = prediction.bbox;
    const centerX = (x + w / 2) / width;

    const zone = centerX < LEFT_EDGE
      ? 'zoneLeft'
      : centerX > RIGHT_EDGE
        ? 'zoneRight'
        : 'zoneCenter';

    const areaRatio = (w * h) / (width * height);

    return {
      zone,
      proximity: areaRatio >= NEAR_AREA_RATIO ? 'proximityNear' : 'proximityFar',
      areaRatio,
      cls: prediction.class,
      score: prediction.score,
      hazard: HAZARD_LABELS.has(prediction.class),
    };
  }

  async function observe(canvas) {
    const engine = await init();
    const predictions = await engine.detect(canvas, 20, MIN_SCORE);

    return {
      obstacles: predictions.map((p) =>
        toObstacle(p, canvas.width, canvas.height)),
    };
  }

  /*
    Самое важное препятствие. Обычно это самое крупное — оно же самое
    близкое. Но машина или человек перед пользователем важнее стены,
    занимающей полкадра, поэтому опасные классы идут вперёд.
  */
  function mostImportant(obstacles) {
    if (obstacles.length === 0) return null;
    const hazards = obstacles.filter((o) => o.hazard);
    const pool = hazards.length > 0 ? hazards : obstacles;
    return pool.reduce((a, b) => (a.areaRatio >= b.areaRatio ? a : b));
  }

  /*
    Собирает фразу, которую услышит пользователь.

    Перечислять всё, что попало в кадр, значит утопить нужное в шуме:
    на слух список из восьми предметов не удерживается. Поэтому сначала
    главное препятствие, затем короткий список остального.
  */
  function describe(observation, lang) {
    const t = I18N[lang];
    const parts = [];
    const { obstacles } = observation;

    const main = mostImportant(obstacles);
    if (main) {
      const name = main.score >= NAMING_SCORE ? labelName(main.cls, lang) : null;
      const subject = name
        ? name.charAt(0).toUpperCase() + name.slice(1)
        : t.obstacle;
      parts.push(`${subject} ${t[main.zone]}.`);
    }

    // Множество убирает повторы: четыре стула в кадре должны прозвучать
    // как «стул», а не четыре раза подряд.
    const others = new Set();
    obstacles.forEach((o) => {
      if (o === main || o.score < NAMING_SCORE) return;
      const name = labelName(o.cls, lang);
      if (name) others.add(name);
    });

    if (others.size > 0) {
      parts.push(`${t.seeIntro} ${[...others].slice(0, 4).join(', ')}.`);
    }

    // Пусто и когда модель ничего не нашла, и когда все её классы
    // оказались вне словаря. Для пользователя разницы нет: описать нечем.
    if (parts.length === 0) return t.nothingRecognized;

    return parts.join(' ');
  }

  return { observe, describe, init };
})();
