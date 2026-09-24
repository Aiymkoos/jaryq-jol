import {spokenAddress} from './address.js';
import {Progress,meters,parseRoute,instruction,command,guidance,announcementKey} from './navigation.js';
const $=id=>document.getElementById(id);
const stored=k=>{try{return localStorage.getItem(k)}catch{return null}};
const save=(k,v)=>{try{localStorage.setItem(k,v)}catch{}};
let kk=stored('jaryq-language')==='kk',rate=Number(stored('jaryq-rate')||1),page='route',last='',busy=false,operation=0;
let route,progress,position,map,routeLayer,currentMarker,endMarker,watchId,watchdog,listening,recognition,networkConsent=false;
let lastRequest=0,lastAlert=0,searchSequence=0;
const resultsCache=new Map();
const tr=(ru,kz)=>kk?kz:ru;
if(!Number.isFinite(rate)||rate<0.5||rate>2)rate=1;
let guidanceGeneration=0;
let labels={};fetch('labels.json').then(r=>r.json()).then(d=>labels=d).catch(()=>{});
function translate(){document.documentElement.lang=kk?'kk':'ru';document.querySelectorAll('[data-ru]').forEach(el=>el.textContent=el.dataset[kk?'kk':'ru']);$('language').textContent=kk?'РУС':'ҚАЗ';$('language').ariaLabel=kk?'Орыс тіліне ауыстыру':'Переключить на казахский';$('destination').placeholder=tr('Например, парк 28 панфиловцев','Мысалы, 28 панфиловшылар саябағы');$('command').placeholder=tr('Что передо мной?','Алдымда не бар?');networkStatus();if(route)renderRoute();}
function speak(text,{display=true}={}){
 if(display){last=text;$('answer').textContent=text;}
 if(!('speechSynthesis' in window))return;
 speechSynthesis.cancel();const utterance=new SpeechSynthesisUtterance(text);utterance.lang=kk?'kk-KZ':'ru-RU';utterance.rate=rate;
 const voices=speechSynthesis.getVoices();const matching=voices.find(v=>v.lang.toLowerCase().startsWith(kk?'kk':'ru'));if(matching)utterance.voice=matching;
 utterance.onerror=()=>{};speechSynthesis.speak(utterance);
}
function setPage(name){page=name;document.querySelectorAll('.page').forEach(p=>p.hidden=p.id!==`${name}-page`);document.querySelectorAll('[data-page]').forEach(b=>{b.classList.toggle('active',b.dataset.page===name);if(b.dataset.page===name)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});if(name==='route'&&map)setTimeout(()=>map.invalidateSize(),50);}
function networkStatus(){$('network').textContent=navigator.onLine?tr('Онлайн','Онлайн'):tr('Без сети','Желі жоқ');}
window.addEventListener('online',networkStatus);window.addEventListener('offline',()=>{networkStatus();speak(tr('Нет интернета. Новый маршрут и первая загрузка моделей недоступны. Уже загруженный маршрут остаётся на экране.','Интернет жоқ. Жаңа маршрут пен модельдердің алғашқы жүктелуі қолжетімсіз. Жүктелген маршрут экранда қалады.'));});
function markBusy(value){busy=value;$('busy').hidden=!value;for(const id of ['describe','read','rebuild','start-route'])$(id).disabled=value;document.querySelector('#search-form button').disabled=value;}
async function task(fn){if(busy)return;const token=++operation;markBusy(true);stopMic();try{const result=await fn(token);if(result&&token===operation)speak(result);}catch(e){if(token===operation)speak(errorText(e));}finally{markBusy(false);}}
function errorText(e){
 if(e?.code===1||/Permission|NotAllowed/i.test(e?.name||''))return tr('Доступ запрещён. Разрешите камеру, микрофон или геопозицию в настройках браузера для этого сайта.','Қолжетімділікке рұқсат жоқ. Браузер баптауларынан осы сайтқа камера, микрофон немесе геолокация рұқсатын беріңіз.');
 if(e?.code===3)return tr('Не удалось вовремя определить геопозицию. Подождите на открытом месте и повторите.','Орныңыз уақытында анықталмады. Ашық жерде күтіп, қайталаңыз.');
 if(/too_dark/.test(e?.message||''))return tr('Слишком темно для камеры. Улучшите освещение. Я не могу надёжно описать этот снимок.','Камера үшін тым қараңғы. Жарықты жақсартыңыз. Бұл суретті сенімді сипаттай алмаймын.');
 if(/no_route/.test(e?.message||''))return tr('Пешеходный маршрут не найден. Выберите другой адрес или вход.','Жаяу маршрут табылмады. Басқа мекенжай немесе кіреберісті таңдаңыз.');
 if(/camera_unsupported/.test(e?.message||''))return tr('Камера недоступна. Откройте сайт по HTTPS в Safari или Chrome.','Камера қолжетімсіз. Сайтты HTTPS арқылы Safari не Chrome-да ашыңыз.');
 return tr('Не удалось выполнить действие. Проверьте разрешения и интернет, затем попробуйте ещё раз.','Әрекет орындалмады. Рұқсаттар мен интернетті тексеріп, қайталаңыз.');
}
async function consent(){if(networkConsent)return true;return new Promise(resolve=>{const dialog=$('consent');dialog.showModal();const finish=v=>{networkConsent=v;dialog.close();resolve(v);};$('consent-no').onclick=()=>finish(false);$('consent-yes').onclick=()=>finish(true);dialog.oncancel=()=>finish(false);});}
async function throttle(){const delay=1100-(Date.now()-lastRequest);if(delay>0)await new Promise(r=>setTimeout(r,delay));lastRequest=Date.now();}
async function request(url){await throttle();const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),25000);try{const r=await fetch(url,{signal:controller.signal,referrerPolicy:'strict-origin-when-cross-origin'});if(!r.ok)throw new Error('network_'+r.status);return await r.json();}finally{clearTimeout(timer)}}
async function locate(){if(!navigator.geolocation)throw new Error('location_unsupported');return new Promise((resolve,reject)=>navigator.geolocation.getCurrentPosition(p=>{position=p;showGps(p);resolve(p);},reject,{enableHighAccuracy:true,timeout:20000,maximumAge:0}));}
function showGps(p){$('gps-status').textContent=`GPS ±${Math.round(p.coords.accuracy)} ${tr('м','м')}`;if(map){const latlng=[p.coords.latitude,p.coords.longitude];if(!currentMarker)currentMarker=L.circleMarker(latlng,{radius:9,color:'#fff',weight:3,fillColor:'#1456ce',fillOpacity:1}).addTo(map);else currentMarker.setLatLng(latlng);}}
async function search(){
 const q=$('destination').value.trim();if(q.length<3){speak(tr('Введите хотя бы три буквы.','Кемінде үш әріп енгізіңіз.'));return;}
 if(busy||!await consent())return;const seq=++searchSequence;
 await task(async token=>{
  speak(tr('Ищу место в Алматы.','Алматыдан орын іздеп жатырмын.'));
  let places=resultsCache.get(q);
  if(!places){const u=new URL('https://nominatim.openstreetmap.org/search');u.search=new URLSearchParams({q:`${q}, Алматы`,format:'jsonv2',limit:'5',countrycodes:'kz','accept-language':'ru',viewbox:'76.7,43.4,77.2,43.05',bounded:'1'});const data=await request(u);places=data.map(p=>({name:p.display_name,point:{lat:Number(p.lat),lon:Number(p.lon)}}));resultsCache.set(q,places);}
  if(token!==operation||seq!==searchSequence)return;
  $('places').replaceChildren();
  for(const place of places){const b=document.createElement('button');b.type='button';b.textContent=place.name;b.addEventListener('click',()=>buildRoute(place));$('places').append(b);}
  if(places.length)$('places').querySelector('button').focus();
  return places.length?tr(`Найдено ${places.length}. Выберите нужный адрес.`,`${places.length} орын табылды. Мекенжайды таңдаңыз.`):tr('Место не найдено. Попробуйте точный адрес.','Орын табылмады. Нақты мекенжайды енгізіңіз.');
 });
}
function routePoint(p){return {lat:p.coords.latitude,lon:p.coords.longitude};}
async function buildRoute(destination){
 if(busy||!await consent())return;pauseGuidance();
 await task(async token=>{
  speak(tr('Определяю ваше положение и строю пешеходный маршрут.','Орныңызды анықтап, жаяу маршрут құрып жатырмын.'));
  const p=await locate();if(token!==operation)return;
  if(p.coords.accuracy>35)return tr('GPS пока неточен. Подождите на открытом месте и повторите.','GPS дәл емес. Ашық жерде күтіп, қайталаңыз.');
  const from=routePoint(p),to=destination.point;
  const u=`https://routing.openstreetmap.de/routed-foot/route/v1/foot/${from.lon},${from.lat};${to.lon},${to.lat}?overview=full&geometries=geojson&steps=true`;
  const data=await request(u);if(token!==operation)return;
  route=parseRoute(data,destination);progress=new Progress(route);$('places').replaceChildren();renderRoute();
  return tr(`Маршрут ${(route.distance/1000).toFixed(1)} километра, примерно ${Math.ceil(route.duration/60)} минут. Проверьте шаги и нажмите «Начать сопровождение».`,`Бағыт ${(route.distance/1000).toFixed(1)} километр, шамамен ${Math.ceil(route.duration/60)} минут. Қадамдарды тексеріп, «Бағыттауды бастау» түймесін басыңыз.`);
 });
}
function renderRoute(){
 $('route-empty').hidden=true;$('route-detail').hidden=false;$('route-name').textContent=route.destination.name.split(',').slice(0,2).join(',');$('route-metrics').textContent=`${(route.distance/1000).toFixed(1)} км · ${Math.ceil(route.duration/60)} мин`;
 $('steps').replaceChildren();route.steps.forEach(s=>{const li=document.createElement('li');li.textContent=`${instruction(s,kk)} — ${Math.round(s.distance)} м`;$('steps').append(li);});
 nextStep();
 if(!window.L){$('map').textContent=tr('Карта не загрузилась. Все шаги маршрута доступны ниже.','Карта жүктелмеді. Маршрут қадамдары төменде көрсетілген.');return;}
 if(!map){map=L.map('map',{zoomControl:true}).setView([route.points[0].lat,route.points[0].lon],15);L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>'}).addTo(map);}
 if(routeLayer)routeLayer.remove();if(endMarker)endMarker.remove();routeLayer=L.polyline(route.points.map(p=>[p.lat,p.lon]),{color:'#2258cc',weight:6}).addTo(map);endMarker=L.circleMarker([route.destination.point.lat,route.destination.point.lon],{radius:10,color:'#061528',weight:3,fillColor:'#ffd43b',fillOpacity:1}).addTo(map);
 map.fitBounds(routeLayer.getBounds(),{padding:[25,25]});if(position)showGps(position);setTimeout(()=>map.invalidateSize(),100);
}
function nextStep(){if(!route)return;const s=route.steps[progress?.step||0];$('next-step').replaceChildren();const text=document.createElement('div');text.textContent=progress?guidance(progress,kk):instruction(s,kk);const small=document.createElement('small');small.textContent=tr(`Осталось примерно ${Math.round(progress?.remaining??route.distance)} м`,`Шамамен ${Math.round(progress?.remaining??route.distance)} м қалды`);$('next-step').append(text,small);}
function alertThrottled(text){if(Date.now()-lastAlert<20000)return;lastAlert=Date.now();speak(text);}
async function startGuidance(){
 if(!route||busy)return;pauseGuidance();
 const generation=guidanceGeneration;
 await task(async token=>{const p=await locate();if(token!==operation||generation!==guidanceGeneration||document.hidden)return; if(p.coords.accuracy>35)return tr('GPS неточен. Сопровождение пока не включено.','GPS дәл емес. Бағыттау әлі қосылмады.');
  const current=routePoint(p);if(meters(current,route.points[0])>100&&(progress?.along||0)<30)return tr('Вы далеко от начала маршрута. Нажмите «Перестроить».','Маршрут басынан алыссыз. «Қайта құру» түймесін басыңыз.');
  $('start-route').textContent=tr('Сопровождение включено','Бағыттау қосулы');
  watchId=navigator.geolocation.watchPosition(p=>{if(generation===guidanceGeneration)onPosition(p)},e=>{if(generation!==guidanceGeneration)return;pauseGuidance();speak(errorText(e));},{enableHighAccuracy:true,maximumAge:0,timeout:20000});
  watchdog=setInterval(()=>{if(!position||Date.now()-position.timestamp>20000){alertThrottled(tr('Сигнал GPS устарел. Подсказки приостановлены.','GPS сигналы ескірді. Нұсқаулар тоқтатылды.'));}},10000);
  try{if('wakeLock'in navigator)await navigator.wakeLock.request('screen').then(lock=>{if(generation!==guidanceGeneration||document.hidden)return lock.release();wakeLock=lock;});}catch{}
  return tr(`Сопровождение включено. Держите приложение открытым. ${guidance(progress,kk)}. GPS не проверяет безопасность переходов.`,`Бағыттау қосылды. Қолданбаны ашық ұстаңыз. ${guidance(progress,kk)}. GPS өткелдердің қауіпсіздігін тексермейді.`);
 });
}
let wakeLock;
function pauseGuidance(){guidanceGeneration++;if(watchId!==undefined){navigator.geolocation.clearWatch(watchId);watchId=undefined;}clearInterval(watchdog);if(wakeLock){wakeLock.release().catch(()=>{});wakeLock=null;}$('start-route').textContent=tr('Начать сопровождение','Бағыттауды бастау');}
function onPosition(p){
 position=p;showGps(p);const result=progress.update(routePoint(p),p.coords.accuracy,p.timestamp);nextStep();
 if(result.state==='uncertain')return alertThrottled(tr('GPS неточен. Подсказки поворотов приостановлены.','GPS дәл емес. Бұрылыс нұсқаулары тоқтатылды.'));
 if(result.state==='offroute')return alertThrottled(tr('Возможно, вы отклонились от маршрута. Остановитесь в безопасном месте и перестройте маршрут.','Бағыттан ауытқуыңыз мүмкін. Қауіпсіз жерде тоқтап, бағытты қайта құрыңыз.'));
 if(result.state==='arrived'){pauseGuidance();speak(tr('Вы рядом с местом назначения. Уточните вход с помощью камеры или помощника.','Межелі жерге жақындадыңыз. Камера не көмекші арқылы кіреберісті нақтылаңыз.'));return;}
 if(result.state==='tracking'){const key=announcementKey(progress);if(key!==progress.lastAnnouncement){progress.lastAnnouncement=key;speak(guidance(progress,kk));}}
}
async function camera(mode){
 setPage('camera');await task(async token=>{
  speak(mode==='text'?tr('Держите камеру перед текстом. При первом запуске загрузка может занять время.','Камераны мәтінге бағыттаңыз. Алғаш іске қосу біраз уақыт алуы мүмкін.'):tr('Распознаю предметы. Держите телефон неподвижно.','Заттарды танып жатырмын. Телефонды қозғалтпай ұстаңыз.'));
  const r=JSON.parse(await window.jaryq.capture(mode,'rus+kaz'));if(token!==operation)return;
  if(r.error)throw new Error(r.error);
  if(mode==='text')return r.text?tr(`Распознанный текст может содержать ошибки. ${r.text}`,`Танылған мәтінде қате болуы мүмкін. ${r.text}`):tr('Не удалось уверенно прочитать текст. Улучшите освещение и повторите.','Мәтін анық танылмады. Жарықты жақсартып, қайталаңыз.');
  const names=[...new Set(r.labels.map(l=>labels[l.label]?.[kk?'kk':'ru']).filter(Boolean))];const nearest=r.obstacles.sort((a,b)=>b.area-a.area)[0];const sides=kk?['сол жақта','ортада','оң жақта']:['слева','по центру','справа'];
  const parts=[];if(nearest)parts.push(tr(`Объект ${sides[nearest.zone]}. ${nearest.area>=.25?'Занимает большую часть кадра.':''}`,`Нысан ${sides[nearest.zone]}. ${nearest.area>=.25?'Кадрдың үлкен бөлігін алып тұр.':''}`));if(names.length)parts.push(tr(`Вижу: ${names.join(', ')}.`,`Көріп тұрмын: ${names.join(', ')}.`));
  return parts.join(' ')||tr('Не удалось уверенно распознать предметы. Попробуйте при лучшем освещении.','Заттар анық танылмады. Жарықты жақсартып, қайталаңыз.');
 });
}
function stopMic(){if(recognition){try{recognition.abort()}catch{}recognition=null;}listening=false;$('listen').classList.remove('recording');$('listening-status').textContent='';}
function listen(){
 if(busy)return;if(listening){stopMic();return;}window.speechSynthesis?.cancel();const SpeechRecognition=window.SpeechRecognition||window.webkitSpeechRecognition;
 if(!SpeechRecognition){speak(tr('Браузер не поддерживает голосовой ввод. Напишите команду ниже.','Браузер дауыстық енгізуді қолдамайды. Пәрменді төменге жазыңыз.'));$('command').focus();return;}
 const r=new SpeechRecognition();recognition=r;r.lang=kk?'kk-KZ':'ru-RU';r.interimResults=true;r.continuous=false;
 r.onstart=()=>{if(recognition!==r)return;listening=true;$('listen').classList.add('recording');$('listening-status').textContent=tr('Слушаю…','Тыңдап тұрмын…');};
 r.onresult=e=>{if(recognition!==r)return;const result=e.results[e.results.length-1];$('command').value=result[0].transcript;if(result.isFinal){const t=result[0].transcript;stopMic();execute(t);}};
 r.onerror=e=>{if(recognition!==r)return;stopMic();if(e.error!=='aborted')speak(tr('Не удалось распознать речь. Попробуйте ещё раз или напишите команду.','Сөйлеу танылмады. Қайталаңыз немесе пәрменді жазыңыз.'));};r.onend=()=>{if(recognition===r)stopMic();};
 try{r.start()}catch{stopMic();speak(tr('Микрофон недоступен. Напишите команду.','Микрофон қолжетімсіз. Пәрменді жазыңыз.'));}
}
function stopAll(){if($('consent').open){$('consent').oncancel?.();}operation++;searchSequence++;window.jaryq.cancel?.();pauseGuidance();stopMic();window.speechSynthesis?.cancel();last=tr('Остановлено.','Тоқтатылды.');$('answer').textContent=last;}
async function execute(text){const c=command(text);if(c.action==='stop'){stopAll();return;}if(c.action==='repeat'){speak(last,{display:false});return;}if(c.action==='search'){setPage('route');$('destination').value=c.query;await search();return;}if(c.action==='scene'||c.action==='text'){await camera(c.action);return;}if(c.action==='location'){await where();return;}speak(tr('Я понимаю: «найди парк», «что передо мной», «прочитай текст», «где я», «повтори», «стоп». Свободный разговор пока не подключён.','«Айналада не бар», «мәтінді оқып бер», «қайдамын», «қайтала», «тоқта» пәрмендерін түсінемін. Еркін әңгіме әлі қосылмаған.'));}
async function where(){
 if(busy)return;
 await task(async token=>{
  const p=await locate();if(token!==operation)return;
  const coordinates=tr(`Ваши координаты ${p.coords.latitude.toFixed(5)}, ${p.coords.longitude.toFixed(5)}. Точность GPS примерно ${Math.round(p.coords.accuracy)} метров.`,`Координаттарыңыз ${p.coords.latitude.toFixed(5)}, ${p.coords.longitude.toFixed(5)}. GPS дәлдігі шамамен ${Math.round(p.coords.accuracy)} метр.`);
  if(!navigator.onLine)return coordinates;
  if(!await consent()||token!==operation)return token===operation?coordinates:undefined;
  try{
   const key=`reverse:${p.coords.latitude.toFixed(5)},${p.coords.longitude.toFixed(5)}:${kk}`;
   let address=resultsCache.get(key);
   if(!address){const u=new URL('https://nominatim.openstreetmap.org/reverse');u.search=new URLSearchParams({format:'jsonv2',lat:p.coords.latitude,lon:p.coords.longitude,zoom:'18','accept-language':kk?'kk,ru':'ru'});address=spokenAddress((await request(u)).address);if(address)resultsCache.set(key,address);}
   if(token!==operation)return;
   return address?tr(`Примерный адрес: ${address}. Точность GPS примерно ${Math.round(p.coords.accuracy)} метров.`,`Шамамен мекенжайыңыз: ${address}. GPS дәлдігі шамамен ${Math.round(p.coords.accuracy)} метр.`):coordinates;
  }catch{return token===operation?coordinates:undefined;}
 });
}

document.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>setPage(b.dataset.page));
$('search-form').onsubmit=e=>{e.preventDefault();search();};$('locate').onclick=where;$('start-route').onclick=startGuidance;$('rebuild').onclick=()=>route&&buildRoute(route.destination);$('describe').onclick=()=>camera('scene');$('read').onclick=()=>camera('text');$('listen').onclick=listen;$('repeat').onclick=()=>speak(last||tr('Пока нечего повторять.','Әзірге қайталайтын ештеңе жоқ.'),{display:false});$('stop').onclick=stopAll;
$('command-form').onsubmit=e=>{e.preventDefault();execute($('command').value);};document.querySelectorAll('[data-command]').forEach(b=>b.onclick=()=>{$('command').value=kk?b.dataset.kk:b.dataset.command;execute($('command').value);});
$('language').onclick=()=>{kk=!kk;save('jaryq-language',kk?'kk':'ru');translate();const available=window.speechSynthesis?.getVoices().some(v=>v.lang.toLowerCase().startsWith(kk?'kk':'ru'));speak(available?tr('Русский язык выбран.','Қазақ тілі таңдалды.'):tr('Выбранный голос отсутствует. Используется доступный голос устройства.','Таңдалған дауыс жоқ. Құрылғыдағы қолжетімді дауыс қолданылады.'));};
$('settings-open').onclick=()=>{$('speed').value=String(rate);$('large-text').checked=document.documentElement.classList.contains('large');$('settings').showModal();};$('settings-close').onclick=()=>$('settings').close();$('speed').onchange=()=>{rate=Number($('speed').value);save('jaryq-rate',rate)};$('large-text').onchange=()=>{document.documentElement.classList.toggle('large',$('large-text').checked);save('jaryq-large',String($('large-text').checked));};$('test-voice').onclick=()=>speak(tr('Так звучит голос вашего помощника.','Көмекшіңіздің дауысы осылай естіледі.'));
$('welcome-start').onclick=()=>{$('welcome').close();save('jaryq-welcome','1');speak(tr('Jaryq Jol готов. Найдите место или выберите камеру и голосового помощника.','Jaryq Jol дайын. Орынды табыңыз немесе камера мен дауыстық көмекшіні таңдаңыз.'));};
document.addEventListener('visibilitychange',()=>{if(document.hidden){operation++;window.jaryq.cancel?.();const was=watchId!==undefined;pauseGuidance();stopMic();window.speechSynthesis?.cancel();if(was){last=tr('Сопровождение приостановлено. Для продолжения нажмите «Начать сопровождение».','Бағыттау тоқтатылды. Жалғастыру үшін «Бағыттауды бастау» түймесін басыңыз.');$('answer').textContent=last;}}});
window.addEventListener('pagehide',()=>{operation++;window.jaryq.cancel?.();pauseGuidance();stopMic();window.speechSynthesis?.cancel();});
if(stored('jaryq-large')==='true')document.documentElement.classList.add('large');translate();if(!stored('jaryq-welcome'))$('welcome').showModal();
if('serviceWorker'in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
