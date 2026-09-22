/*
  Определение местоположения и адреса.

  Геопозиция берётся у браузера, адрес — у Nominatim (OpenStreetMap).
  Координаты уходят только в этот один запрос и нигде не сохраняются.

  Построения маршрута здесь пока нет, и это сознательно. Публичный
  демо-сервер OSRM отвечает на запрос пешеходного профиля, но считает
  по автомобильной сети — в ответе так и приходит `"mode":"driving"`.
  Вести незрячего человека по дороге для машин и называть это пешеходным
  маршрутом нельзя. Что нужно для настоящей навигации — записано в README.
*/
const NavError = {
  DENIED: 'denied',
  UNAVAILABLE: 'unavailable',
  TIMEOUT: 'timeout',
  OFFLINE: 'offline',
  FAILED: 'failed',
};

const Navigation = (() => {
  /* Выше этой погрешности адрес называть можно, но с оговоркой:
     на 100 метрах легко промахнуться улицей. */
  const ACCURACY_WARN_METERS = 50;

  function position() {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(NavError.UNAVAILABLE);
        return;
      }

      navigator.geolocation.getCurrentPosition(
        resolve,
        (err) => {
          if (err.code === err.PERMISSION_DENIED) reject(NavError.DENIED);
          else if (err.code === err.TIMEOUT) reject(NavError.TIMEOUT);
          else reject(NavError.UNAVAILABLE);
        },
        { enableHighAccuracy: true, timeout: 15000, maximumAge: 10000 },
      );
    });
  }

  async function addressOf(lat, lon, lang) {
    const url = new URL('https://nominatim.openstreetmap.org/reverse');
    url.searchParams.set('format', 'json');
    url.searchParams.set('lat', lat);
    url.searchParams.set('lon', lon);
    url.searchParams.set('zoom', '18');
    url.searchParams.set('accept-language', lang === 'kk' ? 'kk,ru' : 'ru');

    const response = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!response.ok) throw NavError.FAILED;

    const data = await response.json();
    return data && data.address ? data.address : null;
  }

  /* Собираем адрес от улицы к району: человеку на месте нужна улица,
     а область и страна он и так знает. */
  function spokenAddress(address) {
    if (!address) return null;

    const street = address.road || address.pedestrian || address.footway;
    const house = address.house_number;
    const area = address.suburb || address.neighbourhood || address.city_district;
    const city = address.city || address.town || address.village;

    const parts = [];
    if (street) parts.push(house ? `${street}, ${house}` : street);
    if (area) parts.push(area);
    if (!street && city) parts.push(city);

    return parts.length > 0 ? parts.join(', ') : null;
  }

  async function whereAmI(lang) {
    if (!navigator.onLine) throw NavError.OFFLINE;

    const pos = await position();
    const { latitude, longitude, accuracy } = pos.coords;

    let address;
    try {
      address = await addressOf(latitude, longitude, lang);
    } catch (_) {
      throw NavError.FAILED;
    }

    return {
      text: spokenAddress(address),
      accuracy,
      imprecise: accuracy > ACCURACY_WARN_METERS,
    };
  }

  return { whereAmI };
})();
